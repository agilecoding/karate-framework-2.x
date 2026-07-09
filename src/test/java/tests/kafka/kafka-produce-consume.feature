Feature: Kafka event validation

  Best practices demonstrated here:
    - a fresh, unique consumer group per scenario (avoids offset/rebalance contamination
      between tests running in parallel)
    - the consumer is created and subscribed BEFORE anything is produced, to avoid the
      classic race where a message is sent before the consumer group has joined
    - poll in a bounded retry loop instead of a single fixed sleep, since consumer group
      rebalancing/assignment is asynchronous
    - explicit close() of producer/consumer at the end of each scenario

  Background:
    * def KafkaProducerHelper = Java.type('utils.KafkaProducerHelper')
    * def KafkaConsumerHelper = Java.type('utils.KafkaConsumerHelper')
    * def bootstrapServers = kafka.bootstrapServers
    * def uniqueGroupId = 'karate-test-' + java.util.UUID.randomUUID()
    * def pollUntilFound =
      """
      function(consumer, matchKey) {
        var records = [];
        for (var i = 0; i < 10 && records.length == 0; i++) {
          var batch = consumer.poll(1000);
          batch.forEach(function(r) { if (r.key == matchKey) records.push(r); });
        }
        return records;
      }
      """

  Scenario: producer/consumer round trip on a dedicated echo topic
    * def consumer = new KafkaConsumerHelper(bootstrapServers, uniqueGroupId, kafka.echoTopic)
    * def producer = new KafkaProducerHelper(bootstrapServers)
    * def testKey = 'echo-' + java.util.UUID.randomUUID()
    * def testPayload = { message: 'hello from karate', sentAt: new Date().toISOString() }

    * def sendResult = producer.send(kafka.echoTopic, testKey, JSON.stringify(testPayload))
    And match sendResult == { topic: '#string', partition: '#number', offset: '#number' }
    And match sendResult.topic == kafka.echoTopic

    * def found = pollUntilFound(consumer, testKey)
    And match found == '#[1]'
    And match found[0].partition == '#number'
    And match found[0].offset == '#number'

    * def received = JSON.parse(found[0].value)
    And match received.message == 'hello from karate'

    * eval producer.close()
    * eval consumer.close()

  Scenario: submitting a disability application publishes an event to the application topic
    * url mockBaseUrl
    * header Authorization = 'Bearer ' + jwtToken
    * def consumer = new KafkaConsumerHelper(bootstrapServers, uniqueGroupId, kafka.applicationTopic)
    * def payload = { ssn: '135792468', firstName: 'Sam', lastName: 'Lee', dob: '1990-01-01', disabilityType: 'MENTAL', incomeAnnual: 18000 }

    Given path '/api/disability/apply'
    And request payload
    When method post
    Then status 201
    * def newId = response.applicationId

    * def found = pollUntilFound(consumer, newId)
    And match found == '#[1]'

    * def event = JSON.parse(found[0].value)
    And match event == { applicationId: '#(newId)', ssn: '135792468', status: 'SUBMITTED', disabilityType: 'MENTAL', submittedAt: '#string' }

    * eval consumer.close()

  Scenario: no event is published to the application topic for a rejected (invalid) application
    * def consumer = new KafkaConsumerHelper(bootstrapServers, uniqueGroupId, kafka.applicationTopic)
    * url mockBaseUrl
    * header Authorization = 'Bearer ' + jwtToken
    * def invalidPayload = { ssn: '', firstName: '', lastName: '', dob: '', disabilityType: '' }

    Given path '/api/disability/apply'
    And request invalidPayload
    When method post
    Then status 400

    * def batch = consumer.poll(2000)
    And match batch == '#[0]'

    * eval consumer.close()
