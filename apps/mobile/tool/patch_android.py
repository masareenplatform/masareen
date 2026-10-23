#!/usr/bin/env python3
"""Re-apply MASAREEN's Android configuration on top of a freshly generated
`flutter create --platforms=android .` project (apps/mobile/android/ is
git-ignored, so a clean clone has none).

Run from apps/mobile:  python3 tool/patch_android.py
Idempotent. Pinned/tested against Flutter 3.24.x (Groovy build.gradle)."""
import os, re, sys, shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = os.path.join(ROOT, 'android')
APP_ID = 'com.masaren.app'
LABEL = 'MASAREEN'

def rw(path, fn):
    with open(path, encoding='utf-8') as f: s = f.read()
    n = fn(s)
    if n != s:
        with open(path, 'w', encoding='utf-8') as f: f.write(n)

def die(m): print('ERROR:', m); sys.exit(1)

gradle = os.path.join(A, 'app', 'build.gradle')
manifest = os.path.join(A, 'app', 'src', 'main', 'AndroidManifest.xml')
if not os.path.exists(gradle):
    die('android/app/build.gradle not found (Groovy). Use Flutter 3.24.x or run `flutter create --platforms=android .` first.')

# ---- discover generated package, then move to APP_ID --------------------
g = open(gradle, encoding='utf-8').read()
m = re.search(r'namespace\s*=?\s*["\']([\w.]+)["\']', g)
old_pkg = m.group(1) if m else None
if not old_pkg: die('could not find namespace in build.gradle')

def gradle_fix(s):
    s = re.sub(r'(namespace\s*=?\s*)["\'][\w.]+["\']', r'\1"%s"' % APP_ID, s)
    s = re.sub(r'(applicationId\s*=?\s*)["\'][\w.]+["\']', r'\1"%s"' % APP_ID, s)
    s = re.sub(r'minSdk(?:Version)?\s*=?\s*flutter\.minSdkVersion', 'minSdkVersion 24', s)
    s = re.sub(r'minSdk(?:Version)?\s+\d+', 'minSdkVersion 24', s)
    if 'coreLibraryDesugaringEnabled' not in s:
        s = re.sub(r'(compileOptions\s*\{)', r'\1\n        coreLibraryDesugaringEnabled true', s, count=1)
    if 'desugar_jdk_libs' not in s:
        s += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'\n}\n"
    # keep the template's debug-key signing for release => installable APK.
    return s
rw(gradle, gradle_fix)

# move MainActivity to the new package
for lang in ('kotlin', 'java'):
    base = os.path.join(A, 'app', 'src', 'main', lang)
    old_dir = os.path.join(base, *old_pkg.split('.'))
    new_dir = os.path.join(base, *APP_ID.split('.'))
    if os.path.isdir(old_dir) and old_dir != new_dir:
        os.makedirs(new_dir, exist_ok=True)
        for fn in os.listdir(old_dir):
            src = os.path.join(old_dir, fn)
            dst = os.path.join(new_dir, fn)
            shutil.move(src, dst)
            rw(dst, lambda s: s.replace('package ' + old_pkg, 'package ' + APP_ID))
        # prune empty old dirs
        d = old_dir
        while d != base and os.path.isdir(d) and not os.listdir(d):
            os.rmdir(d); d = os.path.dirname(d)

# ---- manifest -------------------------------------------------------------
PERMS = [
 'INTERNET', 'ACCESS_NETWORK_STATE', 'ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION',
 'CAMERA', 'RECORD_AUDIO', 'MODIFY_AUDIO_SETTINGS', 'POST_NOTIFICATIONS', 'VIBRATE',
 'WAKE_LOCK', 'READ_MEDIA_IMAGES', 'READ_MEDIA_VIDEO',
]
def manifest_fix(s):
    add = ''.join('    <uses-permission android:name="android.permission.%s"/>\n' % p
                  for p in PERMS if 'android.permission.%s"' % p not in s)
    add += '' if 'android.hardware.camera"' in s else '    <uses-feature android:name="android.hardware.camera" android:required="false"/>\n'
    s = re.sub(r'(<manifest[^>]*>\n)', lambda mm: mm.group(1) + add, s, count=1)
    s = re.sub(r'android:label="[^"]*"', 'android:label="%s"' % LABEL, s, count=1)
    if 'usesCleartextTraffic' not in s:
        # the default API endpoint is plain http://; Android 9+ blocks that otherwise
        s = s.replace('<application', '<application\n        android:usesCleartextTraffic="true"', 1)
    return s
rw(manifest, manifest_fix)

# ---- launcher icons from the brand logo -------------------------------------
try:
    from PIL import Image
    logo = Image.open(os.path.join(ROOT, 'assets', 'images', 'masaren_logo_512.png')).convert('RGBA')
    sizes = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
    for d, px in sizes.items():
        out = os.path.join(A, 'app', 'src', 'main', 'res', 'mipmap-' + d)
        if not os.path.isdir(out): continue
        canvas = Image.new('RGBA', (px, px), (255, 255, 255, 255))
        inner = int(px * 0.78)
        l = logo.copy(); l.thumbnail((inner, inner))
        canvas.alpha_composite(l, ((px - l.width) // 2, (px - l.height) // 2))
        canvas.convert('RGB').save(os.path.join(out, 'ic_launcher.png'))
except Exception as e:
    print('icon step skipped:', e)

print('Android project patched: id=%s label=%s' % (APP_ID, LABEL))
