import importlib.util
from pathlib import Path
import unittest

spec=importlib.util.spec_from_file_location('manifest',Path(__file__).resolve().parents[2]/'tools/android_store_manifest.py')
m=importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

class ManifestTests(unittest.TestCase):
    def tracks(self,status='completed',**extra):
        return [{'track':'production','releases':[{'name':'2.5.26','versionCodes':['1215'],'status':status,**extra}]}]
    def lifecycle(self,state=m.PUBLISHED):
        return {'releases':[{'releaseLifecycleState':state,'activeArtifacts':[{'versionCode':1215}]}]}
    def test_published_full_production_is_eligible(self):
        self.assertEqual(m.choose_public_release(self.tracks(),self.lifecycle()),(1215,'2.5.26'))
    def test_review_upload_approval_are_not_public(self):
        for state in ['RELEASE_LIFECYCLE_STATE_IN_REVIEW','RELEASE_LIFECYCLE_STATE_APPROVED_NOT_PUBLISHED','RELEASE_LIFECYCLE_STATE_NOT_SENT_FOR_REVIEW']:
            self.assertIsNone(m.choose_public_release(self.tracks(),self.lifecycle(state)))
    def test_halted_staged_country_releases_are_not_global(self):
        for tracks in [self.tracks('halted'),self.tracks('inProgress',userFraction=.2),self.tracks(countryTargeting={'countries':['KR']}),self.tracks(userFraction=.5)]:
            self.assertIsNone(m.choose_public_release(tracks,self.lifecycle()))
    def test_internal_release_cannot_activate_global_gate(self):
        tracks=self.tracks();tracks[0]['track']='internal'
        self.assertIsNone(m.choose_public_release(tracks,self.lifecycle()))
    def test_other_published_binary_cannot_validate_new_upload(self):
        lifecycle=self.lifecycle();lifecycle['releases'][0]['activeArtifacts'][0]['versionCode']=1213
        self.assertIsNone(m.choose_public_release(self.tracks(),lifecycle))

if __name__=='__main__':unittest.main()
