Feature: Reusable function to verify API error codes
#This function takes a map of arguments and dynamically executes the call.

Scenario: verify error code
  # Required arguments:
  #   url: endpoint path (string)
  #   method: http method (string: get, post, put, delete)
  #   requestBody: request payload (optional, use null if not needed)
  #   headers: request headers (optional, use {} if not needed)
  #   expectedStatus: status code (int)

  * def endpoint = __arg.url
  * def httpMethod = __arg.method
  * def body = __arg.requestBody
  * def hdrs = __arg.headers
  * def statusCode = __arg.expectedStatus

  Given path endpoint
  And headers hdrs
  And if (body != null) request body
  When method httpMethod
  Then status statusCode