import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('android_safety', Path(__file__).parents[2]/'tools/prepare_android_release_safety.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class AndroidSafetyTests(unittest.TestCase):
    def test_release_defaults_cannot_restore_minification(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root/'app/src/main/res/values').mkdir(parents=True)
            gradle = root/'app/build.gradle.kts'
            gradle.write_text('''android { defaultConfig { applicationId = "old.package" }
 buildTypes { debug { isMinifyEnabled = false }
 release {
 isMinifyEnabled = true
 isShrinkResources = true
 signingConfig = signingConfigs.getByName("upload")
 } } }''')
            (root/'app/src/main/AndroidManifest.xml').write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application /></manifest>')
            styles=root/'app/src/main/res/values/styles.xml'
            styles.write_text('<resources><style name="NormalTheme"><item name="android:windowBackground">@android:color/white</item></style></resources>')
            module.configure(root)
            module.configure(root)
            result=gradle.read_text()
            self.assertNotIn('isMinifyEnabled = true', result)
            self.assertNotIn('isShrinkResources = true', result)
            self.assertEqual(result.count('val verifyMuhajeerReleaseSafety'),1)
            self.assertIn('signingConfigs.getByName("upload")', result)
            self.assertIn('@color/muhajeer_launch_background', styles.read_text())
            self.assertIn('android.permission.INTERNET', (root/'app/src/main/AndroidManifest.xml').read_text())
