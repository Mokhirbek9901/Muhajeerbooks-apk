from pathlib import Path

manifest = Path('android/app/src/main/AndroidManifest.xml')
if not manifest.exists():
    raise SystemExit('AndroidManifest.xml not found')
text = manifest.read_text(encoding='utf-8')
permission = '    <uses-permission android:name="android.permission.USE_BIOMETRIC" />\n'
if 'android.permission.USE_BIOMETRIC' not in text:
    marker = '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
    if marker not in text:
        raise SystemExit('Android manifest root marker not found')
    text = text.replace(marker, marker + permission, 1)
manifest.write_text(text, encoding='utf-8')

activities = list(Path('android/app/src/main').rglob('MainActivity.kt'))
if not activities:
    raise SystemExit('MainActivity.kt not found')
for activity in activities:
    data = activity.read_text(encoding='utf-8')
    data = data.replace(
        'import io.flutter.embedding.android.FlutterActivity',
        'import io.flutter.embedding.android.FlutterFragmentActivity',
    )
    data = data.replace('FlutterActivity()', 'FlutterFragmentActivity()')
    activity.write_text(data, encoding='utf-8')

print('Android biometric host prepared')
