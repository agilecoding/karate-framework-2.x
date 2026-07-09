Feature: POST /api/disability/apply - disability application submission

  Background:
    * url mockBaseUrl
    * header Authorization = 'Bearer ' + jwtToken
    * def validPayload =
      """
      {
        "ssn": "987654321",
        "firstName": "Jordan",
        "lastName": "Reed",
        "dob": "1985-03-14",
        "disabilityType": "PHYSICAL",
        "incomeAnnual": 24000
      }
      """

  Scenario: valid application is submitted and returns 201 with a generated applicationId
    * def payload = karate.merge(validPayload, { ssn: '987654321' })
    Given path '/api/disability/apply'
    And request payload
    When method post
    Then status 201
    And match response == { applicationId: '#uuid', ssn: '#(payload.ssn)', status: 'SUBMITTED', submittedAt: '#string' }
    And match response.applicationId == '#regex [0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
    And match responseHeaders['Location'][0] == '/api/disability/application/' + response.applicationId

  Scenario: duplicate application for the same ssn is rejected with 409
    * def payload = karate.merge(validPayload, { ssn: '111223333' })
    Given path '/api/disability/apply'
    And request payload
    When method post
    Then status 201

    Given path '/api/disability/apply'
    And request payload
    When method post
    Then status 409
    And match response.error == 'CONFLICT'
    And match response.existingApplicationId == '#notnull'
    And match response.existingApplicationId == '#uuid'

  Scenario: a submitted application is retrievable via GET by id
    * def payload = karate.merge(validPayload, { ssn: '222334444' })
    Given path '/api/disability/apply'
    And request payload
    When method post
    Then status 201
    * def newId = response.applicationId

    Given path '/api/disability/application/' + newId
    When method get
    Then status 200
    And match response.applicationId == newId
    And match response.status == 'SUBMITTED'
    And match response.ssn == payload.ssn

  Scenario: fetching an unknown application id returns 404
    Given path '/api/disability/application/does-not-exist'
    When method get
    Then status 404
    And match response.error == 'NOT_FOUND'

  Scenario: response time and content-type are within expected bounds
    * def payload = karate.merge(validPayload, { ssn: '333445555' })
    Given path '/api/disability/apply'
    And request payload
    When method post
    Then status 201
    And assert responseTime < 1000
    And match responseHeaders['Content-Type'][0] contains 'application/json'

  Scenario Outline: invalid payloads are rejected with 400 and the expected validation message
    * def payload = karate.merge(validPayload, <override>)
    Given path '/api/disability/apply'
    And request payload
    When method post
    Then status 400
    And match response.error == 'VALIDATION_ERROR'
    And match response.messages contains '<expectedMessage>'

    Examples:
      | override                 | expectedMessage                  |
      | { ssn: '' }               | ssn is required                  |
      | { ssn: '123' }            | ssn must be 9 digits             |
      | { firstName: '' }         | firstName is required            |
      | { lastName: '' }          | lastName is required             |
      | { dob: '' }                | dob is required                  |
      | { dob: '03-14-1985' }     | dob must be in YYYY-MM-DD format |
      | { disabilityType: '' }    | disabilityType is required       |
      | { incomeAnnual: -500 }    | incomeAnnual cannot be negative  |

  Scenario: multiple validation errors are all reported together, not just the first
    * def payload = karate.merge(validPayload, { ssn: '', firstName: '', incomeAnnual: -1 })
    Given path '/api/disability/apply'
    And request payload
    When method post
    Then status 400
    And match response.messages == '#[3]'
    And match response.messages contains 'ssn is required'
    And match response.messages contains 'firstName is required'
    And match response.messages contains 'incomeAnnual cannot be negative'

  Scenario: missing auth header returns 401 before any validation runs
    Given header Authorization = ''
    And path '/api/disability/apply'
    And request validPayload
    When method post
    Then status 401
    And match response.error == 'UNAUTHORIZED'
