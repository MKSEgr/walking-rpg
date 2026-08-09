const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const templatePath = path.join(__dirname, 'connection.template.json');
const templateText = fs.readFileSync(templatePath, 'utf8');
const connection = JSON.parse(templateText);

test('Telegram uses the reviewed Auth0 OIDC and PKCE boundary', () => {
  assert.equal(connection.name, 'telegram');
  assert.equal(connection.display_name, 'Telegram');
  assert.equal(connection.strategy, 'oidc');
  assert.equal(connection.show_as_button, true);
  assert.equal(connection.is_domain_connection, false);
  assert.deepEqual(connection.authentication, {active: true});
  assert.equal('enabled_clients' in connection, false);

  assert.equal(connection.options.type, 'back_channel');
  assert.equal(
    connection.options.discovery_url,
    'https://oauth.telegram.org/.well-known/openid-configuration',
  );
  assert.deepEqual(connection.options.connection_settings, {pkce: 's256'});
});

test('Telegram requests only the minimum identity scopes', () => {
  const scopes = connection.options.scopes.split(/\s+/);

  assert.deepEqual(scopes, ['openid', 'profile']);
  assert.equal(scopes.includes('phone'), false);
  assert.equal(scopes.includes('telegram:bot_access'), false);
  assert.equal('userinfo_scope' in connection.options.attribute_map, false);
  assert.deepEqual(connection.options.attribute_map, {
    mapping_mode: 'use_map',
    attributes: {
      name: '${context.tokenset.name}',
      username: '${context.tokenset.preferred_username}',
      picture: '${context.tokenset.picture}',
    },
  });
});

test('Telegram credentials remain explicit unresolved placeholders', () => {
  assert.equal(
    connection.options.client_id,
    '@@TELEGRAM_CLIENT_ID@@',
  );
  assert.equal(
    connection.options.client_secret,
    '@@TELEGRAM_CLIENT_SECRET@@',
  );
  assert.deepEqual(
    [...templateText.matchAll(/@@[A-Z0-9_]+@@/g)].map((match) => match[0]),
    ['@@TELEGRAM_CLIENT_ID@@', '@@TELEGRAM_CLIENT_SECRET@@'],
  );
  assert.equal(templateText.includes('phone_number'), false);
  assert.equal(templateText.includes('telegram:bot_access'), false);
});
