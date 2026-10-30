"""PIN-less rollout must preserve existing admin preorder checkout routes."""
from pathlib import Path
import unittest

SOURCE = (Path(__file__).resolve().parents[2] /
          "supabase/functions/web-preorders/index.ts").read_text(encoding="utf-8")


class PinlessWebPreorderCompatibilityTests(unittest.TestCase):
    def test_existing_admin_checkout_routes_stay_available(self):
        for action in ('"checkout_detail"', '"checkout_confirm"'):
            self.assertIn(action, SOURCE)
        self.assertIn('admin_web_preorder_checkout_detail', SOURCE)
        self.assertIn('admin_web_preorder_checkout_confirm', SOURCE)
        self.assertIn('p_preorder_id: p.p_payload.id', SOURCE)
        self.assertIn('balance_proof_url', SOURCE)

    def test_native_preorder_instagram_reaches_device_dispatch(self):
        app_source = (Path(__file__).resolve().parents[2] /
                      "lib/app_state.dart").read_text(encoding="utf-8")
        ui_source = (Path(__file__).resolve().parents[2] /
                     "lib/store_ui.dart").read_text(encoding="utf-8")
        self.assertIn("'p_instagram_handle': instagramHandle", app_source)
        self.assertIn("instagramHandle: instagramHandle,", app_source)
        self.assertIn(
            "instagramHandle: normalizePreorderContact(preorderInstagram.text)",
            ui_source,
        )
        self.assertIn("contactPlatform: preorderContactPlatform.name", ui_source)
        self.assertIn("'p_contact_platform': contactPlatform", app_source)

    def test_admin_still_requires_secret(self):
        self.assertIn('typeof p.p_secret !== "string"', SOURCE)
        self.assertIn('return reply(403', SOURCE)

    def test_pinless_preorder_and_admin_contacts_coexist(self):
        self.assertIn('customer_device_dispatch', SOURCE)
        self.assertIn('admin_customer_preorder_contacts', SOURCE)
        self.assertIn('web_preorder_submit_multi', SOURCE)
        self.assertIn('web_preorder_submit', SOURCE)


if __name__ == "__main__":
    unittest.main()
