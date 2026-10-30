"""Web preorder notifications: deliver canonical private outbox events only."""
import hashlib
import hmac
import json
import os
import uuid
from concurrent.futures import ThreadPoolExecutor

import requests
from flask import jsonify, request
from preorder_native_push import send_preorder_native


def preorder_rpc(params, action='delivery'):
    url = os.getenv('SUPABASE_URL', 'https://rytfhjvhjxnbhgitowho.supabase.co').rstrip('/')
    response = requests.post(url + '/functions/v1/web-preorders',
                             json={'action': action, 'params': params}, timeout=25)
    response.raise_for_status()
    result = response.json()
    if not isinstance(result, dict) or result.get('ok') is not True:
        raise ValueError('Preorder delivery unavailable')
    return result.get('data') or {}


def register_preorder_routes(app, send_push):
    @app.post('/api/push/preorder-event')
    def preorder_event():
        expected = os.getenv('ORDER_PUSH_SECRET', '').strip()
        supplied = request.headers.get('X-Muhajeer-Push-Secret', '').strip()
        if not expected or not hmac.compare_digest(expected, supplied):
            return jsonify(error='Unauthorized'), 401
        body = request.get_json(silent=True) or {}
        try:
            event_id = str(uuid.UUID(str(body.get('event_id', ''))))
        except (ValueError, TypeError):
            return jsonify(error='Invalid event'), 400
        params = {'p_secret': supplied, 'p_event_id': event_id}
        try:
            event = preorder_rpc(params)
        except Exception:
            return jsonify(error='Notification queue unavailable'), 502
        if event.get('skip'):
            return jsonify(ok=True, skipped=True)
        subscriptions = event.get('subscriptions') or []
        private_key = os.getenv('VAPID_PRIVATE_KEY', '').strip()
        payload = json.dumps({
            'title': event['title'], 'body': event['body'], 'url': event['url'],
            'tag': event['tag'], 'open_inbox': event['audience'] == 'customer',
            'icon': '/icons/Icon-192.png', 'badge': '/icons/Icon-192.png',
        }, ensure_ascii=False)

        def deliver(row):
            endpoint = str(row.get('endpoint', ''))
            key = hashlib.md5(endpoint.encode()).hexdigest()  # Opaque deduplication key, not authentication.
            if not private_key:
                return None
            try:
                send_push(subscription_info={
                    'endpoint': endpoint,
                    'keys': {'p256dh': row['p256dh'], 'auth': row['auth']},
                }, data=payload, vapid_private_key=private_key,
                    vapid_claims={'sub': 'https://muhajeer-books-live-production.up.railway.app'},
                    ttl=86400, timeout=8)
                return key
            except Exception as exc:
                # Expired subscriptions cannot receive this message; leave the in-app copy intact.
                status = getattr(getattr(exc, 'response', None), 'status_code', 0)
                return key if status in (404, 410) else None

        with ThreadPoolExecutor(max_workers=6) as pool:
            results = list(pool.map(deliver, subscriptions))
        delivered = [key for key in results if key is not None]
        failed = len(results) - len(delivered)
        native_recipient_count = 0
        try:
            # The event is read from the database, never from the request body.
            # Legacy outbox claim responses lack the reference until migration.
            if not event.get('reference'):
                raise ValueError('Preorder event lacks reference')
            native_recipients = preorder_rpc({
                'p_event_secret': supplied,
                'p_source': 'web',
                'p_reference': str(event['reference']),
                'p_audience': event['audience'],
            }, action='delivery_recipients')
            extra, native_recipient_count, native_failed = send_preorder_native(
                {**event, 'source': 'web'}, native_recipients)
            delivered += extra
            failed += native_failed
        except Exception as exc:
            # Keep the existing Web Push/in-app notification available if
            # native push infrastructure is temporarily unavailable.
            print("Preorder native push:", type(exc).__name__, flush=True)
            failed += 1
        try:
            preorder_rpc({**params, 'p_result': {
                'claim_token': event['claim_token'], 'delivered_keys': delivered,
                'failed': failed, 'recipients': len(subscriptions) + native_recipient_count,
                'error': 'Push qayta yuborish navbatida' if failed else '',
            }})
        except Exception:
            return jsonify(error='Delivery receipt unavailable'), 502
        return jsonify(ok=True, sent=len(delivered), failed=failed)

    @app.post('/api/push/native-preorder-event')
    def native_preorder_event():
        expected = os.getenv('ORDER_PUSH_SECRET', '').strip()
        supplied = request.headers.get('X-Muhajeer-Push-Secret', '').strip()
        if not expected or not hmac.compare_digest(expected, supplied):
            return jsonify(error='Unauthorized'), 401
        data = request.get_json(silent=True) or {}
        try:
            event_id = str(uuid.UUID(str(data.get('event_id', ''))))
        except (ValueError, TypeError):
            return jsonify(error='Invalid event'), 400
        params = {'p_secret': supplied, 'p_event_id': event_id}
        try:
            event = preorder_rpc(params, action='delivery_native')
            if event.get('skip'):
                return jsonify(ok=True, skipped=True)
            recipients = preorder_rpc({
                'p_event_secret': supplied,
                'p_source': 'native',
                'p_reference': str(event['reference']),
                'p_audience': event['audience'],
            }, action='delivery_recipients')
            delivered, attempted, failed = send_preorder_native(
                {**event, 'source': 'native'}, recipients)
            preorder_rpc({**params, 'p_result': {
                'claim_token': event['claim_token'],
                'delivered_keys': delivered, 'failed': failed,
                'recipients': attempted,
                'error': 'Native push retry pending' if failed else '',
            }}, action='delivery_native')
            return jsonify(ok=True, sent=len(delivered), failed=failed)
        except Exception as exc:
            print("Native preorder delivery:", type(exc).__name__, flush=True)
            return jsonify(error='Native preorder notification unavailable'), 502

