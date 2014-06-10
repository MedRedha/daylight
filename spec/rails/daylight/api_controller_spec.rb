require 'spec_helper'

describe Daylight::APIController, type: :controller do

  #
  # Test classes
  #

  class Anonymous; end

  class Suite < ActiveRecord::Base
    # TODO: remove when incorporated into ActiveRecord::Base
    include Daylight::Refiners

    has_many :cases

    def odd_suites
      # computational results
      all.values_at(*all.each_index.select(&:odd?))
    end
  end

  class SuitesController < Daylight::APIController
  end

  class Case < ActiveRecord::Base
    belongs_to :suite
  end

  # defined second to prove `handles :all` in SuitesController doesn't
  # publicize every subclass.
  class TestsController < Daylight::APIController
    handles :create, :update, :destroy

    self.model_name  = :case
    self.record_name = :results
  end

  TestAppRecord = Class.new(ActiveResource::Base)

  controller(Daylight::APIController) do
    inherited(self)

    # act like SuitesController should
    self.model_name  = :suite
    self.record_name = :suites
    handles :all

    def raise_argument_error
      raise ArgumentError.new('this is my message')
    end

    def raise_record_invalid_error
      record = TestAppRecord.new
      record.errors.add 'foo', 'error one'
      record.errors.add 'bar', 'error two'
      raise ActiveRecord::RecordInvalid.new(record)
    end

    # strong parameters to permit mass-assignment
    def suite_params
      params.require(:suite).permit(:name, :switch)
    end

    # url helper to generate location url
    def anonymous_path model
      "/anonymous/#{model.to_param}"
    end
  end

  #
  # Hooks
  #

  before do
    @routes.draw do
      get '/anonymous/raise_argument_error'
      get '/anonymous/raise_record_invalid_error'

      resources :anonymous, associated: [:cases], remoted: [:odd_suites]
    end
  end

  before :all do
    FactoryGirl.define do
      factory :suite do
        name   { Faker::Name.name }
        switch false

        after(:create) do |suite|
          create_list :case,  2, suite: suite
        end
      end

      factory :case do
      end
    end
  end

  migrate do
    create_table :suites do |t|
      t.boolean :switch
      t.string  :name
    end

    create_table :cases, id: false do |t|
      t.primary_key :test_id
      t.integer     :suite_id
    end
  end

  after :all do
    Rails.application.reload_routes!
  end

  #
  # Specs
  #

  describe "rescue from ArgumentError" do
    it "has status of bad_request" do
      get :raise_argument_error

      assert_response :bad_request
    end

    it "returns the error message as JSON" do
      get :raise_argument_error

      body = JSON.parse(response.body)
      body['errors'].should == 'this is my message'
    end
  end

  describe "rescue from RecordInvalid" do
    it "has status of unprocessable_entity" do
      get :raise_record_invalid_error

      assert_response :unprocessable_entity
    end

    it "returns the record's errors as JSON" do
      get :raise_record_invalid_error

      body = JSON.parse(response.body)
      body['errors'].count.should == 2
      body['errors']['foo'].should == ['error one']
      body['errors']['bar'].should == ['error two']
    end
  end

  describe "default configuration" do
    let(:controller) { SuitesController }

    it "uses controller name for record name" do
      controller.record_name.should == 'suites'
    end

    it "uses controller name for model name" do
      controller.model_name.should == 'suites'
    end

    it "uses controller name for model key" do
      controller.send(:model_key).should == :suite
    end

    it 'determines model class' do
      controller.send(:model).should == Suite
    end

    it 'delegates primary key to model class' do
      controller.send(:primary_key).should == 'id'
    end
  end

  describe "custom configuration" do
    let(:controller) { TestsController }

    it "overrides record name" do
      controller.record_name.should == :results
    end

    it "overrides model name" do
      controller.model_name.should == :case
    end

    it 'determines model key' do
      controller.send(:model_key).should == :case
    end

    it 'determines model class' do
      controller.send(:model).should == Case
    end

    it 'delegates primary key to determined model class' do
      controller.send(:primary_key).should == 'test_id'
    end
  end

  describe "API handling" do
    let(:tests_controller)  { TestsController.new }
    let(:suites_controller) { SuitesController.new }

    it 'handles no API actions by default' do
      Daylight::APIController::API_ACTIONS.each do |action|
        suites_controller.should_not respond_to(action)
      end
    end

    it 'handles some API actions but not others' do
      allowed = [:create, :update, :destroy]
      denied  = Daylight::APIController::API_ACTIONS.dup - allowed

      allowed.each do |action|
        tests_controller.should respond_to(action)
      end

      denied.each do |action|
        tests_controller.should_not respond_to(action)
      end
    end

    it 'handles all API actions' do
      Daylight::APIController::API_ACTIONS.each do |action|
        @controller.should respond_to(action)
      end
    end
  end

  describe "common actions" do
    let!(:suite1) { create(:suite, switch: true)  }
    let!(:suite2) { create(:suite, switch: false) }
    let!(:suite3) { create(:suite, switch: true)  }

    def parse_response body
      JSON.parse(body)['anonymous'].
        map(&:values).
        map(&:first).
        map(&:with_indifferent_access)
    end

    it 'responds to index' do
      get :index

      results = parse_response(response.body)
      results.size.should == 3

      names = results.map {|suite| suite["name"] }
      names.should be_include(suite1.name)
      names.should be_include(suite2.name)
      names.should be_include(suite3.name)
    end

    it 'responds to index with refine_by' do
      get :index, filters: {switch: true}

      results = parse_response(response.body)

      results.size.should == 2
      names = results.map {|suite| suite[:name] }
      names.should be_include(suite1.name)
      names.should be_include(suite3.name)
    end

    it 'creates a record' do
      post :create, suite: suite = FactoryGirl.attributes_for(:suite)

      result = JSON.parse(response.body).with_indifferent_access
      result[:name].should   == suite[:name]
      result[:switch].should == suite[:switch]

      response.headers['Location'].should == @controller.anonymous_path(Suite.new(result))
    end

  end

end
