import json
import os
import sys
import unittest
from pathlib import Path
from unittest.mock import Mock, patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from flask import Flask
from preorder_delivery import register_preorder_routes

EVENT = '12345678-1234-4234-8234-123456789abc'


class DeliveryTests(unittest.TestCase):
    def setUp(self):
        self.sender = Mock()
        app = Flask(__name__)
        register_preorder_routes(app, self.sender)
        self.client = app.test_client()
        self.env = patch.dict(os.environ, ORDER_PUSH_SECRET='test-secret', VAPID_PRIVATE_KEY='test-key')
        self.env.start()
        self.addCleanup(self.env.stop)

    def post(self, **data):
        return self.client.post('/api/push/preorder-event', json=data,
                                headers={'X-Muhajeer-Push-Secret': 'test-secret'})

    @patch('preorder_delivery.preorder_rpc')
    def test_unauthorized_request_never_reaches_queue(self, rpc):
        self.assertEqual(self.client.post('/api/push/preorder-event', json={'event_id': EVENT}).status_code, 401)
        rpc.assert_not_called()

    @patch('preorder_delivery.preorder_rpc')
    def test_duplicate_event_is_skipped(self, rpc):
        rpc.return_value = {'skip': True}
        self.assertEqual(self.post(event_id=EVENT).status_code, 200)
        self.sender.assert_not_called()

    def event(self):
        return {'claim_token': EVENT, 'title': 'canonical', 'body': 'from database',
                'url': '/?open=notifications', 'tag': 'event-stable-tag', 'audience': 'customer',
                'subscriptions': [{'endpoint': 'https://push.example/test', 'p256dh': 'key', 'auth': 'auth'}]}

    @patch('preorder_delivery.preorder_rpc')
    def test_payload_injection_is_ignored_and_delivery_is_acknowledged(self, rpc):
        rpc.side_effect = [self.event(), {'ok': True}]
        response = self.post(event_id=EVENT, phone='attacker', title='fake', body='fake')
        self.assertEqual(response.status_code, 200)
        payload = json.loads(self.sender.call_args.kwargs['data'])
        self.assertEqual(payload['title'], 'canonical')
        self.assertEqual(payload['body'], 'from database')
        result = rpc.call_args.args[0]['p_result']
        self.assertEqual(result['failed'], 0)
        self.assertEqual(len(result['delivered_keys']), 1)

    @patch('preorder_delivery.preorder_rpc')
    def test_transient_failure_remains_retryable(self, rpc):
        rpc.side_effect = [self.event(), {'ok': True}]
        self.sender.side_effect = TimeoutError()
        self.assertEqual(self.post(event_id=EVENT).status_code, 200)
        result = rpc.call_args.args[0]['p_result']
        self.assertEqual(result['failed'], 1)
        self.assertEqual(result['delivered_keys'], [])

    @patch('preorder_delivery.preorder_rpc')
    def test_no_push_permission_keeps_durable_inbox_and_finishes_without_key(self, rpc):
        event = self.event(); event['subscriptions'] = []
        rpc.side_effect = [event, {'ok': True}]
        with patch.dict(os.environ, VAPID_PRIVATE_KEY=''):
            self.assertEqual(self.post(event_id=EVENT).status_code, 200)
        self.sender.assert_not_called()
        self.assertEqual(rpc.call_args.args[0]['p_result']['recipients'], 0)


if __name__ == '__main__':
    unittest.main()
