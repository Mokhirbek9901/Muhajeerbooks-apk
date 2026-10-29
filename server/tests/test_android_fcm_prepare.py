from pathlib import Path
import importlib.util
import json
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('fcm_prepare',ROOT/'tools/prepare_android_fcm.py')
fcm=importlib.util.module_from_spec(spec)
spec.loader.exec_module(fcm)


class AndroidFcmPreparationTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        self.main=self.root/'app/src/main'
        self.activity=self.main/'kotlin/com/example/MainActivity.kt'
        self.activity.parent.mkdir(parents=True)
        self.activity.write_text('''package com.example
import io.flutter.embedding.engine.FlutterEngine
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Existing analytics channel must survive.
    }
}
''')
        (self.main/'AndroidManifest.xml').write_text('''<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application android:label="Muhajeer Books"><activity android:name=".MainActivity" /></application></manifest>''')
        (self.root/'app/build.gradle.kts').write_text('plugins {}\n')
        self.config=self.root/'firebase.json'

    def test_repeatable_preparation_preserves_host_and_only_adds_one_service(self):
        fcm.configure(self.root,self.config)
        fcm.configure(self.root,self.config)
        text=self.activity.read_text()
        self.assertIn('Existing analytics channel',text)
        self.assertEqual(text.count('MuhajeerFcmBridge.attach'),1)
        manifest=ET.parse(self.main/'AndroidManifest.xml')
        services=manifest.getroot().find('application').findall('service')
        self.assertEqual(len(services),1)
        self.assertEqual(services[0].get(fcm.ANDROID+'exported'),'false')
        self.assertFalse((self.main/'res/values/muhajeer_firebase.xml').exists())
        self.assertIn('package com.example',self.activity.with_name('MuhajeerMessagingService.kt').read_text())

    def test_release_refuses_missing_firebase_configuration(self):
        with self.assertRaisesRegex(ValueError,'config missing'):
            fcm.configure(self.root,self.config,require_config=True)

    def test_public_configuration_selects_only_exact_android_package(self):
        def client(package,app):
            return {'client_info':{'android_client_info':{'package_name':package},'mobilesdk_app_id':app},
                    'api_key':[{'current_key':'public-api-key'}]}
        self.config.write_text(json.dumps({'project_info':{'project_number':'123','project_id':'books-test'},
            'client':[client('wrong.app','wrong-id'),client('com.muhajeerbooks.app','right-id')]}))
        fcm.configure(self.root,self.config,require_config=True)
        strings={x.get('name'):x.text for x in ET.parse(self.main/'res/values/muhajeer_firebase.xml').getroot()}
        self.assertEqual(strings['google_app_id'],'right-id')
        self.assertEqual(strings['gcm_defaultSenderId'],'123')


if __name__=='__main__': unittest.main()
