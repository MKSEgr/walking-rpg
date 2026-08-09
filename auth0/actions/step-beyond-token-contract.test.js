const assert = require('node:assert/strict');
const test = require('node:test');

const action = require('./step-beyond-token-contract');

test('interactive login emits signed device and authentication-time claims', async () => {
  const api = recordingApi();
  await action.onExecutePostLogin(
    {
      resource_server: {identifier: action._contract.API_AUDIENCE},
      request: {
        query: {
          'ext-installation-id': '0123456789abcdef0123456789abcdef',
        },
      },
      authentication: {
        methods: [
          {name: 'pwd', timestamp: '2026-08-09T08:00:00.500Z'},
          {name: 'mfa', timestamp: '2026-08-09T08:01:00.999Z'},
        ],
      },
      transaction: {protocol: 'oidc-basic-profile'},
    },
    api,
  );

  assert.equal(api.denials.length, 0);
  assert.deepEqual(api.claims, {
    [action._contract.DEVICE_CLAIM]:
      '0123456789abcdef0123456789abcdef',
    [action._contract.AUTHENTICATION_TIME_CLAIM]: 1786262460,
  });
});

test('refresh keeps the device claim but cannot mint authentication freshness', async () => {
  const api = recordingApi();
  await action.onExecutePostLogin(
    {
      resource_server: {identifier: action._contract.API_AUDIENCE},
      request: {
        body: {
          grant_type: 'refresh_token',
          'ext-installation-id': 'fedcba9876543210fedcba9876543210',
        },
      },
      transaction: {protocol: 'oauth2-refresh-token'},
    },
    api,
  );

  assert.equal(api.denials.length, 0);
  assert.deepEqual(api.claims, {
    [action._contract.DEVICE_CLAIM]:
      'fedcba9876543210fedcba9876543210',
  });
});

test('matching API fails closed for a missing or malformed installation ID', async () => {
  for (const installationId of [undefined, 'device-1', 'A'.repeat(32)]) {
    const api = recordingApi();
    await action.onExecutePostLogin(
      {
        resource_server: {identifier: action._contract.API_AUDIENCE},
        request: {query: {'ext-installation-id': installationId}},
        transaction: {protocol: 'oidc-basic-profile'},
      },
      api,
    );

    assert.equal(api.denials.length, 1);
    assert.deepEqual(api.claims, {});
  }
});

test('interactive login fails closed without a recorded authentication method', async () => {
  const api = recordingApi();
  await action.onExecutePostLogin(
    {
      resource_server: {identifier: action._contract.API_AUDIENCE},
      request: {
        query: {
          'ext-installation-id': '0123456789abcdef0123456789abcdef',
        },
      },
      authentication: {methods: [{name: 'pwd', timestamp: 'invalid'}]},
      transaction: {protocol: 'oidc-basic-profile'},
    },
    api,
  );

  assert.equal(api.denials.length, 1);
  assert.deepEqual(api.claims, {});
});

test('other resource servers are not modified', async () => {
  const api = recordingApi();
  await action.onExecutePostLogin(
    {resource_server: {identifier: 'https://another.example/api'}},
    api,
  );

  assert.equal(api.denials.length, 0);
  assert.deepEqual(api.claims, {});
});

function recordingApi() {
  const claims = {};
  const denials = [];
  return {
    claims,
    denials,
    access: {
      deny(reason) {
        denials.push(reason);
      },
    },
    accessToken: {
      setCustomClaim(name, value) {
        claims[name] = value;
      },
    },
  };
}
