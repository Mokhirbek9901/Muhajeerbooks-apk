"""No recipient may be selected by an untrusted preorder webhook body."""
import json
import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch
from flask import Flask
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from preorder_delivery import register_preorder_routes
from preorder_native_push import send_preorder_native

EVENT = 'b67b1f7d-6c31-431f-9afd-cade8a75eaa8'


class NativePreorderPushTests(unittest.TestCase):
    def setUp(self):
        app = Flask(__name__)
        register_preorder_routes(app, lambda **kwargs: None)
        self.client = app.test_client()
        self.patch_env = patch.dict(os.environ, ORDER_PUSH_SECRET='preorder-secret')
        self.patch_env.start()
        self.addCleanup(self.patch_env.stop)

    def test_unknown_caller_cannot_use_native_webhook(self):
        res = self.client.post('/api/push/native-preorder-event',
            json={'event_id': EVENT})
        self.assertEqual(res.status_code, 401)

    @patch('preorder_delivery.send_preorder_native')
    @patch('preorder_delivery.preorder_rpc')
    def test_native_outbox_delivers_only_db_chosen_order_and_audience(self, rpc, send):
        rpc.side_effect = [
            {'claim_token': EVENT, 'source': 'native', 'reference': '81',
             'audience': 'admin', 'delivered_keys': []},
            {'apns': [], 'fcm': []}, {'ok': True}]
        send.return_value = (['b' * 32], 1, 0)
        res = self.client.post('/api/push/native-preorder-event',
            json={'event_id': EVENT, 'reference': '82', 'audience': 'customer'},
            headers={'X-Muhajeer-Push-Secret': 'preorder-secret'})
        self.assertEqual(res.status_code, 200)
        self.assertEqual(rpc.call_args_list[1].kwargs['action'], 'delivery_recipients')
        self.assertEqual(rpc.call_args_list[1].args[0]['p_reference'], '81')
        self.assertEqual(rpc.call_args_list[1].args[0]['p_audience'], 'admin')
        self.assertEqual(rpc.call_args_list[2].args[0]['p_result']['delivered_keys'], ['b' * 32])

    @patch('preorder_delivery.preorder_rpc')
    def test_native_duplicate_is_skipped(self, rpc):
        rpc.return_value = {'skip': True}
        res = self.client.post('/api/push/native-preorder-event',
            json={'event_id': EVENT},
            headers={'X-Muhajeer-Push-Secret': 'preorder-secret'})
        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.json['skipped'])

    @patch('preorder_native_push.send_fcm', return_value=True)
    @patch('preorder_native_push.fcm_configured', return_value=True)
    def test_customer_fcm_has_generic_message_and_deduplicates(self, configured, fcm):
        token = 'z' * 90
        event = {'audience': 'customer', 'source': 'web',
                 'reference': 'abcd', 'delivered_keys': []}
        delivered, attempted, failed = send_preorder_native(
            event, {'apns': [], 'fcm': [token,token]})
        self.assertEqual((attempted,failed,len(delivered)), (1,0,1))
        self.assertEqual(fcm.call_args.args[3]['kind'], 'customer_preorder')
        self.assertNotIn('phone', json.dumps(fcm.call_args.args))
        event['delivered_keys'] = delivered
        self.assertEqual(send_preorder_native(event,
            {'apns': [], 'fcm': [token]}), ([],0,0))


if __name__ == '__main__':
    unittest.main()
