# Mimir Netlify Bandwidth 최적화 결과

## 최신 상태: badge 교체 및 미사용 파일 정리

아래 최신 상태가 우선합니다. 이후의 최초 최적화 기록과 `static-assets-lossless.json`은 당시 압축 작업의 이력입니다.
`static-assets-before.md/json`은 최초 비교 기준을 보존했고, `static-assets-after.md/json`은 현재 파일 기준으로 다시 생성했습니다.

### 이번에 삭제한 파일

| 파일 | 삭제 직전 bytes | 근거 |
|---|---:|---|
| `assets/images/raids/altruia.webp` | 120,424 | 전체 프로젝트 파일명/경로 참조 없음 |
| `assets/images/raids/crystalchamber.webp` | 103,562 | 전체 프로젝트 파일명/경로 참조 없음 |
| `assets/images/raids/ddugi.png` | 347,849 | 전체 프로젝트 파일명/경로 참조 없음 |
| `assets/images/raids/island_eater.png` | 5,338 | 전체 프로젝트 파일명/경로 참조 없음. 사용 중인 island_eater2.png는 유지 |
| `assets/images/raids/only_one.webp` | 21,790 | 전체 프로젝트 파일명/경로 참조 없음 |

총 5개, **598,963 bytes(0.571 MiB)** 제거했습니다.
삭제 직전 `rg --hidden --no-ignore --fixed-strings`로 각 파일명을 검색했으며 0건이었습니다.
`.git`, 의존성, 빌드, `.dart_tool`, 본 작업 리포트는 제외하고 숨김/ignored 소스와 scratch 개발 스크립트는 포함했습니다.
레이드 이미지 경로는 `lib/data/raid_data.dart`에 명시되어 있고 폴더 열거/파일명 동적 생성은 없습니다.
`SharedDeck` 저장/복원 모델에는 이미지 경로가 없으며 시즌과 니케 ID를 저장하므로 현재 공유 덱의 렌더링 경로도 확인했습니다.
이 추가 근거와 사용자의 정리 요청에 따라 최초의 보류 결정을 해제했습니다. 원격 저장소 자체를 조회한 것은 아닙니다.

`assets/images/only_one.png`는 사용자가 앞서 삭제한 상태를 그대로 유지했습니다. 이번 삭제분에 포함하지 않습니다.
사용자가 교체한 badge 4개도 그대로 보존했으며 badge 전체는 6,603,321 → **1,649,049 bytes(약 75% 감소)**입니다.

### 현재 디렉터리 용량

| 디렉터리 | 파일 수 | bytes |
|---|---:|---:|
| `assets/nikke/` | 200 | 5,222,252 |
| `assets/images/` | 23 | 2,899,647 |
| `assets/icons/` | 12 | 299,410 |
| `assets/data/` | 6 | 865,593 |

현재 이미지 인벤토리에서 리터럴 참조가 없는 파일은 burst 아이콘 4개뿐이며, 이들은 `icon-burst-$index.webp`로 동적 사용 중입니다.
`assets/data/nikke_calculator_db.json` 및 assets 루트의 통계 JSON은 scratch 계산/생성 스크립트에서 사용하므로 삭제하지 않았습니다.
최초 분석/압축 도구와 리포트는 유지보수 및 삭제 근거로 사용 중이므로 보존했습니다.
미사용 파일 제거량이 매 방문의 Bandwidth 절감량을 뜻하지는 않습니다.

검증: `flutter build web --release --no-pub` 성공(종료 코드 0).
실제 빌드와 AssetManifest에서 삭제 이미지 5개가 제외되고, 레이드/뱃지의 명시적 경로 31개 및 니케 200개가 유지됨을 확인했습니다.
이번 정리에서는 Dart 코드와 pubspec을 수정하지 않았으며 Netlify 배포는 실행하지 않았습니다.

## 최초 최적화 기록 (아래 수치는 최초 작업 당시 기준)

분석일: 2026-09-10. Flutter 3.19.6 / Dart 3.3.4. 소스 및 로컬 release 빌드 기준입니다.
실제 Netlify 요청 로그/HAR에는 접근하지 않았으므로 원인 순위는 추정이며 크레딧 절감을 실측한 결과는 아닙니다.

