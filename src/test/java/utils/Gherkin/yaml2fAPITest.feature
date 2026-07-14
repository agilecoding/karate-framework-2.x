Feature: Step-by-Step: Create Karate API Tests from YAML (OpenAPI)

# Step1:  Optional: Convert if you prefer JSON </> BASH
yaml2json api.yaml > api.json

## use the YAML file directly if you prefer:
* def openapi = karate.read('classpath:api.yaml')


# Step 2:  Read the OpenAPI file in Karate
Feature: Validate OpenAPI endpoints

Scenario: Load OpenAPI spec
  * def spec = karate.read('classpath:api.yaml')
  * print spec.paths

  # step 3 Loop through  paths and create Tests
  Scenario: Run tests for all GET endpoints
  * def spec = karate.read('classpath:api.yaml')
  * def paths = spec.paths

  * def keys = Object.keys(paths)
  * print 'Found endpoints:', keys

  * def getPaths = 
    """
    function(paths) {
      var list = [];
      for (var path in paths) {
        if (paths[path].get) {
          list.push(path);
        }
      }
      return list;
    }
    """
  * def getEndpoints = getPaths(paths)
  * print getEndpoints

  * def baseUrl = 'https://api.example.com'

  * def runTest = 
    """
    function(url) {
      var config = {
        url: baseUrl + url,
        method: 'get'
      };
      return config;
    }
    """

  * def responseList = []
  * for (var i in getEndpoints)
  """
  * def conf = runTest(getEndpoints[i])
  * url conf.url
  * method conf.method
  * status 200
  """

  ## Step 4: Generate Template .feature Files (Optional)
#   There’s no built-in Karate CLI to generate test files, but you can write a small script (in Node.js, Python, or Bash) to:
# Parse the OpenAPI YAML.
# For each endpoint/method, generate a .feature file with a placeholder scenario.


#### Great! Below is a Node.js script that:

✅ Parses an OpenAPI YAML spec
✅ Extracts paths, methods, and basic descriptions
✅ Generates Karate .feature files (one per endpoint or group)

Before you run the script, install these dependencies:
</> Bash
npm init -y
npm install js-yaml fs path mkdirp


Script: generate-karate-features.js

const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');
const mkdirp = require('mkdirp');

// Path to your OpenAPI YAML file
const openApiPath = './api.yaml';
const outputDir = './karate-tests';

function toMethodName(method) {
  return method.toUpperCase();
}

function sanitizeFilename(str) {
  return str.replace(/[\/{}]/g, '_');
}

function generateFeature(pathKey, method, operation) {
  const summary = operation.summary || `${method.toUpperCase()} ${pathKey}`;
  const fileName = sanitizeFilename(`${method}_${pathKey}.feature`);
  const fullPath = path.join(outputDir, fileName);

  const featureText = `Feature: ${summary}

Scenario: ${summary}
  Given url baseUrl + '${pathKey}'
  When method ${method}
  Then status 200
  # And match response == {}  # <-- update with actual schema if needed
`;

  fs.writeFileSync(fullPath, featureText, 'utf8');
  console.log(`✅ Generated: ${fileName}`);
}

function main() {
  const doc = yaml.load(fs.readFileSync(openApiPath, 'utf8'));

  const basePath = doc.basePath || '';
  const paths = doc.paths;

  mkdirp.sync(outputDir);

  for (const pathKey in paths) {
    const methods = paths[pathKey];
    for (const method in methods) {
      const operation = methods[method];
      generateFeature(pathKey, method, operation);
    }
  }

  console.log('\n🎉 All feature files generated!');
}

main();

### example Directory structure after running the script:
## Given /pets and /pets/{id} in your OpenAPI spec, this script generates:
./karate-tests/
├── get__pets.feature
├── get__pets__id_.feature
├── post__pets.feature
...

## sample karate .feature ouput
Feature: List all pets

Scenario: List all pets
  Given url baseUrl + '/pets'
  When method get
  Then status 200