#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="$ROOT/build/ios-engine"
mkdir -p "$OUTPUT"
python3 "$ROOT/tools/prepare_sherpa_source.py"
ORT="$ROOT/build/ios-onnxruntime"
if [[ ! -f "$ORT/onnxruntime.xcframework/Info.plist" ]]; then
  mkdir -p "$ORT"
  curl --fail --location --retry 2 --max-time 180 'https://github.com/csukuangfj/onnxruntime-libs/releases/download/v1.28.2/onnxruntime-ios-static-xcframework-1.28.2.xcframework.zip' -o "$ORT/runtime.zip"
  echo '2c2299acbb461d26d4bac4bc85985d40e7c7177ed6072703ae0846d88b0b4599  '"$ORT/runtime.zip" | shasum -a 256 -c -
  unzip -q "$ORT/runtime.zip" -d "$ORT"
fi
for target in device simulator; do
  if [[ "$target" == device ]]; then SDK=iphoneos; ARCH=arm64; else SDK=iphonesimulator; ARCH='arm64;x86_64'; fi
  if [[ "$target" == device ]]; then ORT_SLICE=ios-arm64; else ORT_SLICE=ios-arm64_x86_64-simulator; fi
  export SHERPA_ONNXRUNTIME_LIB_DIR="$ORT/onnxruntime.xcframework/$ORT_SLICE"
  export SHERPA_ONNXRUNTIME_INCLUDE_DIR="$SHERPA_ONNXRUNTIME_LIB_DIR/onnxruntime.framework/Headers"
  cmake -S "$ROOT/packages/offline_engine/src" -B "$OUTPUT/$target" -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS -DIOS=ON -DCMAKE_OSX_SYSROOT="$SDK" \
    -DCMAKE_OSX_ARCHITECTURES="$ARCH" -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0
  cmake --build "$OUTPUT/$target" --config Release --target offline_engine -- -quiet CODE_SIGNING_ALLOWED=NO
  # libtool merges the bridge and all linked static ggml/whisper archives.
  # Include the selected static ONNX runtime and source-built dependency
  # archives as well as the bridge; never mix device/simulator runtime slices.
  find "$OUTPUT/$target" -name '*.a' ! -name 'libLingoWhisper.a' > "$OUTPUT/$target/archive-inputs.txt"
  cat "$OUTPUT/$target/sherpa-imported-archives.txt" >> "$OUTPUT/$target/archive-inputs.txt"
  sort -u "$OUTPUT/$target/archive-inputs.txt" > "$OUTPUT/$target/archive-inputs-unique.txt"
  libtool -static -filelist "$OUTPUT/$target/archive-inputs-unique.txt" -o "$OUTPUT/$target/libLingoWhisper.a"
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
