#!/usr/bin/env bash
set -e

# Flutter 설치
rm -rf flutter
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PWD/flutter/bin:$PATH"

flutter --version
flutter config --enable-web

flutter pub get
flutter build web --release --no-wasm-dry-run

# ------------------------------
# Netlify secrets scan 오탐지 회피용 정리
# - flutter SDK 캐시에 'AIza...' 패턴이 포함되어 스캔이 실패하는 케이스가 있음
# - publish는 build/web 이므로 SDK/캐시는 제거해도 배포에는 영향 없음
# ------------------------------
echo "Cleanup: removing Flutter SDK/cache to avoid Netlify secret-scan false positives..."
rm -rf flutter || true