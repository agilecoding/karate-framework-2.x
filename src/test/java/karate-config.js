function fn() {
  var env = karate.env || 'local';
  karate.log('karate.env =', env);

  var config = {
    env: env,
    mockBaseUrl: 'http://localhost:8099',
    kafka: {
      bootstrapServers: java.lang.System.getProperty('kafka.bootstrap.servers') || 'localhost:9092',
      applicationTopic: 'disability.application.events',
      echoTopic: 'test.echo'
    },
    db: {
      postgres: {
        url: 'jdbc:postgresql://localhost:5432/benefits',
        user: 'benefits_user',
        password: 'benefits_pass'
      },
      db2: {
        url: 'jdbc:db2://localhost:50000/BENEFDB',
        user: 'db2inst1',
        password: 'db2pass'
      }
    },
    jwtToken: 'default-test-token'
  };

  // Environment-specific overrides. Karate's real convention is one file per env named
  // karate-<env>.js (NOT karate-config-<env>.js) - only karate-config.js itself is a fixed name.
  if (env == 'local') {
    config = Object.assign(config, read('classpath:karate-local.js')());
  } else if (env == 'qa') {
    // config = Object.assign(config, read('classpath:karate-qa.js')());
  }

  karate.configure('connectTimeout', 15000);
  karate.configure('readTimeout', 15000);
  // Log full request/response only for failures to keep CI logs readable.
  karate.configure('logPrettyRequest', true);
  karate.configure('logPrettyResponse', true);

  return config;
}
