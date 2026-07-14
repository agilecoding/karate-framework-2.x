Feature: Validate PDF Content-Type & Header
Scenario: Verify PDF download
  Given url 'https://example.com/api/document.pdf'
  When method GET
  Then status 200
  And match responseHeaders['Content-Type'][0] contains 'application/pdf'
  And match response startsWith '%PDF-'

## PDFBox pom.xml dependency for parsing PDF content  
# <dependency>
#   <groupId>org.apache.pdfbox</groupId>
#   <artifactId>pdfbox</artifactId>
#   <version>2.0.30</version>
# </dependency>

## JAva Helper class to parse PDF content using PDFBox
#### PdfUtils.java
# package utils;

# import org.apache.pdfbox.pdmodel.PDDocument;
# import org.apache.pdfbox.text.PDFTextStripper;

# import java.io.InputStream;

# public class PdfUtils {
#     public static String extractText(InputStream inputStream) throws Exception {
#         try (PDDocument doc = PDDocument.load(inputStream)) {
#             return new PDFTextStripper().getText(doc);
#         }
#     }
# }

### use java class in karate feature file
* def PdfUtils = Java.type('utils.PdfUtils')
* def pdfText = PdfUtils.extractText(response)
* print pdfText
* match pdfText contains 'Expected Title'  // Replace with expected content
* def filePath = karate.write(response, 'output/test.pdf')
* print 'Saved PDF at:', filePath



### full combined gherkin example
Feature: Validate PDF Content

Scenario: Download and read PDF
  Given url 'https://example.com/api/report.pdf'
  When method GET
  Then status 200
  And match responseHeaders['Content-Type'][0] contains 'application/pdf'
  And match response startsWith '%PDF-'

  * def PdfUtils = Java.type('utils.PdfUtils')
  * def pdfText = PdfUtils.extractText(response)
  * print 'PDF Content:', pdfText
  * match pdfText contains 'Quarterly Financial Report'


#### 🔧 Fix for Karate: Convert Response to InputStream
#When you pass response from Karate (which is a byte array) to your Java class, you must wrap it as an InputStream.
#Updated Java Code (PdfUtils.java):
# package utils;

# import org.apache.pdfbox.pdmodel.PDDocument;
# import org.apache.pdfbox.text.PDFTextStripper;

# import java.io.ByteArrayInputStream;

# public class PdfUtils {
#     public static String extractText(byte[] pdfBytes) throws Exception {
#         try (PDDocument document = PDDocument.load(new ByteArrayInputStream(pdfBytes))) {
#             return new PDFTextStripper().getText(document);
#         }
#     }
# }

* def PdfUtils = Java.type('utils.PdfUtils')
* def pdfText = PdfUtils.extractText(response)
* print 'PDF content:', pdfText
* match pdfText contains 'Some Expected Text'


### 1. Correct Way: Validate PDF Header in Karate (as binary)
* def responseString = java.lang.String(response, 'ISO-8859-1')
* match responseString startsWith '%PDF-'

### 2. Check First 4 Bytes Manually(if strict)
* def pdfSignature = response.slice(0, 5)
* def sigAsString = java.lang.String(pdfSignature, 'ISO-8859-1')
* match sigAsString == '%PDF-'

Feature: Validate PDF response

Scenario: Verify PDF content and header
  Given url 'https://example.com/api/document.pdf'
  When method GET
  Then status 200

  # Validate Content-Type
  And match responseHeaders['Content-Type'][0] contains 'application/pdf'

  # Validate starts with %PDF-
  * def responseString = java.lang.String(response, 'ISO-8859-1')
  * match responseString startsWith '%PDF-'


#### Working Example (Detect %PDF- header)
* def byteArray = response
* def stringFromBytes = new java.lang.String(byteArray, 'ISO-8859-1')
* match stringFromBytes startsWith '%PDF-'
* match responseHeaders['Content-Type'][0] contains 'application/pdf'


Feature: Validate PDF content

Scenario: Check PDF signature
  Given url 'https://example.com/api/report.pdf'
  When method GET
  Then status 200

  # Check it's a PDF via headers
  And match responseHeaders['Content-Type'][0] contains 'application/pdf'

  # Check binary signature
  * def byteArray = response
  * def stringFromBytes = new java.lang.String(byteArray, 'ISO-8859-1')
  * match stringFromBytes startsWith '%PDF-'



