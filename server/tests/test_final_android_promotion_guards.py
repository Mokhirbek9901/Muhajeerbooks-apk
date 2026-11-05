import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('final_promotion',
    Path(__file__).resolve().parents[2] / 'tools/promote_final_android_20261105.py')
promotion = importlib.util.module_from_spec(spec)
spec.loader.exec_module(promotion)


class PromotionGuards(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'app-release.aab').write_bytes(b'test fixture, never uploaded')
        self.candidate = {'version_code': '1215', 'source': 'verified-source',
                          'track': 'internal', 'production_unchanged': True}
        self.env = {'CANDIDATE_EVIDENCE_DIR': str(self.root),
                    'EXPECTED_CANDIDATE_SOURCE': 'verified-source',
                    'OWNER_APPROVED_EXACT_RELEASE': 'com.muhajeerbooks.app:2.5.26:1215'}

    def assertBlocked(self, message):
        (self.root / 'play-candidate.json').write_text(json.dumps(self.candidate))
        with patch.dict(os.environ, self.env, clear=True):
            with self.assertRaisesRegex(ValueError, message):
                promotion.main()

    def test_different_source_cannot_load_credentials_or_publish(self):
        self.candidate['source'] = 'other-build'
        self.assertBlocked('provenance')

    def test_production_changed_during_candidate_upload_is_rejected(self):
        self.candidate['production_unchanged'] = False
        self.assertBlocked('provenance')

    def test_authorization_for_another_build_is_rejected(self):
        self.env['OWNER_APPROVED_EXACT_RELEASE'] = 'com.muhajeerbooks.app:2.5.26:1214'
        self.assertBlocked('authorization')

    def test_ambiguous_artifact_is_rejected(self):
        nested = self.root / 'unexpected'
        nested.mkdir()
        (nested / 'app-release.aab').write_bytes(b'other fixture')
        self.assertBlocked('exactly one')


if __name__ == '__main__':
    unittest.main()
