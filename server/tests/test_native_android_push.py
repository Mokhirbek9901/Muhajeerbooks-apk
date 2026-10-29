import json
import os
from pathlib import Path
import sys
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import native_android_push as fcm

KEY = json.dumps({'type':'service_account','project_id':'muhajeer-books-push',
                  'client_email':'sender@example.invalid',
                  'private_key':'-----BEGIN PRIVATE KEY-----\ntest'})
TOKEN = 'A_test-FCM_token:'+'b'*60


class AndroidPushTests(unittest.TestCase):
    def test_missing_credentials_never_enumerates_recipients_or_claims_delivery(self):
        rpc=Mock()
        with patch.dict(os.environ,{'FIREBASE_SERVICE_ACCOUNT_JSON':''}):
            result=fcm.send_android_broadcast('admin','test','test','id',rpc)
        self.assertFalse(result['configured'])
        self.assertEqual(result['sent'],0)
        rpc.assert_not_called()

    def test_wrong_firebase_project_is_not_enabled(self):
        wrong = json.loads(KEY)
        wrong['project_id'] = 'unrelated-project'
        with patch.dict(os.environ, {'FIREBASE_SERVICE_ACCOUNT_JSON': json.dumps(wrong)}):
            self.assertFalse(fcm.fcm_configured())

    def test_bad_credentials_and_lookup_are_not_success(self):
        with patch.dict(os.environ,{'FIREBASE_SERVICE_ACCOUNT_JSON':'not json'}):
            self.assertFalse(fcm.fcm_configured())
        with patch.dict(os.environ,{'FIREBASE_SERVICE_ACCOUNT_JSON':KEY}):
            result=fcm.send_android_broadcast('admin','test','test','id',lambda *_:None)
        self.assertTrue(result['lookup_error'])
        self.assertEqual(result['sent'],0)

    def test_customer_orders_target_only_session_bound_customer_lookup(self):
        rpc=Mock(return_value=[{'token':TOKEN},{'token':TOKEN},{'token':'bad'}])
        with patch.dict(os.environ,{'FIREBASE_SERVICE_ACCOUNT_JSON':KEY}), patch.object(fcm,'_send',return_value=True) as send:
            result=fcm.send_android_order_event('event','01000000000',
                {'title':'private title','body':'private amount'},
                {'event':'shipping','order_id':'order-id','total':999},rpc)
        rpc.assert_called_once_with('event_native_fcm_for_order',
            {'p_event_secret':'event','p_phone':'01000000000','p_order_id':'order-id'})
        self.assertEqual(result['devices'],1)
        self.assertEqual(result['sent'],1)
        args=send.call_args.args
        self.assertNotIn('private',args[1]+args[2])
        self.assertEqual(args[3],{'kind':'customer_order','order_id':'order-id'})

    def test_admin_diagnostic_never_uses_customer_or_broadcast_lookup(self):
        rpc=Mock(return_value=[{'token':TOKEN}])
        with patch.dict(os.environ,{'FIREBASE_SERVICE_ACCOUNT_JSON':KEY}), patch.object(fcm,'_send',return_value=True):
            result=fcm.send_android_order_event('event','',
                {'title':'Push sinovi','body':'Yangi buyurtma emas'},
                {'event':'admin_test'},rpc)
        rpc.assert_called_once_with('event_admin_native_fcm',{'p_event_secret':'event'})
        self.assertEqual(result['sent'],1)

    def test_broadcast_uses_only_admin_authorized_opt_in_lookup(self):
        rpc=Mock(return_value=[{'token':TOKEN}])
        with patch.dict(os.environ,{'FIREBASE_SERVICE_ACCOUNT_JSON':KEY}), patch.object(fcm,'_send',return_value=False):
            result=fcm.send_android_broadcast('verified-admin','Books','New books','message-id',rpc)
        rpc.assert_called_once_with('admin_native_fcm_devices',{'p_secret':'verified-admin'})
        self.assertEqual(result['sent'],0)
        self.assertEqual(result['failed'],1)

    def test_http_v1_uses_high_priority_channel_and_string_data(self):
        session=Mock()
        session.post.return_value.status_code=200
        with patch.object(fcm,'_session',return_value=(session,'https://fcm.googleapis.com/test')):
            self.assertTrue(fcm._send(TOKEN,'Hello','Test',{'kind':'customer_order','id':12},'tag'))
        message=session.post.call_args.kwargs['json']['message']
        self.assertEqual(message['android']['notification']['channel_id'],'muhajeer_books')
        self.assertEqual(message['android']['priority'],'HIGH')
        self.assertEqual(message['data']['id'],'12')
        self.assertEqual(message['token'],TOKEN)

    def test_http_error_does_not_claim_delivery(self):
        session=Mock()
        session.post.return_value.status_code=401
        with patch.object(fcm,'_session',return_value=(session,'https://fcm.googleapis.com/test')):
            self.assertFalse(fcm._send(TOKEN,'Hello','Test',{},'tag'))

    def test_customer_test_targets_only_authenticated_opted_in_customer_lookup(self):
        rpc = Mock(return_value=[{'token':TOKEN}])
        with patch.dict(os.environ, {'FIREBASE_SERVICE_ACCOUNT_JSON':KEY}), patch.object(fcm, '_send', return_value=True) as send:
            result = fcm.send_android_customer_test('event-secret', rpc)
        rpc.assert_called_once_with('event_customer_fcm_test_recipients', {'p_event_secret':'event-secret'})
        self.assertEqual(result['sent'], 1)
        self.assertIn('Mijoz push sinovi', send.call_args.args[1])
        self.assertEqual(send.call_args.args[3], {'kind':'customer_broadcast'})


if __name__=='__main__': unittest.main()
