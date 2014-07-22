class API::V1::Post < Daylight::API
  scopes :published, :recent, :edited,
         :liked # doesn't exist server-side for error handling tests

  belongs_to :blog
  belongs_to :author, class_name: 'api/v1/user'

  has_many :comments, through: :associated
  has_many :commenters, through: :associated, class_name: 'api/v1/user'
  has_many :suppressed_comments, through: :associated, class_name: 'api/v1/comment'

  has_one :company, through: :blog

  remote :top_comments,  class_name: 'api/v1/comment'

  # these don't exist server-side, they are here for error_handling tests
  has_many :spammers, through: :associated, class_name: 'api/v1/user'
  remote :top_spammers, class_name: 'api/v1/user'
end
