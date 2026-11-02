"""Record the user's requested scoring roster, without activating unassigned teams."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GROUPS = [
    ('fire', '작열', [5185, 5186, 5129, 5138, 5159, 5180, 5179, 5024, 5167, 5004, 5044, 5119]),
    ('iron', '철갑', [5175, 5129, 5143, 5142, 5002, 5176, 5113, 5150, 5101, 5164, 1010, 5012, 5001]),
    ('electric', '전격', [5124, 5170, 5152, 5127, 5097, 5013, 5077, 5169, 1021, 5045]),
    ('wind', '풍압', [5105, 5156, 5133, 5177, 5181, 5174, 5132, 5117, 5137]),
    ('water', '수냉', [5161, 5145, 5007, 5146, 5002, 5122, 5158, 5135, 5103, 5066, 5182, 5183]),
]


def main():
    nikkes = json.loads((ROOT / 'assets/nikkes.json').read_text(encoding='utf-8-sig'))
    by_code = {n['blablaNameCode']: n for n in nikkes}
    elements = json.loads((ROOT / 'functions/nikkeElements.json').read_text(encoding='utf-8-sig'))
    # The baseline is the original 14 contexts, not the expanding runtime list.
    # Otherwise regeneration would relabel manual parties as legacy standards.
    existing = []
    source = ROOT / 'services/nikke_score'
    compact_names = {n['name'].replace(' ', ''): n['blablaNameCode'] for n in nikkes}
    for target in json.loads((source / 'targets.json').read_text(encoding='utf-8')):
        context = json.loads((source / 'contexts' / (target['version'] + '.json')).read_text(encoding='utf-8'))
        names = context['request']['squad']
        existing.append({'nameCode': target['nameCode'], 'weakness': target['element'].lower(),
                         'team': [compact_names[name.replace(' ', '')] for name in names], 'teamNames': names})
    by_profile = {(t['nameCode'], t['weakness']): t for t in existing}
    rows = []
    for weakness, _, codes in GROUPS:
        for code in codes:
            nikke = by_code[code]
            assert weakness in [e.lower() for e in elements[str(code)]], (code, weakness)
            team = by_profile.get((code, weakness))
            rows.append({
                'key': f'{code}:{weakness}', 'nameCode': code,
                'name': nikke['name'], 'weakness': weakness,
                'teamStatus': 'existing' if team else 'needs_selection',
                'team': team['team'] if team else None,
                'teamNames': team['teamNames'] if team else None,
            })
    assert len(rows) == len({r['key'] for r in rows}) == 56
    assert len({r['nameCode'] for r in rows}) == 54
    existing_count = sum(r['teamStatus'] == 'existing' for r in rows)
    selection_path = ROOT / 'services/nikke_score/collection_team_selection.json'
    selection = json.loads(selection_path.read_text(encoding='utf-8')) if selection_path.exists() else None
    selected_by_key = {r['key']: r for r in selection['profiles']} if selection else {}
    roster = {
        'schemaVersion': 1, 'requestedAtKst': '2026-11-02',
        'status': 'planning',
        'note': 'Requested roster only. New teams and element-specific runtime storage must be configured before activation.',
        'confirmedNameCorrection': {'requested': '네온 : 헤비암즈', 'nameCode': 5170, 'name': by_code[5170]['name']},
        'profiles': rows,
    }
    (ROOT / 'services/nikke_score/collection_roster.json').write_text(
        json.dumps(roster, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

    doc = [
        '# 미미르 스코어 수집 대상 확장 (2026-11-02)', '',
        '사용자가 지정한 54종 · 속성별 56개 평가 항목이다. 네온은 사용자 확인에 따라 네온 : 비전아이(5170)로 정정했다. 2026-11-03 기본 로산나(5045)와 리틀 머메이드(5137)를 추가했다.', '',
        f'기존 편성이 있는 항목 {existing_count}개, 신규 선정 대상 {len(rows) - existing_count}개.',
        '신규 편성의 선정 결과·빈칸·후보는 [편성 선정표](mimir-score-team-selection.md)와 `collection_team_selection.json`에서 관리한다. 이 명세의 `needs_selection`은 신규 대상 구분이며 선정 결과를 덮어쓰지 않는다.',
        '이 문서와 collection_roster.json은 수집 대상 명세다. 확정한 collection_team_selection.json을 build_partner_score_targets.py가 읽어 56개 운영용 계산·수집 설정을 생성한다.', '',
        '## 평가 구분', '',
        '- 라피 : 레드 후드(5129)는 작열과 철갑을 별도 평가한다.',
        '- 슈가(5002)는 철갑과 수냉을 별도 평가한다.',
        '- 사용자 지정으로 레이(5119)를 작열 평가에 추가하고 마나(1019)는 수집 대상에서 제외했다.',
        '- 점수·순위·캐시·화면 결과는 니케 번호와 평가 속성을 함께 식별자로 사용해야 한다.',
        '- 각 항목의 보스 weakness는 아래 분류의 속성으로 설정한다. 이중 속성 니케의 기본 속성만 보고 덮어쓰지 않는다.',
        '- 나유타는 수집 대상에 없다. 다른 대상의 더미 니케로 사용되는 편성은 유지한다. 리틀 머메이드는 사용자 요청으로 풍압 측정에 추가했다.',
        '- 대상만 실제 육성, 더미 4명은 고정 육성, 사용자 연구실 공통 적용, 개인 딜 × 5 ÷ 1억 기준을 유지한다.', '',
    ]
    for weakness, label, codes in GROUPS:
        doc += [f'## {label} ({len(codes)}개)', '', '| 니케 | name_code | 편성 상태 |', '| --- | ---: | --- |']
        for row in rows:
            if row['weakness'] == weakness:
                status = '기존 편성 있음' if row['teamStatus'] == 'existing' else '선정 필요'
                decision = selected_by_key.get(row['key'])
                if decision and row['teamStatus'] != 'existing':
                    status = {'selected': '최다 사용 조합 선정', 'user_defined': '사용자 지정 완료',
                              'incomplete': '사용자 지정 · 1명 미정'}.get(decision['status'], '빈칸 · 사용자 지정 대기')
                doc.append(f"| {row['name']} | {row['nameCode']} | {status} |")
        doc.append('')
    doc += [
        '## 적용에 필요한 후속 작업', '',
        ('1. 56개 평가 항목의 편성 선정 완료. 라피 철갑과 작열은 별도 편성으로 유지한다.'
         if selection and selection['status'] == 'teams_complete'
         else '1. 편성 선정표의 빈칸을 사용자 지정 조합으로 채운다. 라피 철갑은 작열 편성을 자동 복사하지 않고 별도로 선정한다.'),
        '2. 더미 스펙 생성 후 새 항목의 실제 API 지원을 검증한다.',
        '3. 요청·캐시·분포·화면 상태를 name_code + weakness 단위로 분리했다.',
        '4. 편성을 변경할 때 생성기를 실행하고 계산·수집 서버와 프런트엔드를 함께 반영한다.', '',
        '재생성: `python tools/build_score_collection_roster.py`', '',
    ]
    (ROOT / 'docs/mimir-score-collection-roster.md').write_text('\n'.join(doc), encoding='utf-8')
    print(json.dumps({'profiles': len(rows), 'uniqueNikkes': len({r['nameCode'] for r in rows}),
                      'existingTeams': existing_count, 'teamsToSelect': len(rows) - existing_count}))


if __name__ == '__main__':
    main()
