Feature: Verify API payload against Avro Schema

  Background:
    * def AvroValidator = Java.type('utils.AvroSchemaValidator')

##In your Karate feature file, import your Java utility, point it to your .avsc file, and assert that the validation returns "SUCCESS".

  # Ready-to-use pattern only, like the DB2 scenarios in db-validation.feature: this project
  # doesn't ship a real external API or a schemas/user.avsc file, so this can't run as-is.
  # Point the url at your real endpoint, add your .avsc under src/test/resources/schemas/,
  # and remove @ignore to enable it.
  @ignore
  Scenario: Validate User API response against user.avsc
    Given url 'https://api.example.com/users/1'
    When method get
    Then status 200
    
    # Convert response to string for Java input
    * def jsonString = karate.toJson(response)
    
    # Call the Java helper (assuming user.avsc is in src/test/resources/schemas/user.avsc)
    * def validationResult = AvroValidator.validate(jsonString, 'schemas/user.avsc')
    
    # Assert validation succeeded
    Then match validationResult == 'SUCCESS'
