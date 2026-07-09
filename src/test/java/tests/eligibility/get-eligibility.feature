Feature: GET /api/benefits/eligibility/{ssn} - eligibility checks

  Background:
    * url mockBaseUrl
    * header Authorization = 'Bearer ' + jwtToken

  Scenario: eligible ssn returns 200 with a full eligibility payload
    Given path '/api/benefits/eligibility/123456788'
    When method get
    Then status 200
    And assert responseTime < 1000
    And match response == { ssn: '123456788', eligible: true, benefits: '#array', checkedAt: '#string' }
    And match response.benefits == '#[3]'
    And match each response.benefits == '#string'
    And match response.benefits contains 'SSDI'
    And match response.benefits contains only ['SNAP', 'MEDICAID', 'SSDI']
    And match response.ssn == '#regex [0-9]{9}'
    And match response.checkedAt == '#regex \\d{4}-\\d{2}-\\d{2}T.*'
    And match responseHeaders['Content-Type'][0] contains 'application/json'

  Scenario: ineligible ssn returns 200 with an empty benefits array
    Given path '/api/benefits/eligibility/123456787'
    When method get
    Then status 200
    And match response.eligible == false
    And match response.benefits == '#[0]'
    And match response.benefits == []

  Scenario: unknown ssn returns 404 not found
    Given path '/api/benefits/eligibility/000000000'
    When method get
    Then status 404
    And match response == { error: 'NOT_FOUND', message: '#string' }
    And match response.message contains '000000000'

  Scenario: malformed ssn returns 400 bad request
    Given path '/api/benefits/eligibility/12AB'
    When method get
    Then status 400
    And match response.error == 'BAD_REQUEST'
    And match response.message == '#present'

  Scenario: missing auth header returns 401 unauthorized
    Given header Authorization = ''
    And path '/api/benefits/eligibility/123456788'
    When method get
    Then status 401
    And match response.error == 'UNAUTHORIZED'

  Scenario: invalid bearer token still passes since mock only checks header presence - documents current contract
    Given header Authorization = 'Bearer garbage-token'
    And path '/api/benefits/eligibility/123456788'
    When method get
    Then status 200

  Scenario Outline: eligibility status codes are consistent across ssn variants
    Given path '/api/benefits/eligibility/<ssn>'
    When method get
    Then status <status>

    Examples:
      | ssn        | status |
      | 111111112  | 200    |
      | 111111113  | 200    |
      | 000000000  | 404    |
      | 22222      | 400    |

  Scenario: response never leaks internal fields beyond the documented schema
    Given path '/api/benefits/eligibility/123456788'
    When method get
    Then status 200
    * def keys = Object.keys(response)
    And match keys contains only ['ssn', 'eligible', 'benefits', 'checkedAt']
