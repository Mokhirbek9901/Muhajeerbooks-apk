from pathlib import Path
import re

root = Path("android/app/src/main")
candidates = list((root / "kotlin").rglob("MainActivity.kt"))
if not candidates:
    raise SystemExit("MainActivity.kt not found after flutter create")

p = candidates[0]
old = p.read_text(encoding="utf-8")
match = re.search(r"^package\s+([^\s]+)", old, re.MULTILINE)
if not match:
    raise SystemExit("MainActivity package not found")
package_name = match.group(1)

p.write_text(
    f'''package {package_name}

import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {{
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {{
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "muhajeer/device_analytics"
        ).setMethodCallHandler {{ call, result ->
            when (call.method) {{
                "isFirebaseTestLab" -> {{
                    val value = Settings.System.getString(
                        contentResolver,
                        "firebase.test.lab"
                    )
                    result.success(value == "true")
                }}
                else -> result.notImplemented()
            }}
        }}
    }}
}}
''',
    encoding="utf-8",
)

print(f"Patched Firebase Test Lab analytics detection in {p}")
