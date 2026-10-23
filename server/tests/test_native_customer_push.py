import os
import sys
import types
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from native_customer_push import send_customer_apns_order_event


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
        self.assertEqual(posts[0][2]["apns-topic"], "com.muhajeerbooks.app")
        lookup.assert_called_once_with("event_customer_apns_for_phone", {
            "p_event_secret": "event-secret", "p_phone": "01012345678",
        })

if __name__ == "__main__":
    unittest.main()