## 핵심 결과

- 니케 이미지 208개 → 200개. 모두 256×512 WebP이며 현재 JSON의 200개 imageUrl과 대응합니다.
- 미참조 PNG 8개, 1,508,189 bytes(1.438 MiB) 제거. 사용 중인 WebP 경로는 그대로입니다.
- PNG 16개 무손실 재압축: 655,661 bytes(0.625 MiB) 절감. 진행 메시지의 약 0.72 MiB는 부정확했으며 이 값이 최종 합계입니다.
- 총 정적 파일 감소: 2,163,850 bytes(2.064 MiB). 미사용 파일은 원래 요청되지 않을 수 있으므로 이 수치를 매 방문당 절감량으로 해석하면 안 됩니다.
- 이미지 재방문 캐시 1년 immutable. 실행 파일·데이터·생성 폰트·로컬 엔진은 재검증 유지.
- 모바일 덱 라이브러리의 shrinkWrap 전체 생성 구조를 SliverList로 변경.
- 카드 디자인·필터·덱 데이터·드래그·캡처·Firebase 로직은 변경하지 않았습니다. 사용자 선행 수정 4개 파일도 보존했습니다.

## 디렉터리별 용량

| 디렉터리 | 변경 전 파일 수 | 변경 후 파일 수 | 변경 전 bytes | 변경 후 bytes | 감소 bytes |
|---|---:|---:|---:|---:|---:|
| `assets/nikke/` | 208 | 200 | 6,730,441 | 5,222,252 | 1,508,189 |
| `assets/images/` | 29 | 29 | 11,852,657 | 11,245,106 | 607,551 |
| `assets/icons/` | 12 | 12 | 347,520 | 299,410 | 48,110 |
| `assets/data/` | 6 | 6 | 865,593 | 865,593 | 0 |

니케 포맷별: 변경 전 PNG 8개/1,508,189 bytes, WebP 200개/5,222,252 bytes, JPG/JPEG 0개/0 bytes.
변경 후 PNG 0개, WebP 200개/5,222,252 bytes(4.980 MiB), JPG/JPEG 0개입니다.

니케 및 전체 이미지 TOP 20, 모든 이미지의 참조, 포맷별 용량, 중복/유사도 후보는
[변경 전 인벤토리](static-assets-before.md)와 [변경 후 인벤토리](static-assets-after.md)에 전체 목록으로 기록했습니다.

## 변경한 파일

| 파일 경로 | 변경 코드/역할 | 예상 Bandwidth 영향 |
|---|---|---|
| `netlify.toml` | 실제 배포 이미지 경로 `/assets/assets/{nikke,images,icons}/`와 logo에 1년 immutable. HTML은 no-cache, JS/데이터/manifest/생성 폰트/로컬 CanvasKit은 재검증 | 캐시가 유지되는 이미지의 반복 전송 및 요청 감소. 재검증 파일은 내용이 같으면 304 가능 |
| `lib/screens/deck_library.dart` | 모바일 `SingleChildScrollView → Column → shrinkWrap ListView`를 `CustomScrollView + SliverToBoxAdapter + SliverList`로 변경. 동일 카드 builder 공유, 데스크톱은 `ListView.custom`과 기존 항목 수 semantics 유지 | 화면 밖 덱과 내부 이미지의 불필요한 생성/다운로드 감소. viewport 및 기본 cacheExtent 근처 항목은 미리 생성 가능 |
| `tool/audit_static_assets.py` | 읽기 전용 파일 크기·치수·경로/파일명 참조·SHA-256·RGBA 동일성·dHash 후보 조사 | 직접적인 런타임 효과 없음. 재점검/삭제 근거 제공 |
| `tool/optimize_png_assets.py` | PNG IDAT 압축만 교체. RGBA 및 나머지 청크 동일성 검증. 기본 dry-run, `--apply`만 쓰기 | 해상도·색상·메타데이터·경로를 유지하면서 전송 파일 크기 감소 |
| `docs/static-assets-report.md` | 본 결과와 유지보수·검증 기록 | 직접적인 런타임 효과 없음 |
| `docs/static-assets-before.md`, `docs/static-assets-before.json` | 삭제 전 인벤토리 및 참조 근거 | 직접적인 런타임 효과 없음 |
| `docs/static-assets-after.md`, `docs/static-assets-after.json` | 변경 후 인벤토리 | 직접적인 런타임 효과 없음 |
| `docs/static-assets-lossless.json` | 이미지별 압축 전후 bytes와 동일성 검증 결과 | 직접적인 런타임 효과 없음 |

