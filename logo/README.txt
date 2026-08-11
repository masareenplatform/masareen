MASAREEN Logo Asset Package (Transparent Background)
=====================================================

Generated from source: WhatsApp Image 2026-06-26 at 7.14.26 PM.jpeg
Background: Transparent (white removed)

Folder Structure:
-----------------

android/
  mipmap-mdpi/     - 48x48 px
  mipmap-hdpi/     - 72x72 px
  mipmap-xhdpi/    - 96x96 px
  mipmap-xxhdpi/   - 144x144 px
  mipmap-xxxhdpi/  - 192x192 px
  Each folder contains:
    ic_launcher.png           - Standard launcher icon
    ic_launcher_round.png     - Circular launcher icon
    ic_launcher_foreground.png - Foreground layer for adaptive icons

ios/
  AppIcon.appiconset/
    All required iOS app icon sizes with Contents.json
    for direct use in Xcode projects.

web/
  favicon-16x16.png           - Browser favicon
  favicon-32x32.png           - Browser favicon (retina)
  favicon-48x48.png           - Browser favicon
  apple-touch-icon.png        - iOS home screen icon (180x180)
  icon-72x72.png through icon-512x512.png - Web app manifest icons
  icon-*.webp                 - WebP versions for modern browsers
  og-image.png                - Open Graph sharing (1200x630, transparent)
  twitter-card.png            - Twitter card image (1200x630, transparent)

root/
  masareen_logo_full.png      - Full resolution PNG (transparent)
  masareen_logo_16x16.png through masareen_logo_1024x1024.png
                              - Standard square sizes (transparent)

Usage Notes:
------------
- All PNG files have transparent backgrounds.
- For true vector (SVG), a designer should trace the source in Illustrator,
  Figma, or Inkscape. Automated raster-to-vector is not recommended for
  gradient-heavy logos.
- WebP versions are recommended for web applications to reduce file size.
- The OG and Twitter card images have transparent backgrounds; social platforms
  may render them on white or their own background.

Recommended HTML:
-----------------
<link rel="icon" type="image/png" sizes="16x16" href="/favicon-16x16.png">
<link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png">
<link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png">
<link rel="manifest" href="/site.webmanifest">
<meta property="og:image" content="/og-image.png">
<meta name="twitter:image" content="/twitter-card.png">
