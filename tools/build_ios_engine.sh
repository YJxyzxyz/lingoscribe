#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="$ROOT/build/ios-engine"
mkdir -p "$OUTPUT"
for target in device simulator; do
  if [[ "$target" == device ]]; then SDK=iphoneos; ARCH=arm64; else SDK=iphonesimulator; ARCH='arm64;x86_64'; fi
  cmake -S "$ROOT/packages/offline_engine/src" -B "$OUTPUT/$target" -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS -DIOS=ON -DCMAKE_OSX_SYSROOT="$SDK" \
    -DCMAKE_OSX_ARCHITECTURES="$ARCH" -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0
  cmake --build "$OUTPUT/$target" --config Release --target offline_engine -- -quiet CODE_SIGNING_ALLOWED=NO
  # libtool merges the bridge and all linked static ggml/whisper archives.
  find "$OUTPUT/$target" -name '*.a' -path '*Release*' -print0 | xargs -0 libtool -static -o "$OUTPUT/$target/libLingoWhisper.a"
  mkdir -p "$OUTPUT/$target/headers"
  cp "$ROOT/packages/offline_engine/src/lingo_engine.h" "$OUTPUT/$target/headers/"
done
FRAMEWORK="$ROOT/packages/offline_engine/ios/Frameworks/LingoWhisper.xcframework"
if [[ -e "$FRAMEWORK" ]]; then
  # Only remove the generated framework inside this repository.
  case "$FRAMEWORK" in "$ROOT/packages/offline_engine/ios/Frameworks/LingoWhisper.xcframework") rm -rf "$FRAMEWORK" ;; *) exit 1 ;; esac
fi
mkdir -p "$(dirname "$FRAMEWORK")"
xcodebuild -create-xcframework \
  -library "$OUTPUT/device/libLingoWhisper.a" -headers "$OUTPUT/device/headers" \
  -library "$OUTPUT/simulator/libLingoWhisper.a" -headers "$OUTPUT/simulator/headers" \
  -output "$FRAMEWORK"
