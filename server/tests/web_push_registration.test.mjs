import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';

const html = readFileSync(new URL('../../web/index.html', import.meta.url), 'utf8');
const script = html.slice(html.lastIndexOf('    (() => {', html.indexOf('const vapidPublicKey')), html.indexOf('  </script>', html.indexOf('const vapidPublicKey')));

function browser() {
  const requests = [];
  const subscription = {endpoint: 'https://push.example/test', toJSON: () => ({endpoint: 'https://push.example/test', keys: {p256dh: 'public', auth: 'auth'}})};
  const registration = {pushManager: {getSubscription: async () => subscription}};
  const context = {
    window: {addEventListener() {}, PushManager: {}, Notification: {}},
    location: {protocol: 'https:'},
    navigator: {userAgent: 'test', serviceWorker: {register: async () => registration, ready: Promise.resolve(registration)}},
    Notification: {permission: 'granted'},
    localStorage: {getItem: () => ''},
    fetch: async (url, init) => {requests.push(JSON.parse(init.body)); return {ok: true, json: async () => ({ok: true})};},
    console, Uint8Array, atob,
  };
  vm.runInNewContext(script, context);
  return {window: context.window, requests};
}

test('granted web permission actually saves an anonymous subscription', async () => {
  const {window, requests} = browser();
  assert.equal(await window.muhajeerEnablePush(), true);
  assert.equal(requests.length, 1);
  assert.equal(requests[0].name, 'customer_push_subscribe');
  assert.equal(requests[0].params.p_phone, '');
  assert.equal(requests[0].params.p_endpoint, 'https://push.example/test');
});

test('verified session reaches the phone-linking RPC without exposing a claimed phone', async () => {
  const {window, requests} = browser();
  assert.equal(await window.muhajeerSyncPushPhone('untrusted-phone', 'session-for-test'), true);
  assert.equal(requests[0].name, 'customer_release_push_subscribe');
  assert.equal(requests[0].params.p_session, 'session-for-test');
  assert.equal('p_phone' in requests[0].params, false);
});

test('permission refresh preserves verified identity and sign-out clears it', async () => {
  const {window, requests} = browser();
  await window.muhajeerSyncPushPhone('ignored', 'session-for-test');
  await window.muhajeerEnablePush();
  assert.equal(requests[1].name, 'customer_release_push_subscribe');
  assert.equal(requests[1].params.p_session, 'session-for-test');
  await window.muhajeerSyncPushPhone('', '');
  await window.muhajeerEnablePush();
  assert.equal(requests[2].name, 'customer_push_subscribe');
  assert.equal(requests[3].name, 'customer_push_subscribe');
  assert.equal('p_session' in requests[3].params, false);
});

test('overlapping startup and login persist in order', async () => {
  const {window, requests} = browser();
  await Promise.all([window.muhajeerEnablePush(), window.muhajeerSyncPushPhone('ignored', 'session-for-test')]);
  assert.equal(requests.at(-1).name, 'customer_release_push_subscribe');
  assert.equal(requests.at(-1).params.p_session, 'session-for-test');
});
