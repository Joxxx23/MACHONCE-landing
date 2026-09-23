import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, describe, mock, test } from 'node:test';
import { createServer } from 'vite';

const testUrl = 'https://waitlist-tests.example';
const testKey = 'sb_publishable_local_test_value';
const servers = [];
let service;
let requests = [];
let respond;

async function loadService(url = testUrl, key = testKey) {
  const server = await createServer({
    configFile: false,
    envDir: false,
    logLevel: 'silent',
    appType: 'custom',
    server: { middlewareMode: true, watch: null },
    define: {
      'import.meta.env.VITE_SUPABASE_URL': JSON.stringify(url),
      'import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY': JSON.stringify(key),
    },
  });
  servers.push(server);
  return server.ssrLoadModule('/src/waitlist.js');
}

function apiError(code, status) {
  return Response.json({ code, message: 'Internal database detail', details: 'Private detail' }, { status });
}

describe('waitlist service with the official Supabase client and a mocked HTTP transport', () => {
  before(async () => {
    mock.method(globalThis, 'fetch', async (input, init) => {
      const request = new Request(input, init);
      requests.push(request);
      return respond(request);
    });
    service = await loadService();
  });

  beforeEach(() => {
    requests = [];
    respond = () => Response.json({ accepted: true });
  });

  after(async () => {
    await Promise.all(servers.map(server => server.close()));
    mock.restoreAll();
  });

  test('trims and lowercases; calls only join_waitlist with email and consent version', async () => {
    assert.equal(await service.submitEmail('  Player+Early@Example.COM  ', true), 'accepted');
    assert.equal(requests.length, 1);
    const request = requests[0];
    assert.equal(request.method, 'POST');
    assert.equal(request.url, `${testUrl}/rest/v1/rpc/join_waitlist`);
    assert.deepEqual(await request.json(), {
      email: 'player+early@example.com',
      consent_version: 'waitlist-v2-2026-09-18',
    });
    assert.equal(request.headers.get('content-profile'), 'public');
    assert.equal(request.headers.get('apikey'), testKey);
    assert.doesNotMatch(request.headers.get('prefer') ?? '', /return=representation|resolution=/);
  });

  test('missing, false or truthy non-boolean consent never sends a request', async () => {
    for (const consent of [undefined, false, null, 'true', 1]) {
      await assert.rejects(service.submitEmail('player@example.com', consent), { message: 'Consent is required.' });
    }
    assert.equal(requests.length, 0);
  });

  test('the visible consent text and durable version record agree exactly', async () => {
    const expectedText = 'I’m 16+ and want MACHONCE early-access, closed-alpha and launch emails. I can unsubscribe anytime.';
    const [html, record] = await Promise.all([
      readFile(new URL('../index.html', import.meta.url), 'utf8'),
      readFile(new URL('../docs/privacy/consent-history.md', import.meta.url), 'utf8'),
    ]);
    assert.equal(html.match(/<label for="consent">([^<]+)<\/label>/)?.[1], expectedText);
    assert.ok(record.includes(expectedText));
    assert.equal(service.CONSENT_VERSION, 'waitlist-v2-2026-09-18');
    assert.ok(record.includes(service.CONSENT_VERSION));
  });

  test('new and repeated RPC acknowledgements have the same client result', async () => {
    assert.equal(await service.submitEmail('player@example.com', true), 'accepted');
    assert.equal(await service.submitEmail('player@example.com', true), 'accepted');
    assert.equal(requests.length, 2);
  });

  for (const body of [null, {}, { accepted: false }, { accepted: 'true' }]) {
    test(`RPC acknowledgement ${JSON.stringify(body)} is not success`, async () => {
      respond = () => Response.json(body);
      await assert.rejects(service.submitEmail('player@example.com', true), { message: 'Waitlist request failed.' });
      assert.equal(requests.length, 1);
    });
  }

  test('historical v1 text remains in the original record and consent history', async () => {
    const text = 'Yes, I’d like to receive MACHONCE early-access, closed-alpha and launch emails. I confirm that I am 16 or older. I can unsubscribe at any time.';
    for (const path of ['../docs/consent-versions.md', '../docs/privacy/consent-history.md']) {
      assert.ok((await readFile(new URL(path, import.meta.url), 'utf8')).includes(text));
    }
  });

  for (const [name, code, status] of [
    ['unexpected duplicate error from an incorrect RPC', '23505', 409],
    ['permission denied', '42501', 403],
    ['other integrity error', '23514', 409],
    ['server error', 'XX000', 503],
  ]) {
    test(`${name} stays a generic failure, with no retry or database details`, async () => {
      respond = () => apiError(code, status);
      await assert.rejects(service.submitEmail('player@example.com', true), { message: 'Waitlist request failed.' });
      assert.equal(requests.length, 1);
    });
  }

  test('a network exception does not expose internal details', async () => {
    respond = () => { throw new TypeError('Private network detail'); };
    await assert.rejects(service.submitEmail('player@example.com', true), { message: 'Waitlist request failed.' });
    assert.equal(requests.length, 1);
  });

  test('malformed API responses cannot produce a false success', async () => {
    respond = () => new Response('<html>Unavailable</html>', { status: 200 });
    await assert.rejects(service.submitEmail('player@example.com', true));
    assert.equal(requests.length, 1);
  });

  test('the request has a ten-second timeout and an abort returns an error', async context => {
    const timeout = AbortSignal.timeout.bind(AbortSignal);
    context.mock.method(AbortSignal, 'timeout', milliseconds => {
      assert.equal(milliseconds, 10000);
      return timeout(5);
    });
    respond = request => new Promise((resolve, reject) => {
      const guard = setTimeout(() => reject(new Error('Abort signal did not fire')), 1000);
      request.signal.addEventListener('abort', () => {
        clearTimeout(guard);
        reject(request.signal.reason);
      }, { once: true });
    });
    await assert.rejects(service.submitEmail('player@example.com', true), { message: 'Waitlist request failed.' });
    assert.equal(requests.length, 1);
  });

  for (const [name, url, key] of [
    ['missing configuration', '', ''],
    ['missing URL', '', testKey],
    ['missing key', testUrl, ''],
    ['non-publishable key', testUrl, 'not-a-publishable-key'],
    ['malformed URL', 'not-a-url', testKey],
  ]) {
    test(`${name} fails without making a request`, async () => {
      const unavailable = await loadService(url, key);
      await assert.rejects(unavailable.submitEmail('player@example.com', true), { message: 'Waitlist is unavailable.' });
      assert.equal(requests.length, 0);
    });
  }
});
