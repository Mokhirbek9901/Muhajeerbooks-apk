import os
import sys
import types
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from native_customer_push import send_customer_apns_order_event, send_customer_apns_broadcast, send_customer_apns_test


class NativeCustomerPushTest(unittest.TestCase):
    def setUp(self):
        self.note = [{"title": "Buyurtma qabul qilindi", "body": "Muhajeer Books"}]
        self.order = {"order_id": "abc", "order_number": 204}

    def test_without_apns_credentials_stays_safe(self):
        lookup = Mock(side_effect=AssertionError("no network without credentials"))
        with patch.dict(os.environ, {
            "APPLE_APNS_KEY_ID": "",
            "APPLE_APNS_TEAM_ID": "",
            "APPLE_APNS_PRIVATE_KEY": "",
        }):
            result = send_customer_apns_order_event(
                "event", "01012345678", self.note, self.order, lookup
            )
        self.assertFalse(result["configured"])
        lookup.assert_not_called()

    def test_missing_recipient_lookup_is_not_reported_as_delivery(self):
        with patch.dict(os.environ, {
            "APPLE_APNS_KEY_ID": "key",
            "APPLE_APNS_TEAM_ID": "team",
            "APPLE_APNS_PRIVATE_KEY": "keydata",
        }):
            result = send_customer_apns_order_event(
                "event", "01012345678", self.note, self.order, lambda *_: None,
            )
        self.assertTrue(result["lookup_error"])
        self.assertEqual(result["sent"], 0)

    def test_exact_phone_opt_in_tokens_deduplicated_and_sent(self):
        token = "a" * 64
        posts = []
        class Client:
            def __init__(self, **kwargs):
                self.kwargs = kwargs
            def __enter__(self):
                return self
            def __exit__(self, *_):
                return False
            def post(self, url, json, headers):
                posts.append((url, json, headers))
                return types.SimpleNamespace(status_code=200)
        jwt = types.SimpleNamespace(encode=lambda *args, **kwargs: "signed-token")
        httpx = types.SimpleNamespace(Client=Client)
        lookup = Mock(return_value=[
            {"token": token}, {"token": token}, {"token": "bad-format"}
        ])
        with patch.dict(os.environ, {
            "APPLE_APNS_KEY_ID": "key",
            "APPLE_APNS_TEAM_ID": "team",
            "APPLE_APNS_PRIVATE_KEY": "keydata",
        }), patch.dict(sys.modules, {"jwt": jwt, "httpx": httpx}):
            result = send_customer_apns_order_event(
                "event-secret", "01012345678", self.note, self.order, lookup,
            )
        self.assertEqual(result["devices"], 1)
        self.assertEqual(result["sent"], 1)
        self.assertEqual(result["failed"], 0)
        self.assertEqual(len(posts), 1)
        self.assertTrue(posts[0][0].endswith(token))
        self.assertEqual(posts[0][1]["kind"], "customer_order")
        self.assertEqual(posts[0][1].get("order_id"), "abc")
        self.assertNotIn("order_number", posts[0][1])
        self.assertNotIn("amount", posts[0][1])
        self.assertEqual(posts[0][2]["apns-topic"], "com.muhajeerbooks.app")
        lookup.assert_called_once_with("event_customer_device_apns", {
            "p_event_secret": "event-secret", "p_phone": "01012345678", "p_order_id": "abc",
        })


    def test_broadcast_without_apns_key_does_not_claim_success(self):
        rpc = Mock(side_effect=AssertionError("credentials missing"))
        with patch.dict(os.environ, {
            "APPLE_APNS_KEY_ID": "",
            "APPLE_APNS_TEAM_ID": "",
            "APPLE_APNS_PRIVATE_KEY": "",
        }):
            outcome = send_customer_apns_broadcast(
                "verified-admin", "Yangi kitob", "Barcha mijozlarga", rpc)
        self.assertFalse(outcome["configured"])
        self.assertEqual(outcome["sent"], 0)
        rpc.assert_not_called()

    def test_broadcast_is_public_and_admin_authorized(self):
        token = "a" * 64
        calls = []
        class Client:
            def __init__(self, **kwargs):
                pass
            def __enter__(self):
                return self
            def __exit__(self, *_):
                return False
            def post(self, url, json, headers):
                calls.append((url, json, headers))
                return types.SimpleNamespace(status_code=200)
        rpc = Mock(return_value=[{"token": token}, {"token": token}])
        with patch.dict(os.environ, {
            "APPLE_APNS_KEY_ID": "keyid",
            "APPLE_APNS_TEAM_ID": "teamid",
            "APPLE_APNS_PRIVATE_KEY": "mock-private-key",
        }), patch.dict(sys.modules, {
            "jwt": types.SimpleNamespace(encode=lambda *a, **k: "signed"),
            "httpx": types.SimpleNamespace(Client=Client),
        }):
            result = send_customer_apns_broadcast(
                "verified-admin", "Yangi kitob", "Yangi kitob keldi!", rpc)
        rpc.assert_called_once_with(
            "admin_release_apns_broadcast_recipients",
            {"p_secret": "verified-admin"},
        )
        self.assertEqual(result["sent"], 1)
        self.assertEqual(result["devices"], 1)
        self.assertEqual(len(calls), 1)
        payload = calls[0][1]
        self.assertEqual(payload["kind"], "customer_broadcast")
        self.assertEqual(payload["aps"]["sound"], "default")
        self.assertNotIn("order_id", payload)
        self.assertNotIn("customer_name", payload)
        self.assertNotIn("address", payload)

    def test_broadcast_does_not_accept_unverified_lookup(self):
        with patch.dict(os.environ, {
            "APPLE_APNS_KEY_ID": "keyid",
            "APPLE_APNS_TEAM_ID": "teamid",
            "APPLE_APNS_PRIVATE_KEY": "mock-private-key",
        }):
            result = send_customer_apns_broadcast(
                "wrong-admin", "Hi", "Hello", lambda *args: None)
        self.assertTrue(result["lookup_error"])
        self.assertEqual(result["sent"], 0)

    def test_customer_test_uses_event_authorized_customer_lookup_and_fixed_public_text(self):
        rpc = Mock(return_value=[{'token':'a'*64}])
        posts = []
        class Client:
            def __init__(self, **kwargs): pass
            def __enter__(self): return self
            def __exit__(self, *_): return False
            def post(self, url, json, headers):
                posts.append(json)
                return types.SimpleNamespace(status_code=200)
        with patch.dict(os.environ, {'APPLE_APNS_KEY_ID':'key','APPLE_APNS_PRIVATE_KEY':'mock-private-key'}), patch.dict(sys.modules, {'jwt':types.SimpleNamespace(encode=lambda *a,**k:'signed'), 'httpx':types.SimpleNamespace(Client=Client)}):
            result = send_customer_apns_test('event-secret', rpc)
        rpc.assert_called_once_with('event_customer_apns_test_recipients', {'p_event_secret':'event-secret'})
        self.assertEqual(result['sent'], 1)
        self.assertEqual(posts[0]['kind'], 'customer_broadcast')
        self.assertIn('Mijoz push sinovi', posts[0]['aps']['alert']['title'])
        self.assertNotIn('order_id', posts[0])

if __name__ == "__main__":
    unittest.main()
