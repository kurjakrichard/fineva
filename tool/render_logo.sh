#!/usr/bin/env bash
# Renders the logo PNGs from the SVGs in assets/logo (needs ImageMagick with
# librsvg), then regenerates the app icons and the native splash screen.
#
#   tool/render_logo.sh
set -euo pipefail
cd "$(dirname "$0")/../assets/logo"

render() { magick -background none -density 96 "$1" -resize "$2" "$3"; }

# App icon (Windows .ico, older Android launchers)
render logo.svg 1024x1024 app_icon.png
# Android adaptive icon layers. The launcher shows only the middle ~61% of
# the foreground (a circle at most), so the mark is scaled down to 80%.
render background.svg 1024x1024 icon_background.png
magick -background none -density 96 mark.svg -resize 1024x1024 \
  -gravity center -resize 80% -extent 1024x1024 mark_padded.png
# Splash screens: the mark alone, without empty borders.
magick -background none -density 384 mark.svg -trim -resize x600 splash.png

cd ../..
dart run flutter_launcher_icons
dart run flutter_native_splash:create
