#!/usr/bin/env bash
# Build all three local targets for Galaga: Linux, Web, Android.
#
# Run this ONLY with the Godot editor closed on THIS project — a second Godot
# process on an open project corrupts the .godot/ caches.
#   ps aux | grep '[g]odot.*--editor'
#
#   bash projects/galaga/build.sh            # all three
#   bash projects/galaga/build.sh web        # just one (linux | web | android)
set -e

GODOT=~/GodotDev/learn_2d_gamedev_godot_4_0.57.0_linux/godot
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADB=~/Android/Sdk/platform-tools/adb
targets="${*:-linux web android}"

cd "$HERE"

"$GODOT" --headless --path . --import

# parse-check the scripts on the way past
"$GODOT" --headless --path . --script res://_selftest.gd

for t in $targets; do
  case "$t" in
    linux)
      "$GODOT" --headless --path . --export-release "Linux" ../galaga-linux.x86_64
      chmod +x ../galaga-linux.x86_64
      ;;
    web)
      mkdir -p ../web-release-galaga
      "$GODOT" --headless --path . --export-release "Web" ../web-release-galaga/index.html
      ;;
    android)
      "$GODOT" --headless --path . --export-release "Android" ../galaga-android.apk
      if "$ADB" get-state >/dev/null 2>&1; then
        "$ADB" install -r ../galaga-android.apk
      else
        echo "  (no device connected — APK built, not installed)"
      fi
      ;;
    *) echo "unknown target: $t" ;;
  esac
done

echo
echo "done: $targets"
