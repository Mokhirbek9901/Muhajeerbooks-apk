"""Exercise the real Flask routes; all provider/network calls are mocked."""
import json
import os
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import app as gateway


class PushGatewayTests(unittest.TestCase):
    def setUp(self):
        self.client = gateway.app.test_client()

    def test_status_is_admin_only(self):
        with patch.object(gateway, '_verify_admin_code', return_value=False):
            self.assertEqual(self.client.post('/api/push/apns-status', json={}).status_code, 401)
        with patch.object(gateway, '_verify_admin_code', return_value=True), patch.dict(os.environ, {'APPLE_APNS_KEY_ID': '', 'APPLE_APNS_PRIVATE_KEY': ''}):
            result = self.client.post('/api/push/apns-status', json={'admin_code': 'test'}).get_json()
        self.assertFalse(result['configured'])

    def test_admin_diagnostic_requires_event_authentication(self):
        with patch.dict(os.environ, {'ORDER_PUSH_SECRET': 'test-secret'}), patch.object(gateway, '_admin_rpc_call') as rpc:
            response = self.client.post('/api/push/order-event', json={'event': 'admin_test'})
        self.assertEqual(response.status_code, 401)
        rpc.assert_not_called()

    def test_diagnostic_reaches_only_verified_admin_devices(self):
        subscription = {'endpoint': 'https://push.example/admin', 'p256dh': 'test', 'auth': 'test'}
        with patch.dict(os.environ, {'ORDER_PUSH_SECRET': 'test-secret', 'VAPID_PRIVATE_KEY': 'test-key'}), patch.object(gateway, '_admin_rpc_call', return_value=[subscription]) as rpc, patch.object(gateway, 'webpush') as send, patch.object(gateway, '_send_admin_apns_order_event', return_value={'configured': False, 'devices': 0, 'sent': 0, 'failed': 0}) as apns, patch.object(gateway, 'send_customer_apns_order_event') as customer:
            response = self.client.post('/api/push/order-event', json={'event': 'admin_test'}, headers={'X-Muhajeer-Push-Secret': 'test-secret'})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json()['sent'], 1)
        rpc.assert_called_once_with('event_admin_order_push_subscriptions', {'p_event_secret': 'test-secret'})
        customer.assert_not_called()
        apns.assert_called_once()
        payload = json.loads(send.call_args.kwargs['data'])
        self.assertIn('Push sinovi', payload['title'])
        self.assertIn('Yangi buyurtma emas', payload['body'])
        self.assertFalse(payload['open_inbox'])

    def test_normal_order_still_uses_customer_recipients(self):
        with patch.dict(os.environ, {'ORDER_PUSH_SECRET': 'test-secret'}), patch.object(gateway, '_admin_rpc_call', return_value=[]) as rpc, patch.object(gateway, 'send_customer_apns_order_event', return_value={'configured': False}) as customer, patch.object(gateway, '_send_admin_apns_order_event') as admin:
            response = self.client.post('/api/push/order-event', json={'event': 'shipping', 'phone': '01000000000'}, headers={'X-Muhajeer-Push-Secret': 'test-secret'})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(rpc.call_args.args[0], 'event_customer_device_webpush')
        customer.assert_called_once()
        admin.assert_not_called()

    def test_customer_diagnostic_requires_server_event_authentication(self):
        with patch.object(gateway, 'send_customer_apns_test') as ios, patch.object(gateway, 'send_android_customer_test') as android:
            for expected, supplied in [('test-secret', ''), ('test-secret', 'wrong'), ('', '')]:
                with patch.dict(os.environ, {'ORDER_PUSH_SECRET': expected}):
                    response = self.client.post('/api/push/order-event', json={'event':'customer_test'}, headers={'X-Muhajeer-Push-Secret':supplied})
                self.assertEqual(response.status_code, 401)
            ios.assert_not_called()
            android.assert_not_called()

    def test_customer_diagnostic_never_sends_admin_or_web_or_writes_order_inbox(self):
        ios_result = {'configured':True, 'devices':1, 'sent':1, 'failed':0}
        android_result = {'configured':False, 'devices':0, 'sent':0, 'failed':0}
        with patch.dict(os.environ, {'ORDER_PUSH_SECRET':'test-secret'}), patch.object(gateway, 'send_customer_apns_test', return_value=ios_result) as ios, patch.object(gateway, 'send_android_customer_test', return_value=android_result) as android, patch.object(gateway, '_admin_rpc_call') as rpc, patch.object(gateway, '_send_admin_apns_order_event') as admin, patch.object(gateway, 'send_customer_apns_order_event') as order, patch.object(gateway, 'webpush') as web:
            response = self.client.post('/api/push/order-event', json={'event':'customer_test', 'phone':'01012345678', 'order_id':'private-order', 'title':'ignore this', 'message':'private data'}, headers={'X-Muhajeer-Push-Secret':'test-secret'})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json()['audience'], 'customers')
        self.assertEqual(response.get_json()['sent'], 1)
        ios.assert_called_once()
        android.assert_called_once()
        self.assertIs(ios.call_args.args[1], rpc)
        self.assertIs(android.call_args.args[1], rpc)
        self.assertEqual(ios.call_args.args[0], 'test-secret')
        self.assertEqual(android.call_args.args[0], 'test-secret')
        for operation in (rpc, admin, order, web):
            operation.assert_not_called()


if __name__ == '__main__':
    unittest.main()