다음 16개 파일은 모두 **PNG 내부 압축만 변경**했습니다. 파일마다 치수·RGBA 픽셀·IDAT 외 모든 청크가 동일합니다.
실제로 해당 이미지가 요청되면 아래 bytes만큼 원본 응답이 작아집니다. HTTP 계층 압축 효과와는 별개입니다.

| 파일 경로 | 역할 | 변경 전 bytes | 변경 후 bytes | 감소 bytes |
|---|---|---:|---:|---:|
| `assets/images/badge/600.png` | 업적 뱃지 | 1,101,923 | 1,025,366 | 76,557 |
| `assets/images/badge/911.png` | 업적 뱃지 | 1,918,056 | 1,841,483 | 76,573 |
| `assets/images/badge/CUBE.png` | 업적 뱃지 | 103,597 | 93,533 | 10,064 |
| `assets/images/badge/DAWN.png` | 업적 뱃지 | 2,146,315 | 2,062,585 | 83,730 |
| `assets/images/badge/FIREPOWER.png` | 업적 뱃지 | 121,933 | 114,854 | 7,079 |
| `assets/images/badge/LUCHE.png` | 업적 뱃지 | 92,192 | 85,347 | 6,845 |
| `assets/images/badge/NIKKE500.png` | 업적 뱃지 | 1,027,519 | 960,175 | 67,344 |
| `assets/images/badge/SHOES.png` | 업적 뱃지 | 133,923 | 122,979 | 10,944 |
| `assets/images/dorodojang.png` | 화면 이미지 | 1,011,036 | 876,605 | 134,431 |
| `assets/images/only_one.png` | 미참조 추정 이미지 | 2,841,360 | 2,792,224 | 49,136 |
| `assets/images/raids/annihilio.png` | 레이드 이미지 | 216,375 | 210,398 | 5,977 |
| `assets/images/raids/ddugi.png` | 미참조 추정 레이드 이미지 | 410,917 | 347,849 | 63,068 |
| `assets/images/raids/luxury_spider.png` | 레이드 이미지 | 105,932 | 90,129 | 15,803 |
| `assets/icons/google_g_logo.png` | 로그인 아이콘 | 33,661 | 26,302 | 7,359 |
| `assets/icons/lockkey.png` | 재료 아이콘 | 142,249 | 123,879 | 18,370 |
| `assets/icons/module.png` | 재료 아이콘 | 163,946 | 141,565 | 22,381 |

WebP 니케는 이미 평균 약 26 KiB로 작아 재손실압축/리사이즈하지 않았습니다.
대형 PNG는 손실 WebP 변환보다 절감 효과가 작더라도 정확한 픽셀 보존을 우선했습니다.
`dororong.png`는 확장자와 달리 실제 WEBP(1프레임)이므로 PNG 재압축에서 제외했습니다.

## 삭제한 파일

삭제 전 `rg --hidden` 전체 경로 검색에서 아래 PNG 참조가 없었습니다.
추가로 `rg --files --hidden --no-ignore`로 수집한 프로젝트 UTF-8 텍스트 285개에서
**전체 경로와 파일명+확장자를 각각 검색**했습니다. 백업·숨김·일반 ignored 소스와 JSON도 포함했습니다.
`.git`, dependency/SDK, build, `.dart_tool`, scratch, 생성 리포트는 실행 소스가 아니므로 제외했습니다.

`lib`의 `assets/nikke`, `imageUrl`, `Nikke.fromJson`, asset manifest 열거, PNG 동적 조합/확장자 치환도 함께 검토했습니다.
런타임은 JSON의 WebP imageUrl을 사용하며 수집 도구도 `{id}.webp`를 생성합니다. 원격 저장소를 조사한 것은 아닙니다.

