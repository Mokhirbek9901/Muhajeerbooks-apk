import json
import os
import sys
import urllib.error
import urllib.request


def main():
    supabase_url = os.getenv("SUPABASE_URL", "").rstrip("/")
    anon_key = os.getenv("SUPABASE_ANON_KEY", "").strip()
    event_secret = os.getenv("ORDER_PUSH_SECRET", "").strip()

    if not supabase_url or not anon_key or not event_secret:
        print("RUNTIME_SECRET_MIGRATION_SKIPPED: required environment is missing", flush=True)
        return 2

    payload = {
        "event_secret": event_secret,
        "openai_api_key": os.getenv("OPENAI_API_KEY", "").strip(),
        "vapid_private_key": os.getenv("VAPID_PRIVATE_KEY", "").strip(),
        "vapid_public_key": os.getenv("VAPID_PUBLIC_KEY", "").strip(),
        "admin_push_phone": os.getenv("ADMIN_PUSH_PHONE", "").strip(),
    }
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{supabase_url}/functions/v1/runtime-secret-migrate",
        data=body,
        method="POST",
        headers={
            "apikey": anon_key,
            "Authorization": f"Bearer {anon_key}",
            "Content-Type": "application/json",
        },
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            result = json.loads(response.read().decode("utf-8"))
        if not isinstance(result, dict) or result.get("ok") is not True:
            print("RUNTIME_SECRET_MIGRATION_FAILED: unexpected response", flush=True)
            return 3
        print("RUNTIME_SECRET_MIGRATION_OK", flush=True)
        return 0
    except urllib.error.HTTPError as exc:
        print(f"RUNTIME_SECRET_MIGRATION_FAILED: HTTP {exc.code}", flush=True)
        return 4
    except Exception as exc:
        print(f"RUNTIME_SECRET_MIGRATION_FAILED: {type(exc).__name__}", flush=True)
        return 5


if __name__ == "__main__":
    sys.exit(main())
