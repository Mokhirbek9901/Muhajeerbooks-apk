"""Verified preorder push delivery for native admin/customer devices.

The outbox supplies the audience, source and order reference, never a caller
provided phone number or token. The database checks device ownership.
"""
import hashlib
import os
import re
import time

from native_android_push import fcm_configured, _send as send_fcm

_APNS_TOKEN = re.compile(r"^[0-9a-fA-F]{64}$")
_FCM_TOKEN = re.compile(r"^[A-Za-z0-9:_-]{40,4096}$")


def send_preorder_native(event, recipients):
    """Return (delivered opaque hashes, attempted recipients, failures)."""
    audience = event.get("audience")
    if audience not in ("admin", "customer"):
        raise ValueError("Unknown preorder audience")
    tokens = recipients if isinstance(recipients, dict) else {}
    seen = {str(x) for x in event.get("delivered_keys", [])}
    delivered = []
    attempted = failed = 0
    admin = audience == "admin"
    title = ("Yangi oldindan zakaz 📚" if admin else
             "Oldindan zakazingiz holati yangilandi")
    message = ("Admin paneldagi oldindan zakazlar bo‘limini tekshiring." if admin else
               "Buyurtma holati va avansni Profil → Oldindan zakazlarim bo‘limida tekshiring.")
    data = {"kind": "admin_preorder" if admin else "customer_preorder",
            "source": str(event.get("source", ""))[:10],
            "preorder_id": str(event.get("reference", ""))[:36]}
    apns = list(dict.fromkeys(str(x).lower() for x in tokens.get("apns", [])))
    fcm = list(dict.fromkeys(str(x) for x in tokens.get("fcm", [])))

    key_id = os.getenv("APPLE_APNS_KEY_ID", "").strip()
    team_id = os.getenv("APPLE_APNS_TEAM_ID", "8HJA5K2BQJ").strip()
    key = os.getenv("APPLE_APNS_PRIVATE_KEY", "").strip().replace("\\n", "\n")
    apns_ready = bool(key_id and team_id and key)
    headers = None
    if apns_ready and any(_APNS_TOKEN.fullmatch(t) and
                         hashlib.md5(("apns:" + t).encode()).hexdigest() not in seen
                         for t in apns):
        try:
            import jwt
            bearer = jwt.encode({"iss": team_id, "iat": int(time.time())},
                                key, algorithm="ES256", headers={"kid": key_id})
            headers = {"authorization": f"bearer {bearer}",
                       "apns-topic": "com.muhajeerbooks.app",
                       "apns-push-type": "alert", "apns-priority": "10"}
        except Exception as exc:
            print("Preorder APNs signing error:", type(exc).__name__, flush=True)

    if headers:
        import httpx
        with httpx.Client(http2=True, timeout=8.0) as client:
            for token in apns[:300]:
                if not _APNS_TOKEN.fullmatch(token):
                    continue
                digest = hashlib.md5(("apns:" + token).encode()).hexdigest()
                if digest in seen:
                    continue
                attempted += 1
                try:
                    response = client.post("https://api.push.apple.com/3/device/" + token,
                        headers=headers, json={
                            "aps": {"alert": {"title": title, "body": message}, "sound": "default"},
                            **data,
                        })
                    if response.status_code == 200:
                        delivered.append(digest)
                    else:
                        failed += 1
                        print("Preorder APNs HTTP", response.status_code, flush=True)
                except Exception as exc:
                    failed += 1
                    print("Preorder APNs delivery:", type(exc).__name__, flush=True)
    else:
        failed += sum(1 for t in apns if _APNS_TOKEN.fullmatch(t)
                      and hashlib.md5(("apns:" + t).encode()).hexdigest() not in seen)

    android_ready = fcm_configured()
    for token in fcm[:300]:
        if not _FCM_TOKEN.fullmatch(token):
            continue
        digest = hashlib.md5(("fcm:" + token).encode()).hexdigest()
        if digest in seen:
            continue
        if not android_ready:
            failed += 1
            continue
        attempted += 1
        if send_fcm(token, title, message, data, "preorder-" + data["preorder_id"]):
            delivered.append(digest)
        else:
            failed += 1
    return delivered, attempted, failed