| 파일 경로 | 제거 bytes | 삭제 이유/검색 근거 |
|---|---:|---|
| `assets/nikke/aegis.png` | 137,499 | 전체 경로·파일명 참조 0건. 동일 basename WebP가 존재하며 JSON에서 사용 |
| `assets/nikke/ark_ranger_black.png` | 211,315 | 전체 경로·파일명 참조 0건. 동일 basename WebP가 존재하며 JSON에서 사용 |
| `assets/nikke/cinderella_crystal_wave.png` | 218,839 | 전체 경로·파일명 참조 0건. 동일 basename WebP가 존재하며 JSON에서 사용 |
| `assets/nikke/makoto.png` | 181,285 | 전체 경로·파일명 참조 0건. 동일 basename WebP가 존재하며 JSON에서 사용 |
| `assets/nikke/marciana_marine_study.png` | 305,545 | 전체 경로·파일명 참조 0건. 동일 basename WebP가 존재하며 JSON에서 사용 |
| `assets/nikke/mint.png` | 77,345 | 전체 경로·파일명 참조 0건. 동일 basename WebP가 존재하며 JSON에서 사용 |
| `assets/nikke/prika.png` | 163,532 | 전체 경로·파일명 참조 0건. 동일 basename WebP가 존재하며 JSON에서 사용 |
| `assets/nikke/yukiko.png` | 212,829 | 전체 경로·파일명 참조 0건. 동일 basename WebP가 존재하며 JSON에서 사용 |

동일 basename 중복은 위 8개 PNG와 각각의 `.webp` 쌍입니다. **동일 픽셀이라는 의미는 아닙니다.**
삭제 근거는 현재 참조 부재와 대체 WebP의 실제 사용입니다.
전체 이미지에서 동일 바이트/동일 RGBA 중복은 발견되지 않았으며 니케 dHash 거리 ≤ 4 후보도 없었습니다.
유사도 검사는 의미상 같은 캐릭터, 다른 스킨/크롭의 동일성을 증명하지 않습니다.

## 삭제하지 않았지만 의심되는 파일

아래 파일은 전체 경로 및 파일명 참조가 없지만 과거/향후 레이드 데이터나 외부 입력 경로 가능성을 배제하지 못해 남겼습니다.

| 파일 경로 | 변경 후 bytes | 판단 |
|---|---:|---|
| `assets/images/only_one.png` | 2,792,224 | 5760×5760 대형 이미지, 미참조 추정, 삭제 보류 |
| `assets/images/raids/altruia.webp` | 120,424 | 미참조 추정, 삭제 보류 |
| `assets/images/raids/crystalchamber.webp` | 103,562 | 미참조 추정, 삭제 보류 |
| `assets/images/raids/ddugi.png` | 347,849 | 미참조 추정, 삭제 보류 |
| `assets/images/raids/island_eater.png` | 5,338 | 미참조 추정, 삭제 보류 |
| `assets/images/raids/only_one.webp` | 21,790 | 미참조 추정, 삭제 보류 |

`assets/icons/burst/icon-burst-0.webp` ~ `icon-burst-3.webp`는 전체 경로 검색에는 없지만
`nikke_card.dart`의 `'assets/icons/burst/icon-burst-$index.webp'`에서 **동적 사용 중**이므로 삭제 대상이 아닙니다.
남은 니케 WebP 200개는 모두 JSON에서 참조되어 미사용 의심 파일이 없습니다.

## 니케 목록 및 이미지 캐시 점검

| 위치 | 확인 결과/판단 |
|---|---|
| `deck_builder.dart`, `union_deck_builder.dart` 니케 선택 목록 | Expanded 안 GridView.builder, 최대 카드 폭 150, shrinkWrap 없음. 유지 |
| `my_nikke_screen.dart` 니케 그리드/리스트 | Expanded 안 GridView.builder(최대 폭 105)/ListView.builder. 유지 |
| `deck_library.dart` 니케 선택 목록 | 모바일 유한 높이 SizedBox, 데스크톱 Expanded 안 GridView.builder. 유지 |
| `matcha_gakseol_form.dart` 선택창 | Expanded 안 GridView.builder. 유지 |
| `deck_library.dart` 모바일 결과 목록 | 무제한 부모 안 shrinkWrap 전체 생성 → SliverList로 수정 |
| `Wrap`, `Column`, 기타 shrinkWrap | 필터 칩, 고정 스쿼드, 소수 계산 입력, 선택 니케 상세 스탯 등. 전체 니케 이미지를 나열하는 구조 아님 |
| `AnimatedCrossFade` 덱 내용 | 접힌 카드도 secondChild를 생성할 수 있음. 기존 애니메이션은 유지하고 화면 밖 덱 생성 범위를 축소 |

