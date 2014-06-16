# Guiding Principles

Here are decisions we made when developing Daylight to help us decide which approach to take.
These are not hard-and-fast rules and can be reviewed and changed as the need arises.

1. Let Rails do all of the database work
   - The client should provide the least amount of data to peform the database task
   - Avoid replicating ActiveRecord methods in the client
   Examples: through: :associations, where_values, nested_attributes

2. Maintain symantic URLs and formatted responses
   - Consistency on the server-side allows the client to _just work_
   - Axiomatically, DSL on the client-side is done through these URLs and their query parameters
   Examples: associations are nested routes, properly named root elements, metadata is supported

3. The most granualar objects in responses represent models or their collections
   - Return values only in the context of models (not bare strings, integers etc.)
   Example: associated routes, remote methods

4. Expected behavior of dependent software should not be modified when extended
   - Developers should not be surprised by unexpected results from software they know and love
   - Exception is to fix bugs or expose problems in the underlying software
   Example: AutosaveAssociationFix, ActiveResource `has_one`

5. Extend dependent software (gems) by including changes using ActiveSupport::Concerns
   - Concerns show in ancestor lists and (usually) can chain to original methods via super
   - Extensions may be extracted into their own gems and shared by loading them without configuration
   Examples: readonly attributes and metadata (Serializer), ResourceProxy, Refinements (ActiveResource)

6. Behavior driven tests that drive towards integration testing
   - Use ActiveRecord to do the work for retrieving models instead of mocking it out
   - Server responses are a natural place to mock for the client
   Examples: client_examples, api_controller_examples, MigrationHelper

## Separation of Concerns

* Rails +model+ is the canonical version of the object.
* A model's +serializer+ defines what parts of that model are exposed to the client
* Rails +controller+ defines which actions are performed on the model
* Rails +routes+ defines what APIs are available to the client
* The client-side model is the +client+ representation of the Rails model