### Save PDF to Disk and verufy file exist on disk
* def filePath = karate.write(response, 'output/report.pdf')
* print 'PDF written to:', filePath  
* def File = Java.type('java.io.File')
* def file = new File(filePath)
* match file.exists() == true
* match file.length() > 0
* match file.getName() endsWith '.pdf'

### Validate File Createion Date (Java 8+)
* def Files = Java.type('java.nio.file.Files')
* def Paths = Java.type('java.nio.file.Paths')
* def path = Paths.get(filePath)
* def attrs = Files.readAttributes(path, 'basic:creationTime')
* print 'PDF creation time:', attrs.creationTime()

Feature: Validate PDF is saved locally

Scenario: Save PDF and validate file
  Given url 'https://example.com/api/download.pdf'
  When method GET
  Then status 200

  # Save to disk
  * def filePath = karate.write(response, 'output/report.pdf')

  # Validate file exists and is a PDF
  * def File = Java.type('java.io.File')
  * def file = new File(filePath)
  * match file.exists() == true
  * match file.length() > 1000
  * match file.getName() endsWith '.pdf'


  Feature: Validate PDF signature in response

Scenario: Check PDF magic number
  Given url 'https://example.com/api/report.pdf'
  When method GET
  Then status 200

  # Validate it's a PDF file
  * match responseHeaders['Content-Type'][0] contains 'application/pdf'

  # Convert byte[] to String safely
  * def byteArray = response
  * def stringFromBytes = new java.lang.String(byteArray, 'ISO-8859-1')

  # Validate PDF signature
  * match stringFromBytes startsWith '%PDF-'

  * def path = karate.write(response, 'output/report.pdf')
* print 'Saved PDF at:', path


Feature: Validate PDF response without Java class access

Scenario: Confirm PDF via content-type and magic number
  Given url 'https://example.com/api/report.pdf'
  When method GET
  Then status 200

  # Validate header
  * match responseHeaders['Content-Type'][0] contains 'application/pdf'

  # Convert response byte[] to string using built-in method
  * def stringFromBytes = karate.toString(response, 'ISO-8859-1')

  # Match PDF file signature
  * match stringFromBytes startsWith '%PDF-'
  * def file = { name: 'report.pdf', size: 1500 }
  * match file.size == '#? _ > 1000'  
  * def File = Java.type('java.io.File')
  * def file = new File('output/report.pdf')
  * assert file.getName().endsWith('.pdf')

Feature: File validation

Scenario: Validate saved PDF
  * def File = Java.type('java.io.File')
  * def file = new File('output/report.pdf')
  * assert file.exists()
  * assert file.length() > 1000
  * assert file.getName().endsWith('.pdf')  


##### step by step : check PDF signaure in karate
Feature: Validate PDF Signature

Scenario: Check if PDF response is valid
  Given url 'https://example.com/api/document.pdf'
  When method GET
  Then status 200

  # Check content-type header
  * match responseHeaders['Content-Type'][0] contains 'application/pdf'

  # Convert response byte[] to string using ISO-8859-1 to preserve bytes
  * def pdfString = karate.toString(response, 'ISO-8859-1')

  # Validate that the PDF starts with '%PDF-'
  * match pdfString startsWith '%PDF-'

## isPdf.js --- Karate JavaScript Function
#   function(responseBytes) {
#   // Java interop to create a string from byte[] using ISO-8859-1 encoding
#   var StringClass = Java.type('java.lang.String');
#   var decoded = new StringClass(responseBytes, 'ISO-8859-1');
#   return decoded.startsWith('%PDF-');
# }

* def isPdf = read('classpath:isPdf.js')

Given url 'https://example.com/download/report.pdf'
When method GET
Then status 200

# Validate that the response is a PDF
* assert isPdf(response)

# function isPdf(responseBytes) {
#   var StringClass = Java.type('java.lang.String');
#   var decoded = new StringClass(responseBytes, 'ISO-8859-1');
#   return decoded.startsWith('%PDF-');
# }

# Load the JS file
* def utils = js.read('classpath:utils/utils.js')

# Call the isPdf function with response byte array
* def isValid = utils.isPdf(response)
* assert isValid