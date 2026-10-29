"""Install Android-only FCM after the generated analytics/biometric host.

The optional google-services.json contains public Android application config,
never a service account. Production release preparation requires real config.
"""
import argparse
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ANDROID = '{http://schemas.android.com/apk/res/android}'
ET.register_namespace('android', ANDROID[1:-1])
BOM = '35.1.0'


def configure(root=Path('android'), config=Path('config/firebase-android.json'), require_config=False):
    main = root / 'app/src/main'
    activities = list(main.rglob('MainActivity.kt'))
    if len(activities) != 1:
        raise ValueError('Expected one generated MainActivity')
    activity = activities[0]
    text = activity.read_text()
    package = re.search(r'^package\s+([\w.]+)', text, re.M).group(1)
    if 'MuhajeerFcmBridge.attach' not in text:
        marker = 'super.configureFlutterEngine(flutterEngine)'
        if marker not in text:
            raise ValueError('Run prepare_android_testlab_analytics.py before FCM preparation')
        text = text.replace(marker, marker+'\n        MuhajeerFcmBridge.attach(this, flutterEngine)', 1)
        pos = text.rfind('}')
        text = text[:pos]+'''
    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        MuhajeerFcmBridge.opened(intent)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        MuhajeerFcmBridge.detach(this)
        super.cleanUpFlutterEngine(flutterEngine)
    }
'''+text[pos:]
        activity.write_text(text)
    templates = Path(__file__).with_name('android_push')
    for path in templates.glob('*.kt'):
        activity.with_name(path.name).write_text(path.read_text().replace('__PACKAGE__', package))
    gradle = root/'app/build.gradle.kts'
    text = gradle.read_text()
    text = re.sub(r'applicationId\s*=\s*"[^"]+"',
                  'applicationId = "com.muhajeerbooks.app"', text)
    if 'com.google.firebase:firebase-messaging' not in text:
        text += f'''\n// Android-only push: keep iOS native APNs independent.
dependencies {{
    implementation(platform("com.google.firebase:firebase-bom:{BOM}"))
    implementation("com.google.firebase:firebase-messaging")
}}
'''
    gradle.write_text(text)
    manifest = main/'AndroidManifest.xml'
    tree = ET.parse(manifest)
    top = tree.getroot()
    app = top.find('application')
    for permission in ['android.permission.INTERNET', 'android.permission.POST_NOTIFICATIONS']:
        if not any(e.get(ANDROID+'name') == permission for e in top.findall('uses-permission')):
            ET.SubElement(top,'uses-permission',{ANDROID+'name':permission})
    service = package+'.MuhajeerMessagingService'
    if not any(e.get(ANDROID+'name') == service for e in app.findall('service')):
        item = ET.SubElement(app,'service',{ANDROID+'name':service,ANDROID+'exported':'false'})
        ET.SubElement(ET.SubElement(item,'intent-filter'),'action',
                      {ANDROID+'name':'com.google.firebase.MESSAGING_EVENT'})
    for name, attr, value in [
        ('firebase_messaging_auto_init_enabled','value','false'),
        ('firebase_analytics_collection_enabled','value','false'),
        ('com.google.firebase.messaging.default_notification_channel_id','value','muhajeer_books'),
        ('com.google.firebase.messaging.default_notification_icon','resource','@drawable/ic_muhajeer_notification'),
    ]:
        existing = next((e for e in app.findall('meta-data') if e.get(ANDROID+'name') == name),None)
        if existing is None:
            existing = ET.SubElement(app,'meta-data',{ANDROID+'name':name})
        existing.set(ANDROID+attr,value)
    tree.write(manifest,encoding='unicode')
    drawable=main/'res/drawable'
    drawable.mkdir(parents=True,exist_ok=True)
    (drawable/'ic_muhajeer_notification.xml').write_text('''<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24"><path android:fillColor="#FFFFFFFF" android:pathData="M3,3h7l2,2 2,-2h7v17h-7l-2,2 -2,-2H3zM5,5v13h5l1,1V7L9,5zM13,7v12l1,-1h5V5h-4z"/></vector>''')
    values=main/'res/values/muhajeer_firebase.xml'
    if config.exists():
        data=json.loads(config.read_text())
        project=data['project_info']
        client=next(c for c in data['client'] if c['client_info']['android_client_info']['package_name']=='com.muhajeerbooks.app')
        resources=ET.Element('resources')
        for name,value in {
            'google_app_id':client['client_info']['mobilesdk_app_id'],
            'google_api_key':client['api_key'][0]['current_key'],
            'gcm_defaultSenderId':project['project_number'],
            'project_id':project['project_id'],
        }.items():
            if not isinstance(value,str) or not value.strip(): raise ValueError('Incomplete Firebase Android config')
            ET.SubElement(resources,'string',{'name':name,'translatable':'false'}).text=value
        values.parent.mkdir(parents=True,exist_ok=True)
        values.write_text(ET.tostring(resources,encoding='unicode'))
    else:
        values.unlink(missing_ok=True)
        if require_config:
            raise ValueError('Firebase Android config missing: config/firebase-android.json')


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--require-config',action='store_true')
    args=parser.parse_args()
    configure(require_config=args.require_config)
    print('Android FCM service, notification channel and secure token bridge prepared.')