`lib`, `web`에서 전체 니케 precacheImage, imageCache 비우기/evict, cache-busting URL, downloadOffline 호출은 발견되지 않았습니다.
필터는 데이터 목록을 재계산하지만 이미지 URL은 그대로입니다. 동일 AssetImage 키는 Flutter 전역 ImageCache의 pending/decoded 이미지를 공유합니다.
따라서 위젯 rebuild를 네트워크 재다운로드나 재decode와 동일시하면 안 됩니다. eviction·캐시 만료·다른 ResizeImage 크기 키는 별도 조건입니다.

Image.asset은 목록·아이콘·캡처, AssetImage는 고정 입력/상세 DecorationImage에 사용됩니다.
Image.network는 NikkeCard의 원격 URL 분기이며, 현재 JSON은 전부 로컬 WebP입니다.
외부 서버 이미지에는 Netlify 정적 헤더가 적용되지 않습니다.

NikkeCard 원본 256×512는 논리 폭 105~150의 고해상도 화면에서 과도한 크기가 아닙니다.
한 장 RGBA는 약 0.5 MiB이고 200장 전체는 약 100 MiB입니다. 기본 Flutter ImageCache 한도는 100 MiB/1000개이므로 전체 preloading은 피해야 합니다.
이번에는 니케 썸네일 cacheWidth/cacheHeight를 일괄 추가하지 않았습니다.
DPR·BoxFit.cover·캡처 배율을 고려하지 않은 축소나 크기별 캐시 키 분리는 품질과 재사용에 불리할 수 있습니다.

업적 뱃지는 이미 cacheWidth/cacheHeight 256 및 high filterQuality를 사용하므로 유지했습니다.
큰 dorodojang과 508px 재료 아이콘의 작은 표시 영역은 추가 decode 최적화 후보입니다.
캡처에 쓰이는 dorodojang 축소는 보류했습니다. **cacheWidth/Height는 다운로드 bytes를 줄이지 않습니다.**
Flutter Web renderer에 따라 decode/리사이즈 처리도 달라 네트워크 절감으로 계산하지 않았습니다.

## Netlify 캐시 정책과 업데이트 안전성

| 배포 URL | 정책 |
|---|---|
| `/assets/assets/nikke/*`, `/assets/assets/images/*`, `/assets/assets/icons/*`, logo | public, max-age=31536000, immutable |
| `/`, `/index.html`, `/version.json`, `/manifest.json` | no-cache |
| root JS(실행 JS, flutter.js, bootstrap, 서비스워커, deferred JS) | public, max-age=0, must-revalidate |
| nikkes.json, assets/data, AssetManifest.*, FontManifest.json | public, max-age=0, must-revalidate |
| 생성 폰트, package assets, 로컬 `/canvaskit/*` | public, max-age=0, must-revalidate |

`/assets/*` 전체 immutable은 JSON/계산 DB/manifest까지 고정하므로 실제 이미지 경로로 좁혔습니다.
상충하는 broad 캐시와 예외를 중첩하지 않았습니다.

**이미지 교체 시에는 새 파일명을 사용하고 참조를 수정해야 합니다.** 현재 이름에는 content hash가 없습니다.
이번 배포부터 이미지 URL은 immutable로 취급합니다. 같은 이름으로 덮어쓰면 브라우저에 최대 1년 동안 이전 이미지가 남을 수 있으며 재배포/서버 purge로 해결되지 않습니다.
`tool/collect_nikke_full.ps1`로 기존 `{id}.webp`를 다시 수집해 교체할 때도 새 이름으로 배포해야 합니다.
이번 압축 변경은 최초 장기 캐시 도입과 함께 배포되며 픽셀도 동일합니다. 자동 해시 파일명은 후속 권장 사항입니다.

