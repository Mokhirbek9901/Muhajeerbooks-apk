from pathlib import Path
import re

PACKAGE_ID = "com.muhajeerbooks.app"
APP_NAME = "Muhajeer Books"
TARGET_SDK = 36

build_file = Path("android/app/build.gradle.kts")
text = build_file.read_text(encoding="utf-8")

if "import java.util.Properties" not in text:
    text = "import java.util.Properties\nimport java.io.FileInputStream\n\n" + text

props = '''val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
'''
if "val keystoreProperties = Properties()" not in text:
    text = text.replace("android {", props + "\nandroid {", 1)

text = re.sub(r'compileSdk\s*=\s*flutter\.compileSdkVersion', f'compileSdk = {TARGET_SDK}', text)
text = re.sub(r'applicationId\s*=\s*"[^"]+"', f'applicationId = "{PACKAGE_ID}"', text)
text = re.sub(r'targetSdk\s*=\s*flutter\.targetSdkVersion', f'targetSdk = {TARGET_SDK}', text)

signing_block = '''    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

'''
if 'create("release")' not in text:
    text = text.replace("    buildTypes {", signing_block + "    buildTypes {", 1)

text = text.replace('signingConfig = signingConfigs.getByName("debug")', 'signingConfig = signingConfigs.getByName("release")')
build_file.write_text(text, encoding="utf-8")

manifest = Path("android/app/src/main/AndroidManifest.xml")
m = manifest.read_text(encoding="utf-8")
if 'android.permission.INTERNET' not in m:
    m = m.replace("<manifest xmlns:android=\"http://schemas.android.com/apk/res/android\">", "<manifest xmlns:android=\"http://schemas.android.com/apk/res/android\">\n    <uses-permission android:name=\"android.permission.INTERNET\" />", 1)
m = re.sub(r'android:label="[^"]*"', f'android:label="{APP_NAME}"', m, count=1)
manifest.write_text(m, encoding="utf-8")

# Railway's free container has much less memory than Flutter's generated 8 GiB
# Gradle default. Keep the release build single-worker and within the container.
gradle_props = Path("android/gradle.properties")
gp = gradle_props.read_text(encoding="utf-8") if gradle_props.exists() else ""
settings = {
    "org.gradle.jvmargs": "-Xmx512m -XX:MaxMetaspaceSize=256m -XX:ReservedCodeCacheSize=128m -Dfile.encoding=UTF-8",
    "org.gradle.daemon": "false",
    "org.gradle.parallel": "false",
    "org.gradle.workers.max": "1",
    "kotlin.daemon.jvmargs": "-Xmx256m",
}
for key, value in settings.items():
    pattern = rf"(?m)^{re.escape(key)}=.*$"
    line = f"{key}={value}"
    if re.search(pattern, gp):
        gp = re.sub(pattern, line, gp)
    else:
        if gp and not gp.endswith("\n"):
            gp += "\n"
        gp += line + "\n"
gradle_props.write_text(gp, encoding="utf-8")

print(f"Prepared Android release: {PACKAGE_ID}, targetSdk={TARGET_SDK}")
