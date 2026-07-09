Feature: mock benefits & disability API
  Simulates two application-under-test APIs for SDET framework testing:
    - GET  /api/benefits/eligibility/{ssn}   check SSN eligibility for benefits
    - POST /api/disability/apply             submit a disability application
    - GET  /api/disability/application/{id}  look up a submitted application
  State (applications) is kept in-memory in the Background, which runs once when the mock
  server starts and stays in scope for the lifetime of the process - this is standard Karate
  mock-server behavior and lets scenarios persist data across requests without a real DB.

  Background:
    * def applications = {}
    * def KafkaProducerHelper = Java.type('utils.KafkaProducerHelper')
    * def bootstrapServers = java.lang.System.getProperty('kafka.bootstrap.servers') || 'localhost:9092'
    * def kafkaProducer = new KafkaProducerHelper(bootstrapServers)
    * def applicationTopic = 'disability.application.events'

  # ---------------------------------------------------------------------------------------
  # GET /api/benefits/eligibility/{ssn}
  # ---------------------------------------------------------------------------------------

  Scenario: pathMatches('/api/benefits/eligibility/{ssn}') && methodIs('get') && !(requestHeaders['authorization'] || requestHeaders['Authorization'])
    * def responseStatus = 401
    * def response = { error: 'UNAUTHORIZED', message: 'Missing or invalid Authorization header' }

  Scenario: pathMatches('/api/benefits/eligibility/{ssn}') && methodIs('get')
    * def ssn = pathParams.ssn
    * def isValidFormat = new RegExp('^[0-9]{9}$').test(ssn)
    * def notFound = isValidFormat && ssn == '000000000'
    * def lastDigit = isValidFormat ? parseInt(ssn.charAt(8), 10) : -1
    * def eligible = (isValidFormat && !notFound) ? (lastDigit % 2 == 0) : false
    * def responseStatus = !isValidFormat ? 400 : (notFound ? 404 : 200)
    * def badRequestBody = { error: 'BAD_REQUEST', message: 'ssn must be exactly 9 digits' }
    * def notFoundBody = { error: 'NOT_FOUND', message: 'No record found for ssn ' + ssn }
    * def okBody = {}
    * eval okBody.ssn = ssn
    * eval okBody.eligible = eligible
    * eval okBody.benefits = eligible ? ['SNAP', 'MEDICAID', 'SSDI'] : []
    * eval okBody.checkedAt = new Date().toISOString()
    * def response = !isValidFormat ? badRequestBody : (notFound ? notFoundBody : okBody)

  # ---------------------------------------------------------------------------------------
  # POST /api/disability/apply
  # ---------------------------------------------------------------------------------------

  Scenario: pathMatches('/api/disability/apply') && methodIs('post') && !(requestHeaders['authorization'] || requestHeaders['Authorization'])
    * def responseStatus = 401
    * def response = { error: 'UNAUTHORIZED', message: 'Missing or invalid Authorization header' }

  Scenario: pathMatches('/api/disability/apply') && methodIs('post')
    * def messages = []
    * eval if (!request.ssn) messages.push('ssn is required')
    * eval if (request.ssn && !/^[0-9]{9}$/.test(request.ssn)) messages.push('ssn must be 9 digits')
    * eval if (!request.firstName) messages.push('firstName is required')
    * eval if (!request.lastName) messages.push('lastName is required')
    * eval if (!request.dob) messages.push('dob is required')
    * eval if (request.dob && !/^\d{4}-\d{2}-\d{2}$/.test(request.dob)) messages.push('dob must be in YYYY-MM-DD format')
    * eval if (!request.disabilityType) messages.push('disabilityType is required')
    * eval if (request.incomeAnnual != null && request.incomeAnnual < 0) messages.push('incomeAnnual cannot be negative')
    * def duplicate = messages.length == 0 && applications[request.ssn] ? true : false
    * def responseStatus = messages.length > 0 ? 400 : (duplicate ? 409 : 201)
    * def applicationId = (messages.length == 0 && !duplicate) ? java.util.UUID.randomUUID() + '' : null
    * def submittedAt = new Date().toISOString()
    * def validationErrorBody = {}
    * eval validationErrorBody.error = 'VALIDATION_ERROR'
    * eval validationErrorBody.messages = messages
    * def conflictBody = {}
    * eval if (duplicate) { conflictBody.error = 'CONFLICT'; conflictBody.message = 'Application already exists for this ssn'; conflictBody.existingApplicationId = applications[request.ssn].applicationId }
    * def createdBody = {}
    * eval createdBody.applicationId = applicationId
    * eval createdBody.ssn = request.ssn
    * eval createdBody.status = 'SUBMITTED'
    * eval createdBody.submittedAt = submittedAt
    * def response = messages.length > 0 ? validationErrorBody : (duplicate ? conflictBody : createdBody)
    * eval if (responseStatus == 201) applications[request.ssn] = response
    * def responseHeaders = {}
    * eval if (responseStatus == 201) responseHeaders.Location = '/api/disability/application/' + applicationId
    * eval if (responseStatus == 201) { var event = {}; event.applicationId = applicationId; event.ssn = request.ssn; event.status = 'SUBMITTED'; event.disabilityType = request.disabilityType; event.submittedAt = submittedAt; kafkaProducer.send(applicationTopic, applicationId, JSON.stringify(event)) }

  # ---------------------------------------------------------------------------------------
  # GET /api/disability/application/{id}
  # ---------------------------------------------------------------------------------------

  Scenario: pathMatches('/api/disability/application/{id}') && methodIs('get') && !(requestHeaders['authorization'] || requestHeaders['Authorization'])
    * def responseStatus = 401
    * def response = { error: 'UNAUTHORIZED', message: 'Missing or invalid Authorization header' }

  Scenario: pathMatches('/api/disability/application/{id}') && methodIs('get')
    * def id = pathParams.id
    * def found = null
    * eval for (var key in applications) { if (applications[key].applicationId == id) found = applications[key] }
    * def responseStatus = found ? 200 : 404
    * def response = found ? found : { error: 'NOT_FOUND', message: 'No application found for id ' + id }

  # ---------------------------------------------------------------------------------------
  # Catch-all
  # ---------------------------------------------------------------------------------------

  Scenario:
    * def responseStatus = 404
    * def response = { error: 'NOT_FOUND', message: 'No matching route for ' + requestMethod + ' ' + requestUri }