요청 예시의 로컬 `/canvaskit/*` 1년 immutable은 적용하지 않았습니다.
설치 SDK와 실제 main.dart.js에서 CanvasKit URL이 다음 엔진 버전별 외부 CDN임을 확인했습니다:
`https://www.gstatic.com/flutter-canvaskit/c4cd48e186460b32d44585ce3c103271ab676355/`.
이 전송은 Netlify 이미지 Bandwidth와 다릅니다. 로컬 fallback은 SDK 업그레이드에도 이름이 같아 장기 immutable이면 엔진 충돌 위험이 있습니다.
로컬 호스팅을 선택하려면 먼저 엔진 해시 디렉터리와 해당 URL을 지정해야 합니다.

폰트도 이번 빌드에서 MaterialIcons 21,996 bytes, CupertinoIcons 1,172 bytes로 tree-shaking되었습니다.
아이콘 사용 변경으로 같은 이름의 내용이 달라질 수 있어 재검증을 유지했습니다. 내용이 같으면 HTTP 재검증 시 본문 재전송 없이 이용할 수 있습니다.

서비스워커 CORE는 main.dart.js, index.html, AssetManifest.bin.json, FontManifest.json 4개입니다.
RESOURCES에 이미지가 열거되는 것은 전체 이미지를 prefetch한다는 뜻이 아닙니다.
앱에는 downloadOffline 호출이 없고 서비스워커 기능/업데이트 방식은 변경하지 않았습니다.

## pubspec.yaml 등록 점검

