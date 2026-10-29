"""FCM HTTP v1 delivery. Credentials and registration tokens are never logged."""
import hashlib
import json
import os
import re
import threading
from concurrent.futures import ThreadPoolExecutor

_local = threading.local()
_TOKEN = re.compile(r"^[A-Za-z0-9:_-]{40,4096}$")


def fcm_configured():
    try:
        value = json.loads(os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", "{}"))
        return (value.get("type") == "service_account"
                and bool(value.get("project_id"))
                and bool(value.get("client_email"))
                and str(value.get("private_key", "")).startswith("-----BEGIN PRIVATE KEY-----"))
    except (ValueError, TypeError, AttributeError):
        return False


def _session():
    from google.oauth2 import service_account
    from google.auth.transport.requests import AuthorizedSession
    raw = os.environ["FIREBASE_SERVICE_ACCOUNT_JSON"]
    fingerprint = hashlib.sha256(raw.encode()).hexdigest()
    if getattr(_local, "fingerprint", None) != fingerprint:
        info = json.loads(raw)
        project = info["project_id"]
        if not re.fullmatch(r"[a-z][a-z0-9-]{4,62}", project):
            raise ValueError("Invalid Firebase project")
        # Never use a credential-supplied token URI or API hostname.
        info["token_uri"] = "https://oauth2.googleapis.com/token"
        credentials = service_account.Credentials.from_service_account_info(
            info, scopes=["https://www.googleapis.com/auth/firebase.messaging"])
        _local.session = AuthorizedSession(credentials)
        _local.url = f"https://fcm.googleapis.com/v1/projects/{project}/messages:send"
        _local.fingerprint = fingerprint
    return _local.session, _local.url


def _send(token, title, message, data, tag):
    try:
        session, url = _session()
        response = session.post(url, json={"message": {
            "token": token,
            "notification": {"title": title[:120], "body": message[:950]},
            "data": {str(k): str(v) for k, v in data.items()},
            "android": {"priority": "HIGH", "ttl": "86400s", "notification": {
                "channel_id": "muhajeer_books", "sound": "default", "tag": tag[:100],
            }},
        }}, timeout=12)
        if response.status_code == 200:
            return True
        # Log only bounded provider codes, never HTTP bodies or tokens.
        print(f"FCM delivery HTTP {response.status_code}", flush=True)
    except Exception as error:
        print(f"FCM delivery error: {type(error).__name__}", flush=True)
    return False


def _deliver(rpc, operation, params, title, message, data, tag):
    empty = {"configured": fcm_configured(), "devices": 0, "sent": 0, "failed": 0}
    if not empty["configured"]:
        return empty
    rows = rpc(operation, params)
    if not isinstance(rows, list):
        return {**empty, "lookup_error": True}
    tokens = list(dict.fromkeys(str(row.get("token", ""))
                              for row in rows if isinstance(row, dict)))
    tokens = [token for token in tokens if _TOKEN.fullmatch(token)]
    with ThreadPoolExecutor(max_workers=6) as pool:
        sent = sum(pool.map(lambda token: _send(token, title, message, data, tag), tokens))
    return {"configured": True, "devices": len(tokens), "sent": sent,
            "failed": len(tokens) - sent}


def send_android_order_event(event_secret, phone, notification, order, rpc):
    event = str(order.get("event", ""))
    admin = event in ("admin_new_order", "admin_test")
    if admin:
        operation, params = "event_admin_native_fcm", {"p_event_secret": event_secret}
        title, message = notification["title"], notification["body"]
    else:
        operation, params = "event_native_fcm_for_phone", {
            "p_event_secret": event_secret, "p_phone": phone,
        }
        # Private order details remain behind the app's customer session.
        title, message = {
            "submitted": ("Buyurtma yuborildi ✅", "Buyurtmangiz haqidagi ma’lumot ilovada."),
            "accepted": ("Buyurtma qabul qilindi ✅", "Buyurtmangiz holati yangilandi. Tafsilotlar ilovada."),
            "shipping": ("Buyurtmangiz jo‘natildi 🚚", "Pochtaga topshirildi. Tafsilotlar ilovada."),
            "review_reminder": ("Muhajeer Books 📚", "Kitoblaringiz haqidagi yangi eslatma ilovada."),
        }.get(event, ("Muhajeer Books", "Ilovada yangi bildirishnoma bor."))
    return _deliver(rpc, operation, params, title, message, {
        "kind": "admin_new_order" if admin else "customer_order",
        "order_id": str(order.get("order_id") or "")[:36],
    }, notification.get("tag", "muhajeer-order"))


def send_android_broadcast(admin_secret, title, message, message_id, rpc):
    return _deliver(rpc, "admin_native_fcm_devices", {"p_secret": admin_secret},
                    title, message, {"kind": "customer_broadcast", "message_id": message_id},
                    f"muhajeer-{message_id}")
