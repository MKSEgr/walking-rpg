const API_AUDIENCE = 'https://api.stepbeyond.game';
const DEVICE_CLAIM = 'https://api.stepbeyond.game/device_id';
const AUTHENTICATION_TIME_CLAIM =
  'https://api.stepbeyond.game/auth_time';
const INSTALLATION_PARAMETER = 'ext-installation-id';
const INSTALLATION_PATTERN = /^[0-9a-f]{32}$/;

/**
 * Auth0 Post Login Action for the Step Beyond native application.
 *
 * The native client supplies a random installation identifier on both the
 * authorization and refresh-token requests. Auth0 validates its bounded
 * format and copies it into the access token so the backend never trusts an
 * unsigned device header. Authentication time is emitted only for an
 * interactive login; a refresh exchange cannot manufacture freshness.
 */
exports.onExecutePostLogin = async (event, api) => {
  if (event.resource_server?.identifier !== API_AUDIENCE) {
    return;
  }

  const refresh =
    event.transaction?.protocol === 'oauth2-refresh-token' ||
    event.request?.body?.grant_type === 'refresh_token';
  const requestValues = refresh
    ? event.request?.body
    : event.request?.query;
  const installationId = requestValues?.[INSTALLATION_PARAMETER];

  if (
    typeof installationId !== 'string' ||
    !INSTALLATION_PATTERN.test(installationId)
  ) {
    api.access.deny('A valid Step Beyond installation ID is required.');
    return;
  }

  if (refresh) {
    api.accessToken.setCustomClaim(DEVICE_CLAIM, installationId);
    return;
  }

  const authenticationTime = latestAuthenticationTime(
    event.authentication?.methods,
  );
  if (authenticationTime === null) {
    api.access.deny('A verified interactive authentication is required.');
    return;
  }
  api.accessToken.setCustomClaim(DEVICE_CLAIM, installationId);
  api.accessToken.setCustomClaim(
    AUTHENTICATION_TIME_CLAIM,
    authenticationTime,
  );
};

function latestAuthenticationTime(methods) {
  if (!Array.isArray(methods)) {
    return null;
  }
  let latest = null;
  for (const method of methods) {
    if (typeof method?.timestamp !== 'string') {
      continue;
    }
    const milliseconds = Date.parse(method.timestamp);
    if (!Number.isFinite(milliseconds)) {
      continue;
    }
    const seconds = Math.floor(milliseconds / 1000);
    latest = latest === null ? seconds : Math.max(latest, seconds);
  }
  return latest;
}

exports._contract = {
  API_AUDIENCE,
  DEVICE_CLAIM,
  AUTHENTICATION_TIME_CLAIM,
  INSTALLATION_PARAMETER,
  latestAuthenticationTime,
};
