# 모바일 이미지 캡처 회귀 조사

## 변경 이력과 원인

- `784893d` (2026-08-22): 배포 SDK를 최신 stable에서 Flutter 3.19.6으로 고정.
  3.19.6의 auto renderer는 모바일에서 HTML renderer를 선택하며,
  HTML `Scene.toImage()`는 UnsupportedError를 발생시킨다.
  면허증과 두 덱 견본은 이 API를 사용하므로 이 배포 설정과 호환되지 않는다.
- `5df46e5` (2026-09-08): 리캡도 모바일에서는 기존 DOM 캡처를 제외하고
  `RepaintBoundary.toImage()`를 사용하도록 변경하여 같은 실패 경로에 들어간다.
- 같은 커밋에서 웹 다운로드가 직접 다운로드에서 모바일 파일 공유 우선으로 바뀌었다.
  비동기 캡처 후 호출하는 공유 API에는 사용자 입력 권한이 남아 있다고 보장할 수 없다.
- 복사도 PNG 생성 완료 후 `clipboard.write()`를 호출하고 있었다.
  Safari에서는 원래 탭에서 쓰기를 시작하고 PNG를 Promise로 전달해야 한다.

이는 저장소 이력과 SDK 코드에서 확인한 실패 경로다.
실제 제보자의 마지막 정상 배포 버전이나 사용 브라우저는 확인되지 않았다.

## 수정

기존 버튼과 한 번 누르는 흐름을 유지한다. 추가 저장 창은 제거했다.
웹 초기화와 배포 빌드는 CanvasKit으로 고정하고 공통 캡처에서 프레임 완료 대기와
이미지 메모리 해제를 처리한다. 리캡도 CanvasKit의 캡처를 사용한다.
다운로드는 원래의 직접 Blob 다운로드로 복구하고 URL은 지연 해제한다.
복사는 캡처 Future를 대기하지 않고 네이티브 JavaScript Promise로 전달하여,
원래 버튼 이벤트 안에서 clipboard.write를 호출한다.
클립보드 미지원/거부 시에는 기존 다운로드 대체 동작을 유지한다.

## 검증 명령

- `node --test test/image_export_web.test.js`
- `flutter test --no-pub test/capture_png_test.dart test/recap_service_test.dart`
- `flutter build web --release --no-pub --web-renderer canvaskit`
- `dart compile js -O2 -o .dart_tool/image_export_smoke/main.js test/image_export_interop_smoke.dart`
- `node test/run_image_export_interop_smoke.js` (Chrome 경로가 다르면 `CHROME_EXECUTABLE` 지정)

웹 동작 테스트 9개, Flutter 캡처/리캡 테스트 10개와 별도 Chrome 연동 검증이 통과했다.
별도 Chrome 검증은 Dart Future가 실제 ClipboardItem의 Promise<Blob>으로 전달되고,
PNG 완료 전 write가 호출되며, 캡처 오류가 Dart로 전달되는지 확인한다.
이 검증에서는 clipboard.write를 계측용 함수로 대체하므로 실기기 붙여넣기 검증을 대신하지 않는다.

실제 iPhone/Android 기기 및 배포 검증은 별도로 필요하다.
Windows의 Flutter 3.19.6 Chrome 테스트 서버에는 CanvasKit 경로가 404로 응답하는
환경 문제가 있어 Flutter Chrome 플랫폼 테스트를 완료하지 못했다.

참고: [WebKit Clipboard API의 사용자 입력과 Promise 지원](https://webkit.org/blog/10855/async-clipboard-api/).
