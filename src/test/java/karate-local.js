function fn() {
  // Local-environment overrides, primarily the JWT used to authenticate against the mock API.
  // In a real project this would call your auth server / IdP token endpoint, or be injected
  // via an env var / CI secret rather than hardcoded:
  //   var jwt = karate.properties['LOCAL_JWT'] || callSingle('classpath:auth/get-token.feature').token;
  var jwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.' +
            'eyJzdWIiOiJrYXJhdGUtdGVzdC11c2VyIiwicm9sZXMiOlsiQkVORUZJVFNfQURNSU4iXX0.' +
            'local-dev-signature';

  return {
    jwtToken: jwt
  };
}
