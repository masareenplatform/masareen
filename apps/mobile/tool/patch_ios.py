#!/usr/bin/env python3
"""Re-apply MASAREEN's iOS configuration on top of a freshly generated
`flutter create --platforms=ios .` project (apps/mobile/ios/ is git-ignored).

Run from apps/mobile:  python3 tool/patch_ios.py
Idempotent. Produces an unsigned-friendly project; code signing is disabled in
the GitHub workflow, so the resulting IPA must be sideloaded.
"""
import json
import os
import plistlib
import re
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IOS = os.path.join(ROOT, 'ios')
PLIST = os.path.join(IOS, 'Runner', 'Info.plist')
PROJECT = os.path.join(IOS, 'Runner.xcodeproj', 'project.pbxproj')
PODFILE = os.path.join(IOS, 'Podfile')
APP_ID = 'com.masaren.app'
LABEL = 'MASAREEN'


def die(message):
    print('ERROR:', message)
    sys.exit(1)


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def write(path, value):
    with open(path, 'w', encoding='utf-8') as f:
        f.write(value)


if not os.path.exists(PLIST):
    die('ios/Runner/Info.plist not found. Run `flutter create --platforms=ios .` first.')

# ---- copy Firebase GoogleService-Info.plist if present ----------------------
gs_plist_src = os.path.join(ROOT, 'firebase', 'GoogleService-Info.plist')
gs_plist_dst = os.path.join(IOS, 'Runner', 'GoogleService-Info.plist')
if os.path.exists(gs_plist_src):
    shutil.copyfile(gs_plist_src, gs_plist_dst)

with open(PLIST, 'rb') as f:
    info = plistlib.load(f)

info.update({
    'CFBundleDisplayName': LABEL,
    'CFBundleName': LABEL,
    'CFBundleURLTypes': [{
        'CFBundleTypeRole': 'Editor',
        'CFBundleURLName': APP_ID,
        'CFBundleURLSchemes': ['masaren'],
    }],
    'LSApplicationQueriesSchemes': ['https', 'http', 'masaren', 'mailto', 'tel'],
    'UIBackgroundModes': ['fetch', 'remote-notification'],
    'FirebaseAppDelegateProxyEnabled': True,
    'NSCameraUsageDescription':
        'MASAREEN uses the camera to capture impact evidence and post media.',
    'NSPhotoLibraryUsageDescription':
        'MASAREEN lets you choose photos and videos for your posts and evidence.',
    'NSPhotoLibraryAddUsageDescription':
        'MASAREEN can save photos and videos you create to your library.',
    'NSMicrophoneUsageDescription':
        'MASAREEN uses the microphone for video and voice features.',
    'NSLocationWhenInUseUsageDescription':
        'MASAREEN attaches an optional location to impact posts and projects.',
})

with open(PLIST, 'wb') as f:
    plistlib.dump(info, f, sort_keys=False)

if os.path.exists(PROJECT):
    project = read(PROJECT)
    project = re.sub(
        r'IPHONEOS_DEPLOYMENT_TARGET = [\d.]+;',
        'IPHONEOS_DEPLOYMENT_TARGET = 13.0;',
        project,
    )
    project = project.replace('PRODUCT_BUNDLE_IDENTIFIER = com.example.masaren;',
                              'PRODUCT_BUNDLE_IDENTIFIER = %s;' % APP_ID)
    project = project.replace('PRODUCT_BUNDLE_IDENTIFIER = com.example.masaren.RunnerTests;',
                              'PRODUCT_BUNDLE_IDENTIFIER = %s.RunnerTests;' % APP_ID)

    def bundle_id(match):
        value = match.group(1)
        if value.endswith('.RunnerTests'):
            return 'PRODUCT_BUNDLE_IDENTIFIER = %s.RunnerTests;' % APP_ID
        return 'PRODUCT_BUNDLE_IDENTIFIER = %s;' % APP_ID

    project = re.sub(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);', bundle_id, project)
    write(PROJECT, project)

if os.path.exists(PODFILE):
    podfile = read(PODFILE)
    if re.search(r'^\s*#\s*platform :ios', podfile, re.M):
        podfile = re.sub(r'^\s*#\s*platform :ios[^\n]*',
                         "platform :ios, '13.0'", podfile, count=1, flags=re.M)
    elif 'platform :ios' not in podfile:
        podfile = "platform :ios, '13.0'\n" + podfile
    write(PODFILE, podfile)

# ---- app icon from the brand logo ------------------------------------------
try:
    from PIL import Image, ImageOps
    logo = Image.open(os.path.join(ROOT, 'assets', 'images',
                                   'masaren_logo_512.png')).convert('RGBA')
    icon_dir = os.path.join(IOS, 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    contents = os.path.join(icon_dir, 'Contents.json')
    if os.path.isdir(icon_dir) and os.path.exists(contents):
        data = json.loads(read(contents))
        for image in data.get('images', []):
            filename = image.get('filename')
            size = image.get('size', '')
            scale = image.get('scale', '1x')
            if not filename or 'x' not in size:
                continue
            try:
                points = float(size.split('x')[0])
                multiplier = int(scale.replace('x', ''))
            except ValueError:
                continue
            px = int(round(points * multiplier))
            if px <= 0:
                continue
            canvas = Image.new('RGBA', (px, px), (255, 255, 255, 255))
            inner = int(px * 0.8)
            scaled = logo.copy()
            scaled.thumbnail((inner, inner), Image.LANCZOS)
            canvas.alpha_composite(
                scaled, ((px - scaled.width) // 2, (px - scaled.height) // 2))
            canvas.convert('RGB').save(os.path.join(icon_dir, filename))
except Exception as exc:
    print('icon step skipped:', exc)

# ---- template test cleanup -------------------------------------------------
try:
    test = os.path.join(ROOT, 'test', 'widget_test.dart')
    if os.path.exists(test) and 'MyApp' in read(test):
        os.remove(test)
except Exception as exc:
    print('template test cleanup skipped:', exc)

print('iOS project patched: id=%s label=%s' % (APP_ID, LABEL))
