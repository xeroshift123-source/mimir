#!/usr/bin/env bash
set -e

# Flutter 설치
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PWD/flutter/bin:$PATH"

flutter --version
flutter config --enable-web

flutter pub get
flutter build web --release --no-wasm-dry-run