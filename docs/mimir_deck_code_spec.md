# 📄 미미르(Mimir) 솔로 레이드 덱 코드 연동 및 디코딩 규격서

타 웹사이트 및 커뮤니티 개발자가 **미미르(Mimir) 앱에서 생성된 솔로 레이드 덱 코드를 디코딩하고 붙여넣기 기능**을 구현할 수 있도록 작성된 기술 명세서입니다.

---

## 1. 덱 코드 개요 (Overview)

- **인코딩 방식**: JSON 구조체 ➔ UTF-8 바이트 배열 ➔ **Base64 URL-Safe** (`base64url`) 문자열
- **특징**:
  - URL이나 텍스트 전송에 안전한 Base64URL 포맷 사용 (패딩 `=` 제거 및 `+`➔`-`, `/`➔`_` 대체)
  - 솔로 레이드(Solo Raid) 5개 스쿼드 구성 데이터 전달

---

## 2. 덱 코드 포맷 (Decoded Payload Schema)

덱 코드를 디코딩하면 아래와 같은 JSON 객체 형태가 됩니다.

```json
{
  "type": "solo", 
  "squads": [
    ["red_hood", "crown", "liter", "naga", "modernia"], 
    ["dorothy", "blanc", "alice", "noir", "anis"], 
    [null, null, null, null, null], 
    [null, null, null, null, null], 
    [null, null, null, null, null]  
  ]
}
```

### 필드 상세 설명

| 필드명 | 타입 | 필수 여부 | 설명 |
| :--- | :--- | :--- | :--- |
| `type` | `string` | 필수 | 덱 종류 (항상 `"solo"`) |
| `squads` | `Array<Array<string\|null>>` | 필수 | 5개 스쿼드 x 5개 슬롯 배열 (총 25개 캐릭터 위치). 미배치 슬롯은 `null` |

---

## 3. 웹 JS/TS 디코딩 구현 예시 (TypeScript / JavaScript)

```javascript
/**
 * 미미르 덱 코드를 파싱하여 덱 데이터 객체로 변환합니다.
 * @param {string} code - Base64URL 덱 코드 문자열
 * @returns {{ type: string, squads: Array<Array<string|null>> } | null}
 */
function decodeMimirDeckCode(code) {
  try {
    if (!code || typeof code !== 'string') return null;
    
    // 1. Base64URL ➔ Standard Base64 문자열 변환
    let base64 = code.trim().replace(/-/g, '+').replace(/_/g, '/');
    while (base64.length % 4 !== 0) {
      base64 += '=';
    }
    
    // 2. UTF-8 디코딩
    const jsonString = decodeURIComponent(
      atob(base64)
        .split('')
        .map(c => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
        .join('')
    );
    
    // 3. JSON 파싱
    const decoded = JSON.parse(jsonString);
    
    // 4. 구조 검증
    if (typeof decoded !== 'object' || !decoded.squads) {
      return null;
    }
    
    return decoded;
  } catch (error) {
    console.error("미미르 덱 코드 파싱 실패:", error);
    return null;
  }
}

// ----------------------------------------------------
// 🧪 테스트 예시
// ----------------------------------------------------
const sampleCode = "eyJ0eXBlIjoic29sbyIsInNxdWFkcyI6W1sicmVkX2hvb2QiLCJjcm93biIsImxpdGVyIiwibmFnYSIsIm1vZGVybmlhIl0sW251bGwsbnVsbCxudWxsLG51bGwsbnVsbF0sW251bGwsbnVsbCxudWxsLG51bGwsbnVsbF0sW251bGwsbnVsbCxudWxsLG51bGwsbnVsbF0sW251bGwsbnVsbCxudWxsLG51bGwsbnVsbF1dfQ";

const deck = decodeMimirDeckCode(sampleCode);
console.log(deck);
/*
출력 예시:
{
  type: 'solo',
  squads: [
    ['red_hood', 'crown', 'liter', 'naga', 'modernia'],
    [null, null, null, null, null],
    [null, null, null, null, null],
    [null, null, null, null, null],
    [null, null, null, null, null]
  ]
}
*/
```

