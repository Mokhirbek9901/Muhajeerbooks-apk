"""Apply the same release-startup safeguards to every generated Android build."""
from pathlib import Path
import re


def configure(root: Path):
    gradle = root / 'app/build.gradle.kts'
    text = gradle.read_text()
    text = re.sub(r'applicationId\s*=\s*"[^"]+"', 'applicationId = "com.muhajeerbooks.app"', text)
    match = re.search(r'\brelease\s*\{', text)
    if not match:
        raise ValueError('Release build type is missing')
    start = match.end()
    depth, end = 1, start
    while depth:
        if end >= len(text):
            raise ValueError('Invalid release block')
        depth += (text[end] == '{') - (text[end] == '}')
        end += 1
    block = text[start:end-1]
    if 'optimization {' in block:
        raise ValueError('Review the new AGP optimization DSL before changing this build')
    block = re.sub(r'^\s*is(?:MinifyEnabled|ShrinkResources)\s*=.*$', '', block, flags=re.M)
    text = text[:start] + '\n            isMinifyEnabled = false\n            isShrinkResources = false\n' + block + text[end-1:]
    if 'verifyMuhajeerReleaseSafety' not in text:
        text += '''
// Prevent a later Flutter/Gradle default from restoring the failing R8 path.
val verifyMuhajeerReleaseSafety by tasks.registering {
    doLast {
        val release = android.buildTypes.getByName("release")
        check(release.isMinifyEnabled == false && release.isShrinkResources == false) {
            "Muhajeer release safety changed: validate the preferences plugin on devices first."
        }
        println("MB_ANDROID_RELEASE_SAFETY=minify:false,resources:false")
    }
}
tasks.matching { it.name == "compileReleaseKotlin" || it.name == "bundleRelease" || it.name == "assembleRelease" }
    .configureEach { dependsOn(verifyMuhajeerReleaseSafety) }
'''
    gradle.write_text(text)
    resources = root / 'app/src/main/res'
    for folder in ['drawable', 'drawable-v21']:
        directory = resources / folder
        directory.mkdir(parents=True, exist_ok=True)
        (directory/'launch_background.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/muhajeer_launch_background" />
</layer-list>
''')
    (resources/'values').mkdir(parents=True, exist_ok=True)
    (resources/'values/muhajeer_colors.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<resources><color name="muhajeer_launch_background">#F7F3EA</color></resources>
''')
    for styles in resources.glob('values*/styles.xml'):
        data = styles.read_text()
        data = re.sub(r'(<item name="android:windowBackground">).*?(</item>)', r'\1@color/muhajeer_launch_background\2', data)
        data = re.sub(r'(<item name="android:windowSplashScreenBackground">).*?(</item>)', r'\1@color/muhajeer_launch_background\2', data)
        styles.write_text(data)
    manifest = root/'app/src/main/AndroidManifest.xml'
    data = manifest.read_text()
    if 'android.permission.INTERNET' not in data:
        data = data.replace('<application', '<uses-permission android:name="android.permission.INTERNET" />\n    <application', 1)
    manifest.write_text(data)


if __name__ == '__main__':
    configure(Path('android'))
    print('Android release: shrinking disabled, visible launch background, network permission verified.')
