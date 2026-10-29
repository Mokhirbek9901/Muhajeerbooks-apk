import importlib.util
import os
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

ROOT=Path(__file__).parents[2]
spec=importlib.util.spec_from_file_location('play_candidate',ROOT/'tools/play_candidate.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

class ReleaseGateTests(unittest.TestCase):
    def test_testflight_upload_has_no_automatic_trigger(self):
        workflow = (ROOT/'.github/workflows/testflight_upload.yml').read_text()
        events = workflow.split('on:\n', 1)[1].split('\npermissions:', 1)[0]
        self.assertIn('workflow_dispatch:', events)
        self.assertNotIn('push:', events)
        self.assertNotIn('pull_request:', events)
        self.assertNotIn('workflow_run:', events)

    def test_google_production_is_rejected_before_loading_credentials(self):
        with patch.dict(os.environ,PLAY_TRACK='production'):
            with self.assertRaisesRegex(SystemExit,'Production is blocked'):
                module.main('preflight')
    def test_new_internal_build_cannot_hide_a_production_change(self):
        before=[{'track':'production','releases':[{'status':'completed','versionCodes':['1186']},{'status':'halted','versionCodes':['1188']}]}, {'track':'internal','releases':[]}]
        after=[before[0], {'track':'internal','releases':[{'status':'completed','versionCodes':['1200']}]}]
        self.assertEqual(module.production_state(before),module.production_state(after))
        changed=[{'track':'production','releases':[{'status':'completed','versionCodes':['1200']}]}]
        self.assertNotEqual(module.production_state(before),module.production_state(changed))
    def test_app_store_public_script_requires_exact_owner_approval(self):
        import shutil
        if not shutil.which('ruby'):
            self.skipTest('Ruby release guards run in CI')
        env={**os.environ,'IOS_MARKETING_VERSION':'2.5.20','IOS_BUILD_NUMBER':'9999','ASC_APP_ID':'test-app'}
        env.pop('OWNER_APPROVED_PUBLIC_RELEASE',None)
        result=subprocess.run(['ruby',str(ROOT/'.github/release_tools/submit_app_store_update.rb')],env=env,capture_output=True,text=True,timeout=10)
        self.assertNotEqual(result.returncode,0)
        self.assertIn('owner must test and approve',result.stderr)
