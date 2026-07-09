Feature: database validation - cross-check API responses against persisted data

  DbHelper is a single generic JDBC wrapper reused for both Postgres and DB2 (see
  utils/DbHelper.java) - only the JDBC URL/driver differs.

  Background:
    * def DbHelper = Java.type('utils.DbHelper')
    * def pgHelper = new DbHelper(db.postgres.url, db.postgres.user, db.postgres.password)
    * def db2Helper = new DbHelper(db.db2.url, db.db2.user, db.db2.password)

  @postgres
  Scenario: eligibility check result matches the system-of-record row in Postgres
    # Seeded by data/init.sql via docker-compose - run `docker-compose up -d` first.
    * url mockBaseUrl
    * header Authorization = 'Bearer ' + jwtToken
    Given path '/api/benefits/eligibility/123456788'
    When method get
    Then status 200

    * def rows = pgHelper.query("SELECT ssn, eligible FROM eligibility WHERE ssn = '123456788'")
    And match rows == '#[1]'
    And match rows[0].ssn == response.ssn
    And match rows[0].eligible == response.eligible

  @postgres
  Scenario: eligibility for a second seeded ssn also matches Postgres
    * url mockBaseUrl
    * header Authorization = 'Bearer ' + jwtToken
    Given path '/api/benefits/eligibility/123456787'
    When method get
    Then status 200

    * def rows = pgHelper.query("SELECT ssn, eligible FROM eligibility WHERE ssn = '123456787'")
    And match rows == '#[1]'
    And match rows[0].eligible == false
    And match rows[0].eligible == response.eligible

  # This mock keeps disability applications in-memory only (see mock/benefits-mock.feature),
  # so there is nothing in Postgres to check yet. This scenario documents the pattern to wire
  # up once the real service persists submitted applications - point it at the real
  # disability_application table and remove @ignore.
  @postgres @ignore
  Scenario: disability application row is inserted after a successful POST
    * url mockBaseUrl
    * header Authorization = 'Bearer ' + jwtToken
    * def payload = { ssn: '246813579', firstName: 'Alex', lastName: 'Kim', dob: '1978-06-30', disabilityType: 'PHYSICAL', incomeAnnual: 30000 }
    Given path '/api/disability/apply'
    And request payload
    When method post
    Then status 201

    * def rows = pgHelper.query("SELECT * FROM disability_application WHERE application_id = '" + response.applicationId + "'")
    And match rows == '#[1]'
    And match rows[0].status == 'SUBMITTED'
    And match rows[0].ssn == payload.ssn

  # DB2 pattern only: requires a live DB2 instance + the com.ibm.db2:jcc driver (pom.xml).
  # Point db.db2.url in karate-config.js at your instance, seed DISABILITY_LEDGER, then
  # remove @ignore.
  @db2 @ignore
  Scenario: legacy DB2 ledger reflects the same submitted application
    * def rows = db2Helper.query("SELECT * FROM DISABILITY_LEDGER WHERE APPLICATION_ID = 'some-id'")
    And match rows == '#[1]'
    And match rows[0].STATUS == 'SUBMITTED'
