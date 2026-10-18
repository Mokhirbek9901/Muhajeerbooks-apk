#!/usr/bin/env python3
"""Protect Android Flutter Pigeon plugin registrars in release builds.

On the 2026-10-18 Android 9 smoke test, the stock release build raised:
java.lang.NoSuchMethodError:
SharedPreferencesApiRegistrar.getAll(String, List, Continuation)

The class appeared obfuscated ("y"), pointing to release code shrinking.
Disable R8 shrinking/obfuscation for the emergency Android compatibility
release until there is a tested, narrowly scoped consumer-ProGuard fix.

Run after "flutter create" and after the release signing patch, for both
the Play AAB and release QA APK. Does not modify non-Android platforms.
"""
from pathlib import Path
import re

path = Path("android/app/build.gradle.kts")
if not path.is_file():
    raise SystemExit("Android Gradle project missing: run flutter create first")

source = path.read_text(encoding="utf-8")
# In the generated Flutter Kotlin Gradle file, only release has a signing
# config reference. The Play build changes its name to "upload".
pattern = re.compile(
    r'(?m)^(?P<indent>[ \t]*)(?P<sign>signingConfig[ \t]*=[ \t]*signingConfigs\.getByName\("(?:debug|upload)"\))[ \t]*$'
)
match = pattern.search(source)
if match is None:
    raise SystemExit("Release signing config not found; refusing unsafe build")
start = source.rfind("buildTypes {", 0, match.start())
if start < 0 or "release {" not in source[start:match.start()]:
    raise SystemExit("Signing configuration not inside the release build")
if "isMinifyEnabled" not in source[match.end():match.end()+150]:
    replace = (
        match.group("indent") + match.group("sign") + "\n"
        + match.group("indent") + "isMinifyEnabled = false\n"
        + match.group("indent") + "isShrinkResources = false"
    )
    source = source[:match.start()] + replace + source[match.end():]
if "isMinifyEnabled = false" not in source:
    raise SystemExit("Cannot disable release code shrinking")
if "isShrinkResources = false" not in source:
    raise SystemExit("Cannot disable resource shrinking")
path.write_text(source, encoding="utf-8")
print("Android release R8 minify and resource shrink disabled: Pigeon compatibility")

)
match = pattern.search(source)
if match is None:
    raise SystemExit("Release signing config not found; refusing unsafe build")
start = source.rfind("buildTypes {", 0, match.start())
if start < 0 or "release {" not in source[start:match.start()]:
    raise SystemExit("Signing configuration not inside the release build")
if "isMinifyEnabled" not in source[match.end():match.end()+150]:
    replace = (
        match.group("indent") + match.group("sign") + "\n"
        + match.group("indent") + "isMinifyEnabled = false\n"
        + match.group("indent") + "isShrinkResources = false"
    )
    source = source[:match.start()] + replace + source[match.end():]
if "isMinifyEnabled = false" not in source:
    raise SystemExit("Cannot disable release code shrinking")
if "isShrinkResources = false" not in source:
    raise SystemExit("Cannot disable resource shrinking")
path.write_text(source, encoding="utf-8")
print("Android release R8 minify and resource shrink disabled: Pigeon compatibility")
