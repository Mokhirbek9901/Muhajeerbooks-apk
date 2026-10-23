"""Customer APNs delivery for phone-linked opted-in iOS devices.

Admin APNs registration is a separate path and cannot be used as a customer
recipient. The source-of-truth recipient list is protected by the event secret.
No credentials or device tokens are logged.
"""
import os
import time


def send_customer_apns_order_event(event_secret, phone, notifications, order, rpc):
    key_id = os.getenv("APPLE_APNS_KEY_ID", "").strip()
    team_id = os.getenv("APPLE_APNS_TEAM_ID", "").strip()
    key = os.getenv("APPLE_APNS_PRIVATE_KEY", "").strip().replace("\\n", "\n")
    if not (key_id and team_id and key):
        return {"configured": False, "devices": 0, "sent": 0, "failed": 0}
    recipients = rpc("event_customer_apns_for_phone", {
        "p_event_secret": event_secret, "p_phone": phone,
    })
    if not isinstance(recipients, list):
        return {"configured": True, "devices": 0, "sent": 0,
                "failed": 0, "lookup_error": True}
    tokens = list(dict.fromkeys(
        str(recipient.get("token", "")).lower()
        for recipient in recipients if isinstance(recipient, dict)
    ))
    tokens = [token for token in tokens if 64 <= len(token) <= 200
              and all(char in "0123456789abcdef" for char in token)]
    if not tokens:
        return {"configured": True, "devices": 0, "sent": 0, "failed": 0}
    try:
        import jwt
        import httpx
        bearer = jwt.encode(
            {"iss": team_id, "iat": int(time.time())},
            key, algorithm="ES256", headers={"kid": key_id},
        )
        headers = {
            "authorization": f"bearer {bearer}",
            "apns-topic": "com.muhajeerbooks.app",
            "apns-push-type": "alert",
            "apns-priority": "10",
        }
        sent = failed = 0
        order_id = str(order.get("order_id") or "")[:64]
        order_number = str(order.get("order_number") or "")[:24]
        with httpx.Client(http2=True, timeout=8.0) as client:
            for note in notifications:
                message = {
                    "aps": {"alert": {
                        "title": str(note.get("title", ""))[:200],
                        "body": str(note.get("body", ""))[:950],
                    }, "sound": "default"},
                    "kind": "customer_order",
                    "order_id": order_id, "order_number": order_number,
                }
                for token in tokens:
                    try:
                        response = client.post(
                            f"https://api.push.apple.com/3/device/{token}",
                            json=message, headers=headers,
                        )
                        if response.status_code == 200:
                            sent += 1
                        else:
                            failed += 1
                            reason = ""
                            try:
                                reason = str(response.json().get("reason", ""))[:80]
                            except Exception:
                                pass
                            print(f"Customer APNs HTTP {response.status_code}: {reason}", flush=True)
                    except Exception as exc:
                        failed += 1
                        print(f"Customer APNs request error: {type(exc).__name__}", flush=True)
        return {"configured": True, "devices": len(tokens), "sent": sent, "failed": failed}
    except Exception as exc:
        print(f"Customer APNs configuration error: {type(exc).__name__}", flush=True)
        return {"configured": True, "devices": len(tokens), "sent": 0,
                "failed": len(tokens) * len(notifications)}
