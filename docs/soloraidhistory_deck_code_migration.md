# Solo Raid History용 미미르 덱 코드 마이그레이션 가이드

이 문서는 [Solo Raid History](https://soloraidhistory.vercel.app/)에서 미미르(Mimir) 덱 코드를 계속 사용할 수 있도록, 2026년 8월에 변경된 캐릭터 식별자 규격과 적용 코드를 정리한 개발자 전달용 문서입니다.

## 1. 변경 요약

미미르 덱 코드의 `squads` 슬롯에 저장하는 캐릭터 식별자가 다음과 같이 변경되었습니다.

| 구분 | 기존 코드 | 신규 코드 |
| --- | --- | --- |
| 식별자 | `nikkes.json`의 `id` | `nikkes.json`의 `blablaNameCode` |
| JSON 타입 | `string` | `number` |
| 예시 | `"red_hood"` | `5101` |
| 빈 슬롯 | `null` | `null` |

`name`은 덱 코드에 저장하지 않습니다. 신규 코드를 생성할 때 `blablaNameCode`를 문자열로 변환하지 말고 JSON 숫자로 저장해야 합니다.

미미르 앱은 기존 문자열 `id` 코드도 계속 불러올 수 있습니다. Solo Raid History에서도 기존 공유 링크가 깨지지 않도록 `number | string | null`을 모두 받아들이는 것을 권장합니다.

## 2. 신규 페이로드 예시

솔로 레이드 코드를 Base64URL 디코딩하면 다음 JSON이 나옵니다.

```json
{
  "type": "solo",
  "squads": [
    [5101, 5065, 5011, 5099, 5044],
    [5061, 5008, 5004, 5009, 3005],
    [null, null, null, null, null],
    [null, null, null, null, null],
    [null, null, null, null, null]
  ]
}
```

위 첫 번째 스쿼드의 대응 관계는 다음과 같습니다.

| 캐릭터 | 기존 `id` | 신규 `blablaNameCode` |
| --- | --- | ---: |
| 레드 후드 | `red_hood` | 5101 |
| 크라운 | `crown` | 5065 |
| 리타 | `liter` | 5011 |
| 나가 | `naga` | 5099 |
| 모더니아 | `modernia` | 5044 |

유니온 레이드도 `squads` 식별자만 동일하게 변경됩니다. 기존의 `type: "union"`과 `elements` 필드는 그대로 유지됩니다.

## 3. 권장 TypeScript 타입

신규 코드만 표현하는 타입과, 실제 디코더가 반환할 호환 타입을 분리하는 편이 안전합니다.

```ts
export type BlablaNameCode = number;
export type LegacyNikkeId = string;
export type DeckSlotIdentifier = BlablaNameCode | LegacyNikkeId | null;

export interface MimirDeckCodePayload {
  type: "solo" | "union";
  squads: DeckSlotIdentifier[][];
  elements?: string[];
}

export interface NewMimirDeckCodePayload {
  type: "solo" | "union";
  squads: Array<Array<BlablaNameCode | null>>;
  elements?: string[];
}
```

## 4. Base64URL 디코더

Base64URL 문자열은 패딩 `=`이 있거나 없을 수 있으므로 양쪽 모두 처리해야 합니다.

```ts
function decodeBase64UrlUtf8(code: string): string {
  let base64 = code.trim().replace(/-/g, "+").replace(/_/g, "/");
  base64 += "=".repeat((4 - (base64.length % 4)) % 4);

  const binary = atob(base64);
  const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
  return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
}

function isDeckSlotIdentifier(value: unknown): value is DeckSlotIdentifier {
  return (
    value === null ||
    typeof value === "string" ||
    (typeof value === "number" && Number.isSafeInteger(value))
  );
}

export function decodeMimirDeckCode(
  code: string,
): MimirDeckCodePayload | null {
  try {
    if (!code.trim()) return null;

    const decoded: unknown = JSON.parse(decodeBase64UrlUtf8(code));
    if (typeof decoded !== "object" || decoded === null) return null;

    const value = decoded as Record<string, unknown>;
    const type = value.type === "union" ? "union" : "solo";
    if (!Array.isArray(value.squads)) return null;

    const squads = value.squads.map((rawSquad) => {
      if (!Array.isArray(rawSquad)) throw new Error("Invalid squad");

      // 미미르와 동일하게 각 스쿼드를 5슬롯으로 정규화합니다.
      return Array.from({ length: 5 }, (_, index) => {
        const identifier = rawSquad[index] ?? null;
        return isDeckSlotIdentifier(identifier) ? identifier : null;
      });
    });

    const elements = Array.isArray(value.elements)
      ? value.elements.map(String)
      : undefined;

    return { type, squads, elements };
  } catch {
    return null;
  }
}
```

## 5. `blablaNameCode` 기반 캐릭터 매핑

Solo Raid History가 사용하는 니케 데이터에 `blablaNameCode` 필드를 포함하고 숫자 인덱스를 만들어야 합니다. 미미르 저장소의 최신 `assets/nikkes.json`에는 현재 199개 항목 모두 `blablaNameCode`가 있으며 중복 값은 없습니다.

```ts
export interface NikkeData {
  id: string;
  name: string;
  blablaNameCode: number;
  // 사이트에서 사용하는 나머지 필드
  [key: string]: unknown;
}

export function buildNikkeIndexes(nikkes: NikkeData[]) {
  const byBlablaNameCode = new Map<number, NikkeData>();
  const byLegacyId = new Map<string, NikkeData>();

  for (const nikke of nikkes) {
    if (!Number.isSafeInteger(nikke.blablaNameCode)) {
      throw new Error(`Invalid blablaNameCode: ${nikke.id}`);
    }
    if (byBlablaNameCode.has(nikke.blablaNameCode)) {
      throw new Error(`Duplicate blablaNameCode: ${nikke.blablaNameCode}`);
    }

    byBlablaNameCode.set(nikke.blablaNameCode, nikke);
    byLegacyId.set(nikke.id, nikke);
  }

  return { byBlablaNameCode, byLegacyId };
}
```

신규 숫자 코드와 기존 문자열 코드를 모두 해석하는 함수는 다음처럼 구현할 수 있습니다.

```ts
export function resolveDeckSlot(
  identifier: DeckSlotIdentifier,
  indexes: ReturnType<typeof buildNikkeIndexes>,
): NikkeData | null {
  if (identifier === null) return null;

  if (typeof identifier === "number") {
    return indexes.byBlablaNameCode.get(identifier) ?? null;
  }

  // 기존 id 기반 코드를 먼저 찾습니다.
  const legacyMatch = indexes.byLegacyId.get(identifier);
  if (legacyMatch) return legacyMatch;

  // 다른 구현에서 숫자를 문자열로 저장한 경우도 방어적으로 허용합니다.
  if (/^\d+$/.test(identifier)) {
    return indexes.byBlablaNameCode.get(Number(identifier)) ?? null;
  }

  return null;
}
```

화면에 덱을 적용할 때는 다음처럼 변환합니다.

```ts
const payload = decodeMimirDeckCode(inputCode);
if (!payload) {
  throw new Error("올바르지 않은 미미르 덱 코드입니다.");
}

const indexes = buildNikkeIndexes(nikkes);
const resolvedSquads = payload.squads.map((squad) =>
  squad.map((identifier) => resolveDeckSlot(identifier, indexes)),
);
```

매핑되지 않은 숫자 코드는 전체 가져오기를 실패시키기보다 해당 슬롯만 `null` 또는 “알 수 없는 니케”로 표시하는 것을 권장합니다. 이렇게 하면 미미르에 신규 캐릭터가 먼저 추가된 경우에도 나머지 덱은 복원할 수 있습니다.

## 6. 덱 코드 생성 기능이 있는 경우

Solo Raid History에서도 미미르 호환 코드를 생성한다면 반드시 `blablaNameCode` 숫자를 사용합니다.

```ts
function encodeBase64UrlUtf8(value: string): string {
  const bytes = new TextEncoder().encode(value);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);

  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

export function encodeMimirDeckCode(
  type: "solo" | "union",
  squads: Array<Array<NikkeData | null>>,
  elements?: string[],
): string {
  const payload: NewMimirDeckCodePayload = {
    type,
    squads: squads.map((squad) =>
      Array.from(
        { length: 5 },
        (_, index) => squad[index]?.blablaNameCode ?? null,
      ),
    ),
    ...(elements ? { elements } : {}),
  };

  return encodeBase64UrlUtf8(JSON.stringify(payload));
}
```

## 7. 파일 업데이트 체크리스트

Solo Raid History 저장소의 실제 디렉터리명에 맞춰 다음 역할의 파일을 찾아 업데이트하면 됩니다.

1. **니케 데이터 파일**
   - 미미르의 최신 `assets/nikkes.json`을 기준으로 `blablaNameCode`를 반영합니다.
   - 모든 캐릭터에 숫자 코드가 존재하는지와 중복이 없는지 검사합니다.
2. **덱 코드 타입 파일**
   - 슬롯 타입을 기존 `string | null`에서 `number | string | null`로 변경합니다.
   - 신규 코드 생성용 타입은 `number | null`로 제한합니다.
3. **덱 코드 디코더**
   - 숫자 `blablaNameCode`를 허용합니다.
   - 기존 문자열 `id`도 삭제하지 않고 호환 경로로 유지합니다.
4. **캐릭터 조회 로직**
   - `Map<number, Nikke>` 형태의 `blablaNameCode` 인덱스를 추가합니다.
   - 문자열 입력은 기존 `id` 인덱스로 조회합니다.
5. **덱 코드 인코더**
   - `nikke.id` 대신 `nikke.blablaNameCode`를 저장합니다.
   - 숫자에 `String(...)` 또는 `.toString()`을 적용하지 않습니다.
6. **UI 오류 처리**
   - 아직 사이트 데이터에 없는 코드는 빈 슬롯 또는 알 수 없는 캐릭터로 표시합니다.
7. **테스트**
   - 신규 숫자 코드 디코딩
   - 기존 문자열 코드 디코딩
   - 빈 슬롯
   - 알 수 없는 숫자 코드
   - 솔로/유니온 타입 구분
   - 유니온 `elements` 유지

권장 파일 구성 예시는 다음과 같습니다.

```text
src/
  data/nikkes.json                 # blablaNameCode 데이터
  types/deckCode.ts                # 호환 페이로드 타입
  utils/mimirDeckCode.ts           # 인코딩/디코딩 및 resolveDeckSlot
  utils/mimirDeckCode.test.ts      # 신규/레거시 테스트
```

## 8. Vitest 테스트 예시

```ts
import { describe, expect, it } from "vitest";
import { decodeMimirDeckCode, resolveDeckSlot } from "./mimirDeckCode";

const newCode =
  "eyJ0eXBlIjoic29sbyIsInNxdWFkcyI6W1s1MTAxLDUwNjUsNTAxMSw1MDk5LDUwNDRdLFtudWxsLG51bGwsbnVsbCxudWxsLG51bGxdLFtudWxsLG51bGwsbnVsbCxudWxsLG51bGxdLFtudWxsLG51bGwsbnVsbCxudWxsLG51bGxdLFtudWxsLG51bGwsbnVsbCxudWxsLG51bGxdXX0";

const legacyCode =
  "eyJ0eXBlIjoic29sbyIsInNxdWFkcyI6W1sicmVkX2hvb2QiLCJjcm93biIsImxpdGVyIiwibmFnYSIsIm1vZGVybmlhIl0sW251bGwsbnVsbCxudWxsLG51bGwsbnVsbF0sW251bGwsbnVsbCxudWxsLG51bGwsbnVsbF0sW251bGwsbnVsbCxudWxsLG51bGwsbnVsbF0sW251bGwsbnVsbCxudWxsLG51bGwsbnVsbF1dfQ";

describe("Mimir deck code migration", () => {
  it("decodes the new numeric code", () => {
    expect(decodeMimirDeckCode(newCode)?.squads[0]).toEqual([
      5101, 5065, 5011, 5099, 5044,
    ]);
  });

  it("keeps legacy string ids", () => {
    expect(decodeMimirDeckCode(legacyCode)?.squads[0]).toEqual([
      "red_hood", "crown", "liter", "naga", "modernia",
    ]);
  });
});
```

## 9. 미미르 측 변경 파일

참고용으로 미미르 저장소에서는 다음 파일이 변경되었습니다.

- `lib/screens/deck_builder.dart`: 솔로 덱 내보내기 및 가져오기
- `lib/screens/union_deck_builder.dart`: 유니온 덱 내보내기 및 가져오기
- `lib/utils/deck_code_utils.dart`: 숫자/문자열 호환 페이로드 파싱
- `assets/nikkes.json`: `id`, `name`, `blablaNameCode` 원본 매핑 데이터
- `docs/mimir_deck_code_spec.md`: 덱 코드 규격서
- `test/deck_code_utils_test.dart`: 신규 숫자 코드와 레거시 코드 테스트

## 10. 적용 완료 기준

다음 조건을 모두 만족하면 마이그레이션이 완료된 것입니다.

- 최신 미미르에서 복사한 덱 코드를 Solo Raid History에서 정상적으로 불러온다.
- 신규 코드의 슬롯 값이 문자열이 아닌 숫자 `blablaNameCode`로 디코딩된다.
- 변경 이전의 문자열 `id` 코드도 계속 불러온다.
- 사이트에 아직 등록되지 않은 캐릭터가 있어도 전체 덱 가져오기가 실패하지 않는다.
- 사이트에서 코드를 다시 생성한다면 숫자 `blablaNameCode`를 사용한다.

