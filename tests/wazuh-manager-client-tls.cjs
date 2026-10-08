// Exercise the installed Wazuh client, not a replacement HTTP implementation.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { ServerAPIClient } = require(process.argv[2]);
const fixture = JSON.parse(fs.readFileSync(0, 'utf8'));
const client = new ServerAPIClient({}, { get: async () => fixture.host }, {});

(async () => {
  if (fixture.mode === 'untrusted') {
    let refused = false;
    try {
      await client.asInternalUser.authenticate('fixture');
    } catch (error) {
      refused = ['UNABLE_TO_VERIFY_LEAF_SIGNATURE', 'UNABLE_TO_GET_ISSUER_CERT_LOCALLY',
        'SELF_SIGNED_CERT_IN_CHAIN', 'DEPTH_ZERO_SELF_SIGNED_CERT'].includes(error.code);
    }
    assert(refused, 'Installed manager client accepted an untrusted TLS endpoint');
  } else {
    const token = await client.asInternalUser.authenticate('fixture');
    if (fixture.mode === 'live') {
      assert.equal(typeof token, 'string');
      assert(token.length > 20);
      const reply = await client.asInternalUser.request('GET', '/manager/info', {},
        { apiHostID: 'fixture' });
      assert.equal(reply.status, 200);
      assert.equal(reply.data.error, 0);
      assert.match(reply.data.data.affected_items[0].version, /^v?4\.14\.8$/);
      return;
    }
    assert.equal(token, fixture.token);
    const reply = await client.asInternalUser.request('GET', '/fixture', {},
      { apiHostID: 'fixture' });
    assert.equal(reply.data.marker, 'authenticated-manager-client');
    let refused = false;
    try {
      await client.asInternalUser.request('GET', '/redirect', {},
        { apiHostID: 'fixture' });
    } catch (error) {
      refused = error.response?.status === 302;
    }
    assert(refused, 'Installed manager client followed a credential-bearing redirect');
  }
})().catch(() => {
  // Axios errors may contain credentials: deliberately emit no error object.
  process.stderr.write('Installed manager client TLS/redirect assertion failed\n');
  process.exitCode = 1;
});