변경하지 않았습니다. Flutter 디렉터리 등록은 일반 하위 디렉터리를 재귀 등록하지 않으며 resolution-aware 변형이 예외입니다.
`assets/images/badge/`, `assets/images/raids/`, `assets/icons/elements/`, `assets/icons/burst/`는 필요한 별도 선언입니다.
데이터 폴더 6개 파일도 유지했습니다. [Flutter 공식 등록 규칙](https://docs.flutter.dev/ui/assets/assets-and-images)

## 가장 큰 대역폭 원인 후보

1. **실제로 노출되는 대형 PNG 뱃지/화면 이미지**: 변경 후 DAWN 약 1.97 MiB, 911 약 1.76 MiB, 600 약 0.98 MiB, NIKKE500 약 0.92 MiB, dorodojang 약 0.84 MiB. decode 제한은 전송량을 줄이지 않습니다. 더 큰 only_one은 현재 참조가 없어 최대 트래픽 원인으로 단정하지 않았습니다.
2. **반복 방문/세션의 이미지 재다운로드 가능성**: 기존 netlify.toml에는 이미지 freshness 설정이 없었습니다. 실제 SW/브라우저 캐시 적중률에 따라 효과가 달라집니다. 이번 장기 캐시가 대응합니다.
3. **모바일 덱 라이브러리의 화면 밖 덱 생성**: 접힌 CrossFade 내용도 생성될 수 있어 여러 덱의 서로 다른 니케를 불필요하게 로딩할 수 있습니다. SliverList로 범위를 줄였습니다.
4. **신규 방문/업데이트의 Flutter 실행 코드**: 로컬 main.dart.js 원본 약 3.19 MiB. HTTP 압축 후 bytes는 다르며 서비스워커 CORE와 배포 빈도도 영향을 줍니다.
5. **니케 이미지 누적 전송**: 전체 200개 약 4.98 MiB. 모두 스크롤해 봤을 때의 총량이며 진입 시 전체 전송은 아닙니다.

로컬 build/web의 여러 CanvasKit WASM 및 source map 크기를 일반 방문당 다운로드량으로 합산하지 않았습니다.
CanvasKit은 외부 CDN 사용, source map은 일반 화면 렌더링에 필요한 요청이 아닙니다. 크레딧 합계만으로 URL별 원인을 확정할 수 없습니다.

## 추가로 권장하는 최적화

- Network/HAR와 Netlify URL별 통계로 상위 전송 파일, memory/disk/SW cache 적중률을 측정합니다. 첫 방문·재방문·필터·모바일 스크롤·배포 직후를 분리합니다.
- 큰 뱃지 PNG에 WebP/썸네일을 만들어 DPR과 실제 크기로 시각 비교합니다. 캡처/확대 원본과 표시 경로를 분리하면 무손실 압축보다 큰 효과가 가능합니다.
- 이미지/폰트 content-hash 파일명과 manifest 자동화를 도입하면 업데이트도 안전하게 장기 캐시할 수 있습니다. 현재 이미지 교체는 새 파일명과 참조 갱신이 필수입니다.
- 보류 레이드/only_one 파일은 운영 데이터·과거 콘텐츠 사용 확인 후 제거를 검토합니다.
- 접힌 덱의 최초 펼침 전 내용 생성 지연은 애니메이션/높이 상태 검증 후 적용할 수 있습니다. 이번 CrossFade는 유지했습니다.
- 고정 재료 아이콘부터 DPR에 맞춘 decode 크기와 공통 캐시 키를 검토합니다. 네트워크 절감과 메모리 절감은 따로 측정합니다.

## 검증

- `flutter analyze --no-pub`: 전후 warning 5개 + info 40개 = 45개로 동일. 이슈 문자열 집합도 동일, 신규 error/warning/info 0개. 기존 경고 때문에 종료 코드 1입니다.
- 기존 warning: overload_simulator_model.dart unused_import 1개, my_nikke_screen.dart의 formattedHp400/formattedAtk400/formattedDef400 unused_local_variable 3개, test/find_null_error.dart unused_import 1개. 사용자 선행 변경을 포함한 시작 시점과 비교했습니다.
- `flutter build web --release --no-pub`: 성공, 종료 코드 0. 로컬과 netlify/build.sh 모두 Flutter 3.19.6입니다.
- `flutter test --no-pub test/achievement_badge_showcase_test.dart test/shared_deck_test.dart test/nikke_element_filter_test.dart test/nikke_blabla_mapping_test.dart test/deck_code_utils_test.dart`: 8개 통과.
- 최종 semantics 보존 수정 후 `dart analyze lib/screens/deck_library.dart`: No issues found.
- 실제 AssetManifest: 니케 WebP 200개/PNG 0개. JSON의 200개 경로와 manifest의 모든 파일 존재. 압축 소스 bytes와 빌드 파일 bytes 동일.
- PNG 16개: 전체 RGBA 픽셀·치수 동일, IDAT 외 청크 byte-for-byte 동일.
- netlify.toml tomllib 파싱 및 대표 이미지/JSON/manifest/JS/HTML/font/CanvasKit 경로별 정책 분리 확인. 실제 Netlify 응답 헤더/적중률 측정은 아닙니다.
- `git diff --check`: 통과. LF→CRLF 메시지는 Windows 환경의 줄바꿈 안내입니다.
- 모바일 Sliver 변경은 analyze/release 빌드로 확인했으며 실제 브라우저 상호작용·스크린샷 회귀 비교는 미실시했습니다. 카드 builder·애니메이션·콜백·필터 로직은 유지했습니다.
- 선행 수정 `functions/accountElementAdjusted.md`, `lib/screens/my_nikke_screen.dart`, `lib/services/recap_service.dart`, `test/recap_service_test.dart`는 이번 작업에서 편집하지 않았습니다.
- Netlify 배포는 실행하지 않았습니다. 캐시 헤더는 이 변경 배포 후부터 적용됩니다.

재실행: `python -m pip install Pillow` (이번 분석 12.3.0), `python tool/audit_static_assets.py --output docs/static-assets-after.md`.
`python tool/optimize_png_assets.py`는 dry-run입니다. 이후 immutable 배포 이미지에는 같은 이름으로 `--apply`하지 마세요.

기준: [Netlify custom headers](https://docs.netlify.com/manage/routing/headers/), [Netlify caching overview](https://docs.netlify.com/build/caching/caching-overview/).
엔진·ImageCache·서비스워커 동작은 설치된 Flutter 3.19.6 SDK 소스와 실제 release 결과를 확인했습니다.
