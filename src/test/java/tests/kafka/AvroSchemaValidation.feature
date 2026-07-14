Feature: Verify API payload against Avro Schema

  Background:
    * def AvroValidator = Java.type('utils.AvroSchemaValidator')

##In your Karate feature file, import your Java utility, point it to your .avsc file, and assert that the validation returns "SUCCESS".

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
