"""Run the release test entrypoint with ADB; mobile flutter test requires a VM service."""
from pathlib import Path
import os
import queue
import subprocess
import threading
import time


def main():
    subprocess.run([
        'flutter', 'build', 'apk', '--release', '--target-platform=android-x64',
        '--target=integration_test/store_startup_smoke_test.dart',
        '--dart-define=DEVICE_SMOKE_TEST=true', '--dart-define=ANALYTICS_TEST_BUILD=true',
        '--dart-define=PLAY_STORE_BUILD=true', '--dart-define=STORE_FEATURES=true',
    ], check=True)
    adb = ['adb', '-s', 'emulator-5554']
    subprocess.run(adb + ['install', '-r', 'build/app/outputs/flutter-apk/app-release.apk'], check=True)
    subprocess.run(adb + ['shell', 'am', 'force-stop', 'com.muhajeerbooks.app'], check=True)
    subprocess.run(adb + ['logcat', '-c'], check=True)
    log = subprocess.Popen(adb + ['logcat', '-v', 'brief'], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    lines = queue.Queue()
    def read():
        for line in log.stdout:
            lines.put(line)
    threading.Thread(target=read, daemon=True).start()
    output = []
    try:
        activity = subprocess.check_output(adb + ['shell', 'cmd', 'package', 'resolve-activity', '--brief', 'com.muhajeerbooks.app'], text=True).strip().splitlines()[-1]
        if '/' not in activity:
            raise RuntimeError('Release launcher could not be resolved')
        subprocess.run(adb + ['shell', 'am', 'start', '-W', '-n', activity], check=True)
        deadline = time.monotonic() + 180
        while time.monotonic() < deadline:
            try:
                line = lines.get(timeout=1)
            except queue.Empty:
                if log.poll() is not None:
                    raise RuntimeError('ADB log stream exited before test completion')
                continue
            output.append(line)
            if 'flutter' in line.lower() or 'FATAL EXCEPTION' in line:
                print(line, end='', flush=True)
            if 'MB_RELEASE_STARTUP_SMOKE_PASSED' in line:
                subprocess.run(adb + ['exec-out', 'screencap', '-p'], stdout=open('android-release-startup.png', 'wb'), check=True)
                print('VERIFIED release: native preferences, visible catalog, lifecycle resume. Owner physical-device test remains pending.')
                return
            if any(marker in line for marker in ['Some tests failed.', 'FATAL EXCEPTION', 'MB_RELEASE_STARTUP_SMOKE_FAILED']):
                raise RuntimeError('Release startup test failed')
        raise RuntimeError('No release test success marker within 180 seconds')
    finally:
        log.terminate()
        log.wait(timeout=10)
        Path('android-release-startup.log').write_text(''.join(output))


if __name__ == '__main__':
    main()