---

## 4. 미미르 니케 ID ➔ 캐릭터 이름 매핑표 (196개 니케 전체)

`squads` 배열 내부의 `nikke_id` 문자열을 타 사이트의 캐릭터 DB와 매핑할 때 아래 전체 목록을 사용하세요.

```json
{
  "2b": "2B",
  "a2": "A2",
  "ada": "에이다",
  "ade": "에이드",
  "ade_agent_bunny": "에이드 : 에이전트 바니",
  "admi": "애드미",
  "alice": "앨리스",
  "alice_wonderland_bunny": "앨리스 : 원더랜드 바니",
  "anchor": "앵커",
  "anchor_innocent_maid": "앵커 : 이노센트 메이드",
  "anis": "아니스",
  "anis_sparkling_summer": "아니스 : 스파클링 서머",
  "anne_miracle_fairy": "앤 : 미라클 페어리",
  "arcana": "아르카나",
  "aria": "아리아",
  "asuka": "아스카",
  "asuka_wille": "아스카 : WILLE",
  "bay": "베이",
  "belorta": "벨로타",
  "biscuit": "비스킷",
  "blanc": "블랑",
  "bready": "브래디",
  "brid": "브리드",
  "centi": "센티",
  "chime": "차임",
  "cinderella": "신데렐라",
  "claire": "클레어",
  "clay": "클레이",
  "cocoa": "코코아",
  "crow": "크로우",
  "crown": "크라운",
  "crust": "크러스트",
  "d": "D",
  "delta": "델타",
  "delta_ninja_thief": "델타 : 닌자 시프",
  "diesel": "디젤",
  "dolla": "도라",
  "dorothy": "도로시",
  "dorothy_serendipity": "도로시 : 세렌디피티",
  "drake": "드레이크",
  "d_killer_wife": "D : 킬러 와이프",
  "ein": "아인",
  "elegg": "일레그",
  "elegg_boom_and_shock": "일레그 : 붐 앤 쇼크",
  "emilia": "에밀리아",
  "emma": "엠마",
  "emma_tactical_upgrade": "엠마 : 택티컬 업",
  "epinel": "에피넬",
  "ether": "에테르",
  "eunhwa": "은화",
  "eunhwa_tactical_upgrade": "은화 : 택티컬 업",
  "eve": "이브",
  "exia": "엑시아",
  "flora": "플로라",
  "folkwang": "폴크방",
  "frima": "프림",
  "grave": "그레이브",
  "guilotine": "길로틴",
  "guilotine_winter_slayer": "길로틴 : 윈터 슬레이어",
  "guilty": "길티",
  "harran": "하란",
  "helm": "헬름",
  "helm_aquamarine": "헬름 : 아쿠아마린",
  "himeno": "히메노",
  "idollflower": "iDoll 플라워",
  "idollocean": "iDoll 오션",
  "idollsun": "iDoll 썬",
  "isabel": "이사벨",
  "jackal": "자칼",
  "jill": "질",
  "julia": "율리아",
  "k": "K",
  "kilo": "킬로",
  "laplace": "라플라스",
  "leona": "레오나",
  "liberalio": "리버렐리오",
  "lily": "릴리",
  "liter": "리타",
  "little_mermaid": "리틀 머메이드",
  "ludmilla": "루드밀라",
  "ludmilla_winter_owner": "루드밀라 : 윈터 오너",
  "maiden": "메이든",
  "maiden_ice_rose": "메이든 : 아이스 로즈",
  "makima": "마키마",
  "mana": "마나",
  "marciana": "마르차나",
  "mari": "마리",
  "mary": "메어리",
  "mary_bay_goddess": "메어리 : 베이 갓데스",
  "mast": "마스트",
  "mast_romantic_maid": "마스트 : 로망틱 메이드",
  "maxwell": "맥스웰",
  "mica": "미카",
  "mica_snow_buddy": "미카 : 스노우 버디",
  "mihara": "미하라",
  "mihara_bonding_chain": "미하라 : 본딩 체인",
  "milk": "밀크",
  "milk_blooming_bunny": "밀크 : 블루밍 바니",
  "miranda": "미란다",
  "misato": "미사토",
  "modernia": "모더니아",
  "moran": "목단",
  "mori": "모리",
  "n102": "N102",
  "naga": "나가",
  "nayuta": "나유타",
  "neon": "네온",
  "neon_blue_ocean": "네온 : 블루 오션",
  "nero": "네로",
  "neve": "네베",
  "nihilister": "니힐리스타",
  "noah": "노아",
  "noir": "누아르",
  "noise": "노이즈",
  "novel": "노벨",
  "pascal": "파스칼",
  "pepper": "페퍼",
  "phantom": "팬텀",
  "poli": "폴리",
  "power": "파워",
  "privaty": "프리바티",
  "privaty_unkind_maid": "프리바티 : 언카인드 메이드",
  "product08": "프로덕트 08",
  "product12": "프로덕트 12",
  "product23": "프로덕트 23",
  "quency": "퀀시",
  "quency_escape_queen": "퀀시 : 이스케이프 퀸",
  "quiry": "키리",
  "ram": "람",
  "rapi": "라피",
  "rapi_red_hood": "라피 : 레드 후드",
  "rapunzel": "라푼젤",
  "rapunzel_pure_grace": "라푼젤 : 퓨어 그레이스",
  "raven": "레이븐",
  "red_hood": "레드 후드",
  "rei(eva)": "레이",
  "rei": "라이",
  "rei_tentative_name": "레이 (가칭)",
  "rem": "렘",
  "rosanna": "로산나",
  "rosanna_chic_ocean": "로산나 : 시크 오션",
  "rouge": "루주",
  "rumani": "루마니",
  "rupee": "루피",
  "rupee_winter_shopper": "루피 : 윈터 쇼퍼",
  "sakura(eva)": "사쿠라",
  "sakura": "사쿠라",
  "sakura_bloom_in_summer": "사쿠라 : 블룸 인 서머",
  "scarlet": "홍련",
  "scarlet_black_shadow": "홍련 : 흑영",
  "signal": "시그널",
  "sin": "신",
  "snow_white": "스노우 화이트",
  "snow_white_innocent_days": "스노우 화이트 : 이노센트 데이즈",
  "soda": "소다",
  "soda_twinkling_buny": "소다 : 트윙클링 바니",
  "soldiereg": "솔져 E.G.",
  "soldierfa": "솔져 F.A.",
  "soldierow": "솔져 O.W.",
  "soline": "솔린",
  "soline_frost_ticket": "솔린 : 프로스트 티켓",
  "sora": "소라",
  "sugar": "슈가",
  "tia": "티아",
  "tove": "토브",
  "trina": "트리나",
  "trony": "트로니",
  "vesti": "베스티",
  "vesti_tactical_upgrade": "베스티 : 택티컬 업",
  "viper": "바이퍼",
  "volume": "볼륨",
  "yan": "얀",
  "yulha": "율하",
  "yuni": "유니",
  "zwei": "츠바이",
  "diesel_winter_sweets": "디젤 : 윈터 스위츠",
  "brid_silent_track": "브리드 : 사일런트 트랙",
  "snow_white_heavy_arms": "스노우 화이트 : 헤비암즈",
  "label": "레이블",
  "velvet": "벨벳",
  "chisato": "치사토",
  "takina": "타키나",
  "kurumi": "쿠루미",
  "eh": "E.H.",
  "arcana_fortune_mate": "아르카나 : 포츈 메이트",
  "snow_crane": "백학",
  "anis_star": "아니스 : 스타",
  "neon_vision_eye": "네온 : 비전아이",
  "mint": "민트",
  "prika": "프리카",
  "avista": "아비스타",
  "ark_ranger_black": "아크레인저 블랙",
  "cinderella_crystal_wave": "신데렐라 : 크리스탈 웨이브",
  "marciana_marine_study": "마르차나 : 마린 스터디",
  "laplace_ultimate_hero": "라플라스 : 얼티밋 히어로",
  "maxwell_ordinary_mechanic": "맥스웰 : 오디너리 미케닉"
}
```
