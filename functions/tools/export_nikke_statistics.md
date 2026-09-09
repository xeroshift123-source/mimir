# 니케 통계 일회성 JSON 추출

`functions/tools/export_nikke_statistics.js`는 기존 `functions/node_modules`의 Firebase Admin SDK를 사용하는 독립 CLI입니다. 기존 도구 폴더에 두었으며 `index.js`에 등록하지 않으므로 서비스 실행 경로에 추가되지 않습니다. 배포는 필요 없습니다. production 계산식과 업적은 변경하지 않습니다.

## 확인한 현재 구현

- `.firebaserc`: 프로젝트 `nikke-mimir`. `firebase.json` 및 `functions/index.js`: **이름 있는 DB `mimirdb`** 사용.
- `lib/services/nikke_statistics_service.dart`: Flutter에서 Functions 통계 API 호출.
- `functions/nikkeStatistics.js`: 장비 옵션 ID를 수치로 변환하고 니케 속성별로 우월코드를 단순 합산. 복수 속성 니케는 각 속성에 반영. 상위 %는 `(큰 값의 수 + 동점 수 × 0.5) / 표본 수 × 100`.
- `functions/nikkeStatisticsStore.js`: 연동 바인딩이 있고 최근 30일 내 갱신된 지휘관 계정으로 집계. 니케 표본은 그 니케를 보유한 계정 수이며, 고유 사람 수나 게임 전체 유저 수가 아님. 캐시 ID는 `all_<nameCode>`, 현행 schemaVersion은 8, 최소 표본 20. 같은 컬렉션의 `account_element_damage`는 계정 속성 통계이므로 추출에서 제외.
- `functions/nikkeStatisticsSchedule.js`: 매일 한국 시간 00:00 갱신. 이 도구는 갱신 함수를 호출하지 않음.
- `functions/nikkeStatisticsEndpoint.js`: 응답에서 histogram을 제거하고 조건에 따라 바인딩 정보를 쓰므로 추출용으로 호출하지 않음.

`overload`는 객체가 아닌 옵션별 배열입니다. `userCount`는 해당 옵션 보유 계정 수, `sampleCount`는 해당 니케 전체 표본 수입니다. 전체 평균은 미보유자도 분모에 포함하고 `adopterAverage*`는 옵션 보유자만 포함합니다. `adoptionRate`는 0~100 단위입니다. 현행 histogram은 니케별 옵션 합계(소수 두 자리 문자열)를 계정 수에 대응시키며 미보유자는 `0.00`에 포함합니다.

**저장 시 평균 줄 수 등의 순서로 상위 5개 옵션만 남습니다.** 우월코드 항목이 없다고 0%로 대체하면 안 됩니다. 누락된 옵션이나 줄 수의 전체 분포, 애장품 여부, 투자 시계열은 이 캐시에서 복원할 수 없습니다. 상위 투자자 수치 분포는 저장된 histogram으로 분석할 수 있지만, 투자 전인 신규 딜러와 중요도가 낮은 니케를 단일 시점 투자 통계만으로 확정 구분할 수는 없습니다. 이번 도구는 계수를 결정하지 않습니다.

## 인증과 실행 (PowerShell)

Node.js 20 이상과 `functions` 의존성이 필요합니다(프로젝트 engines는 20). 현재 작업 환경에는 node_modules가 이미 있습니다. 없는 환경에서만 `npm --prefix functions ci`를 실행합니다.

Admin SDK는 ADC(Application Default Credentials)를 사용합니다. `firebase login`이나 앱의 Firebase API key, `functions/.env`만으로는 이 도구의 ADC 인증이 구성되지 않습니다. DB 읽기 IAM 권한이 있는 계정이 필요하며, 읽기 전용 계정의 예는 `roles/datastore.viewer`입니다. 이 도구는 IAM 권한을 변경하지 않습니다.

Google Cloud CLI가 설치된 환경에서:

```powershell
Set-Location C:\MMR\mimir
gcloud auth application-default login
node .\functions\tools\export_nikke_statistics.js
```

이미 보유한 서비스 계정 인증 JSON을 사용하는 경우에는 로그인 대신 다음과 같이 실제 파일 경로를 지정합니다. 키 파일은 저장소 밖에 보관하고 분석 파일과 함께 업로드하지 않습니다.

```powershell
Set-Location C:\MMR\mimir
$env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\secure\YOUR_EXISTING_SERVICE_ACCOUNT.json'
node .\functions\tools\export_nikke_statistics.js
```

2026-09-09 확인 당시 현재 셸에는 `GOOGLE_APPLICATION_CREDENTIALS`, 표준 위치의 로컬 ADC 파일 및 PATH의 `gcloud`가 확인되지 않았습니다. 인증 전에는 실제 서버 추출을 완료할 수 없습니다.

기본 출력: `C:\MMR\mimir\nikke_statistics_export.json`. 실행 폴더와 무관하게 저장소 루트를 기준으로 합니다. 기존 파일은 덮어쓰지 않습니다. 재실행하려면 새 경로를 지정합니다(상위 폴더는 이미 있어야 함).

```powershell
node .\functions\tools\export_nikke_statistics.js --output .\nikke_statistics_export_2.json
```

## 출력 및 읽기 범위

- 문서 ID의 `all_` 범위를 100개씩 조회하고 `all_<양의 정수>`와 내부 nameCode 일치를 검증합니다. 별도 계정 컬렉션이나 하위 컬렉션은 읽지 않습니다.
- Firestore에는 쿼리 `get()`만 수행합니다. write/update/delete, 배치 쓰기, 트랜잭션, 통계 재생성 및 API 호출은 없습니다. 일반 문서 읽기 비용은 발생할 수 있습니다.
- 최상위 `documents`에 니케별 통계가 있고 추출 시각, 대상 DB, 문서 수, 분석 주의사항을 함께 기록합니다.
- 기존 집계 필드만 명시적으로 허용합니다. overload의 모든 저장 옵션과 histogram bin, combinedOffense, skillPresets, equipmentPresets, 표본·스키마·신선도 메타데이터를 보존합니다. UID/openId/개인 비교 필드 등 미지의 필드는 포함하지 않습니다.
- Timestamp는 `{iso, seconds, nanoseconds}`로 기록해 나노초도 보존합니다. 원래 없는 필드는 보충하지 않습니다. 다른 스키마의 필드 형식이 맞지 않으면 오류로 중단합니다.
- 여러 페이지는 단일 시점 스냅샷이 아닙니다. 추출 중 일일 갱신이 겹칠 수 있으므로 분석 시 문서별 generatedAt/schemaVersion을 확인합니다.
- 빈 결과 또는 읽기/변환 실패 시 JSON을 쓰지 않습니다. 기본 파일명 패턴은 gitignore에 추가했습니다.

검증 명령(인증/네트워크 불필요):

```powershell
node --test .\functions\tools\export_nikke_statistics.test.js
node .\functions\tools\export_nikke_statistics.js --help
```

인증 참고: [Firebase Admin SDK 설정](https://firebase.google.com/docs/admin/setup), [ADC 로그인](https://docs.cloud.google.com/sdk/gcloud/reference/auth/application-default/login), [Firestore IAM](https://firebase.google.com/docs/firestore/security/iam).
