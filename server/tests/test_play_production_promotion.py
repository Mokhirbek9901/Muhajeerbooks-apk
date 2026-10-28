import copy
import unittest
from promote_play_tested_candidate import (
    APPROVAL, PACKAGE, SOURCE, find_internal, lifecycle_for, plan_production,
    require_approval, require_candidate, verify_production,
)


class PromotionTests(unittest.TestCase):
    def setUp(self):
        self.internal = {'name': '2.5.20', 'versionCodes': ['1190'], 'status': 'completed'}
        self.approval = {'package': PACKAGE, 'source': SOURCE, 'version_code': '1190',
                         'owner_test_passed': True, 'public_release_allowed': True, 'scope': 'android_only'}

    def test_exact_owner_approval_cannot_authorize_ios_or_another_binary(self):
        require_approval(self.approval, APPROVAL)
        for change in [{'version_code': '1191'}, {'scope': 'both'}, {'owner_test_passed': False},
                       {'source': 'other'}, {'public_release_allowed': False}]:
            with self.assertRaises(ValueError):
                require_approval({**self.approval, **change}, APPROVAL)
        with self.assertRaises(ValueError):
            require_approval(self.approval, '')

    def test_evidence_and_internal_release_must_match_the_tested_binary(self):
        evidence = {'version_code': '1190', 'source': SOURCE, 'track': 'internal', 'production_unchanged': True}
        require_candidate(evidence)
        with self.assertRaises(ValueError):
            require_candidate({**evidence, 'version_code': '1191'})
        for release in [{**self.internal, 'status': 'halted'}, {**self.internal, 'versionCodes': ['1190', '1188']}]:
            with self.assertRaises(ValueError):
                find_internal([{'track': 'internal', 'releases': [release]}])

    def test_full_rollout_preserves_halted_and_draft_without_mutating_input(self):
        halted = {'versionCodes': ['1188'], 'status': 'halted', 'userFraction': 0.1}
        draft = {'versionCodes': ['1300'], 'status': 'draft'}
        production = {'track': 'production', 'releases': [halted, draft, {'versionCodes': ['1186'], 'status': 'completed'}]}
        before = copy.deepcopy(production)
        plan = plan_production(production, self.internal)
        self.assertEqual(production, before)
        self.assertEqual(plan['releases'][:2], [halted, draft])
        self.assertEqual(plan['releases'][-1]['versionCodes'], ['1190'])
        self.assertEqual(plan['releases'][-1]['status'], 'completed')
        self.assertNotIn('countryTargeting', plan['releases'][-1])
        self.assertNotIn('userFraction', plan['releases'][-1])
        verify_production(before, plan)

    def test_newer_public_release_is_not_downgraded(self):
        for status in ['completed', 'inProgress']:
            with self.assertRaises(ValueError):
                plan_production({'releases': [{'versionCodes': ['1191'], 'status': status}]}, self.internal)

    def test_exact_already_completed_release_is_idempotent(self):
        self.assertIsNone(plan_production({'releases': [self.internal]}, self.internal))

    def test_partial_rollout_or_reactivated_bad_binary_fails_verification(self):
        before = {'releases': [{'versionCodes': ['1188'], 'status': 'halted'}]}
        with self.assertRaises(ValueError):
            verify_production(before, {'releases': [{**self.internal, 'userFraction': 0.1}]})
        with self.assertRaises(ValueError):
            verify_production(before, {'releases': [self.internal, {'versionCodes': ['1188'], 'status': 'completed'}]})

    def test_publishing_lifecycle_is_not_confused_with_another_release(self):
        live = {'releases': [
            {'activeArtifacts': [{'versionCode': 1186}], 'releaseLifecycleState': 'RELEASE_LIFECYCLE_STATE_PUBLISHED'},
            {'activeArtifacts': [{'versionCode': 1190}], 'releaseLifecycleState': 'RELEASE_LIFECYCLE_STATE_IN_REVIEW'},
        ]}
        self.assertEqual(lifecycle_for(live), [live['releases'][1]])


if __name__ == '__main__':
    unittest.main()
