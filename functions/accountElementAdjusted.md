# 속성별 보정점수

`accountElementAdjusted.js`의 formulaVersion 1은 보유자 평균 우월% × 보유자 평균 줄 수 × 채택률 계수 × 0.01을 니케 가중치로 사용한다. 채택률 계수는 10% 이상 1, 5% 이상 0.5, 3% 이상 0.2, 그 미만 0.1이다. 저장 대상 상위 5개 옵션에 elementDamage가 없으면 사용자 결정에 따라 0이다.

`nikkeStatisticsStore.js`는 기존 조회에서 계정별 [nameCode, 우월%] 숫자 쌍만 임시 보관한다. 니케별 통계가 확정된 다음 보정점수를 집계하므로 전체 계정 재조회가 없다. 가중치와 기여도는 중간 반올림하지 않으며 속성 합계와 히스토그램은 기존 총합처럼 소수 두 자리로 정리한다. 0점 계정도 평균·분포에 포함한다.

`nikke_statistics/account_element_adjusted`에 weights, formulaVersion, sampleCount, elements(key/adjustedAverage/histogram), generatedAt/cachedAt을 저장한다. 기존 account_element_damage는 그대로 유지한다. 별도 문서로 분리해 기존 문서에 히스토그램 두 세트를 넣지 않는다.

조회 API는 보정 캐시 문서 1개를 추가로 읽고 현재 계정에 그 캐시의 가중치를 적용한다. 기존 캐시와 표본 수·생성 시각이 일치할 때만 adjustedScore/adjustedAverage/adjustedTopPercent를 반환한다. 히스토그램과 가중치는 응답에 포함하지 않는다. 옛 캐시와 구 서버 응답에서는 새 필드가 없으므로 UI가 갱신 대기를 표시한다.

`my_nikke_screen.dart`는 기본 raw enum 상태로 시작하고 같은 카드를 전환한다. 보정점수에는 +/%를 붙이지 않으며 순위 %와 막대의 (100 - topPercent)/100 정의는 유지한다. 모델에 nullable 보정 필드를 추가했다. achievementBadges.js의 기존 topPercent <= 4 판정과 recap 로직은 변경하지 않았다.

운영 반영에는 변경된 Functions(계정 통계 조회, 일일 통계 생성, 관리자 수동 갱신)와 Flutter 앱 배포가 필요하다. 서버 배포 후 기존 관리자 통계 갱신 또는 다음 한국 시간 00:00 일일 갱신으로 보정 캐시가 만들어진다. 이번 로컬 구현 작업에서는 배포나 운영 DB 갱신을 실행하지 않았다.
