"""Select only unambiguous parties from public Enikk ranking snapshots.

Writes aggregated evidence, never player IDs. Does not activate production targets.
The source snapshots live under git-ignored scratch/score-roster-selection.
"""
from collections import Counter, defaultdict
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'scratch/score-roster-selection'
SEASONS = {'fire': 40, 'iron': 39, 'electric': 42, 'wind': 38, 'water': 41}
ELEMENT_NAMES = {'fire': '작열', 'iron': '철갑', 'electric': '전격', 'wind': '풍압', 'water': '수냉'}
RULE = {'minimumTopCount': 5, 'minimumTopShare': 0.5,
        'minimumTopToRunnerUpRatio': 2, 'requireUniqueSlotOrderMode': True}
REASONS = {'selected': '선정', 'existing': '기존 유지', 'no_usage': '사용 표본 없음',
           'low_sample': '사용 표본 부족', 'split': '조합 분산/경합',
           'order_tie': '최빈 배치 동률', 'unmapped_member': '동료 번호 확인 필요',
           'user_defined': '사용자 지정', 'incomplete': '사용자 지정 · 1명 미정'}


def load_overrides(data, profiles, local):
    """Reject stale targets, duplicate assignments and malformed manual parties."""
    targets = {p['key']: p for p in profiles}
    result = {}
    for group in data['groups']:
        team = group['team']
        known = [code for code in team if code is not None]
        if len(team) != 5 or len(known) not in (4, 5) or len(set(known)) != len(known):
            raise ValueError('Manual party needs five distinct slots (at most one blank)')
        if any(code not in local for code in known):
            raise ValueError('Unknown manual party member')
        for key in group['profiles']:
            if key not in targets or key in result or targets[key]['nameCode'] not in known:
                raise ValueError('Invalid, duplicate or missing manual target: ' + key)
            result[key] = list(team)
    return result


def aggregate(rows):
    counts, orders, servers, identities = Counter(), defaultdict(Counter), Counter(), set()
    for row in rows:
        identity = (row['server'], row['playerid'])
        if identity in identities:
            raise ValueError('Duplicate player in the ranking snapshot')
        identities.add(identity)
        servers[row['server']] += 1
        for team in row['teams']:
            members = team['characters']
            if len(members) != 5 or len(set(members)) != 5:
                raise ValueError('Invalid five-member party')
            key = tuple(sorted(members))
            # Each player's recorded squad is one use. The embedded count is not a weight.
            counts[key] += 1
            orders[key][tuple(members)] += 1
    return counts, orders, dict(servers)


def choose(counts, orders, target):
    candidates = sorted(((members, count) for members, count in counts.items() if target in members),
                        key=lambda item: (-item[1], item[0]))
    if not candidates:
        return {'status': 'no_usage', 'targetUses': 0, 'candidates': [], 'chosenOrder': None}
    total = sum(count for _, count in candidates)
    best, top = candidates[0]
    second = candidates[1][1] if len(candidates) > 1 else 0
    ordered = sorted(orders[best].items(), key=lambda item: (-item[1], item[0]))
    if top < RULE['minimumTopCount']:
        status = 'low_sample'
    elif top == second or top / total < RULE['minimumTopShare'] or top < second * RULE['minimumTopToRunnerUpRatio']:
        status = 'split'
    elif len(ordered) > 1 and ordered[0][1] == ordered[1][1]:
        status = 'order_tie'
    else:
        status = 'selected'
    return {'status': status, 'targetUses': total, 'topCount': top, 'runnerUpCount': second,
            'topShare': top / total,
            'orderCount': ordered[0][1],
            'orderRunnerUpCount': ordered[1][1] if len(ordered) > 1 else 0,
            'chosenOrder': list(ordered[0][0]) if status == 'selected' else None,
            'candidates': [{'members': list(members), 'count': count, 'share': count / total,
                            'modeOrders': [{'members': list(order), 'count': uses}
                                           for order, uses in sorted(orders[members].items(), key=lambda item: (-item[1], item[0]))[:3]]}
                           for members, count in candidates[:3]]}


def main():
    raw = (SOURCE / 'rankings.json').read_bytes()
    rankings = json.loads(raw)['data']
    catalog_bytes = (SOURCE / 'catalog.json').read_bytes()
    catalog = json.loads(catalog_bytes)['data']
    roster = json.loads((ROOT / 'services/nikke_score/collection_roster.json').read_text(encoding='utf-8'))
    local = {n['blablaNameCode']: n for n in json.loads((ROOT / 'assets/nikkes.json').read_text(encoding='utf-8-sig'))}
    overrides = load_overrides(json.loads((ROOT / 'services/nikke_score/collection_team_overrides.json').read_text(encoding='utf-8')),
                               roster['profiles'], local)
    name_to_codes = defaultdict(set)
    by_code = defaultdict(set)
    for c in catalog['characters']:
        name, code = c['name_localkey'], int(c['name_code'])
        name_to_codes[name].add(code)
        by_code[code].add(name)
    # Enikk uses "Rei" for two different characters. Never choose one silently.
    name_to_code = {name: next(iter(codes)) for name, codes in name_to_codes.items() if len(codes) == 1}
    summaries = {int(s['raid_number']): s for s in catalog['soloRaidSummaries']}
    analyses = {}
    for element, season in SEASONS.items():
        source_weakness = summaries[season]['weakness'].lower().replace('electronic', 'electric')
        assert source_weakness == element
        analyses[season] = aggregate(rankings[f's{season}'])
    legacy = {t['nameCode']: t for t in json.loads((ROOT / 'services/nikke_score/targets.json').read_text(encoding='utf-8'))}

    def local_name(name):
        code = name_to_code.get(name)
        return local[code]['name'] if code in local else name

    results = []
    for profile in roster['profiles']:
        code, element = profile['nameCode'], profile['weakness']
        entry = {key: profile[key] for key in ['key', 'nameCode', 'name', 'weakness']}
        if profile['key'] in overrides:
            slots = overrides[profile['key']]
            complete = None not in slots
            names = [local[c]['name'] if c is not None else '' for c in slots]
            entry.update(status='user_defined' if complete else 'incomplete', season=None,
                         team=slots if complete else None, teamNames=names if complete else None,
                         candidates=[], selectionSource='user')
            if not complete:
                entry.update(pendingSlots=slots, pendingSlotNames=names)
        elif profile['teamStatus'] == 'existing':
            entry.update(status='existing', season=legacy[code]['season'],
                         team=profile['team'], teamNames=profile['teamNames'], candidates=[])
        else:
            season = SEASONS[element]
            counts, orders, _ = analyses[season]
            names = by_code[code]
            # A name_code can have multiple rarity rows, but should have one roster name.
            present = names.intersection(name for members in counts for name in members)
            if len(present) > 1:
                raise ValueError('Multiple source aliases used for one target')
            name = next(iter(present or names))
            decision = choose(counts, orders, name)
            order = decision.pop('chosenOrder')
            team = [name_to_code.get(n) for n in order] if order else None
            if team and (None in team or any(n not in local for n in team)):
                decision['status'] = 'unmapped_member'
                decision['unresolvedMembers'] = [
                    {'sourceName': n, 'candidateCodes': sorted(name_to_codes[n]),
                     'candidateNames': [local[c]['name'] for c in sorted(name_to_codes[n]) if c in local]}
                    for n in order if name_to_code.get(n) not in local]
                order = team = None
            entry.update(decision, season=season, team=team,
                         teamNames=[local_name(n) for n in order] if order else None)
            for candidate in entry['candidates']:
                candidate['members'] = [local_name(n) for n in candidate['members']]
                for mode in candidate['modeOrders']:
                    mode['members'] = [local_name(n) for n in mode['members']]
        results.append(entry)
    sources = [{
        'season': season, 'weakness': element, 'url': f'https://enikk.app/soloraid/{season}',
        'players': sum(analyses[season][2].values()), 'servers': analyses[season][2],
        'squadUses': sum(analyses[season][0].values()),
        'lastUpdatedAt': (summaries[season].get('data') or {}).get('lastupdated'),
    } for element, season in SEASONS.items()]
    output = {
        'schemaVersion': 1, 'selectionDateKst': '2026-11-02',
        'status': 'teams_complete' if all(r['team'] is not None for r in results) else 'awaiting_manual_teams',
        'policy': RULE, 'sampling': 'Six servers, top 50 players per server; one recorded squad is one use.',
        'existingPolicy': 'Preserve baseline parties unless explicitly overridden; Diesel slot order corrected on 2026-11-03.',
        'source': {'provider': 'enikk', 'endpoint': 'https://enikk.app/api/graphql',
                   'capturedAt': datetime.fromtimestamp((SOURCE / 'rankings.json').stat().st_mtime, timezone.utc).isoformat(),
                   'rankingsSha256': hashlib.sha256(raw).hexdigest(),
                   'catalogSha256': hashlib.sha256(catalog_bytes).hexdigest(),
                   'season43Players': len(rankings['s43']), 'seasons': sources},
        'profiles': results,
    }
    (ROOT / 'services/nikke_score/collection_team_selection.json').write_text(
        json.dumps(output, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    selected = [r for r in results if r['status'] == 'selected']
    user_defined = [r for r in results if r['status'] == 'user_defined']
    manual = [r for r in results if r['team'] is None]
    existing_count = sum(r['status'] == 'existing' for r in results)
    doc = ['# 미미르 스코어 편성 선정표 (2026-11-03)', '',
           f'기존 유지 {existing_count}개 · 신규 자동 선정 {len(selected)}개 · 사용자 지정 완료 {len(user_defined)}개 · 미완성 {len(manual)}개.', '',
           '레이(5119)를 작열 평가에 추가하고 마나는 제외했다. 사용자 지정 편성은 자동 선정 결과보다 우선하며, 재생성해도 유지된다. 레이(5119)와 레이 (가칭)(5132)은 별개 대상이다.', '',
           '2026-11-03 추가 확정: 나유타와 리틀 머메이드는 풍압에서 나유타 · 신데렐라 : 크리스탈 웨이브 · 리틀 머메이드 · 프리바티 · 벨벳 순서로 측정한다.', '',
           '2026-11-03: 기본 로산나(전격)는 최다 사용 조합으로, 리틀 머메이드(풍압)는 사용자 확인 편성으로 추가했다. 디젤은 동일 멤버와 더미 육성을 유지하며 스노우 화이트 : 헤비암즈와 3·4번 자리를 교환했다. API 비교에서 디젤의 합성 기준 딜량이 3.27억에서 9.58억으로 증가했다.', '',
           ('아래 빈칸은 사용자가 직접 지정할 편성이다.' if manual else f'{len(results)}개 평가 항목의 편성 선정이 모두 완료되었다.')
           + ' 표의 1~5번은 왼쪽부터 실제 배치 순서다. 이 문서는 편성 설정이며 운영 계산·수집 적용은 별도다.', '',
           '## 집계 기준', '',
           '- 자동 선정 대상은 해당 약점 속성에서 공개 순위가 있는 최근 시즌으로 집계했다. 기존 편성은 보존하되 디젤의 3·4번 순서 수정과 사용자 지정 편성을 우선한다.',
           '- 서버별 상위 50명씩 총 300명의 1,500개 기록 편성을 집계했다. 전체 이용자 사용률을 뜻하지 않는다.',
           '- 5인 멤버가 같으면 배치 순서와 무관하게 한 조합으로 묶는다. 선정 후 그 조합의 최빈 배치 순서를 사용한다.',
           '- 분산 판단은 보수적으로 정했다: 1위 5건 이상, 대상 포함 편성 중 50% 이상, 2위의 2배 이상을 모두 만족해야 자동 선정한다.',
           '- 최빈 배치가 동률인 경우도 빈칸으로 남긴다. 낮은 표본을 임의의 조합으로 보완하지 않는다.',
           '- 표의 건수는 **1위 / 2위 / 대상 포함 전체 편성** 순서다. 빈칸 사유와 후보는 하단에 기록했다.', '',
           '| 속성 | 시즌 | 표본 | 출처 |', '| --- | ---: | --- | --- |']
    for source in sources:
        doc.append(f"| {ELEMENT_NAMES[source['weakness']]} | S{source['season']} | 300명 / 1,500편성 | [Enikk S{source['season']}]({source['url']}) |")
    doc += ['', 'S43(작열)은 순위 0건이어서 사용하지 않았다. 출시 이후 해당 속성 레이드 기록이 없는 니케는 과거 시즌의 다른 니케로 대체하지 않는다.', '']
    for element, label in ELEMENT_NAMES.items():
        doc += [f'## {label}', '', '| 대상 | 시즌·건수 | 1번 | 2번 | 3번 | 4번 | 5번 | 상태 |',
                '| --- | --- | --- | --- | --- | --- | --- | --- |']
        for r in results:
            if r['weakness'] != element:
                continue
            stat = f"S{r['season']}" if r['season'] is not None else '사용자 지정'
            if 'targetUses' in r:
                stat += f" · {r.get('topCount', 0)}/{r.get('runnerUpCount', 0)}/{r['targetUses']}"
            columns = r['teamNames'] or r.get('pendingSlotNames') or [''] * 5
            doc.append('| ' + ' | '.join([r['name'], stat, *columns, REASONS[r['status']]]) + ' |')
        doc.append('')
    if manual:
        doc += ['## 빈칸 항목의 근거와 후보', '', '후보 목록은 검토용이다. 빈칸에 자동 적용한 값이 아니다.', '']
    for r in manual:
        if r['status'] == 'incomplete':
            doc += [f"### {r['name']} · {ELEMENT_NAMES[r['weakness']]}", '',
                    '사용자가 지정한 4명의 순서는 보존했다. 남은 1명과 배치 위치 확인 전까지 실행 가능한 편성은 비워 둔다.',
                    ' → '.join(n for n in r['pendingSlotNames'] if n) + ' → (1명 미정)', '']
            continue
        doc += [f"### {r['name']} · {ELEMENT_NAMES[r['weakness']]} · S{r['season']}", '',
                f"사유: {REASONS[r['status']]} · 대상 사용 {r['targetUses']}건.", '']
        for member in r.get('unresolvedMembers', []):
            doc.append(f"- 원본 이름 `{member['sourceName']}`이 {' / '.join(member['candidateNames'])}에 중복된다. 순위 원본에는 구분할 캐릭터 번호가 없어 임의로 지정하지 않았다.")
        for i, candidate in enumerate(r['candidates'], 1):
            mode = candidate['modeOrders'][0]
            doc.append(f"- 후보 {i}: {' → '.join(mode['members'])} — {candidate['count']}건 ({candidate['share']:.1%}), 해당 배치 {mode['count']}건")
        if not r['candidates']:
            doc.append('- 해당 시즌 표본에 사용 기록이 없다.')
        doc.append('')
    doc += ['## 재현 자료', '',
            '- 집계 결과: `services/nikke_score/collection_team_selection.json`',
            '- 집계 코드: `tools/select_score_collection_teams.py`',
            '- 사용자 지정 원본: `services/nikke_score/collection_team_overrides.json`',
            '- 원본 순위는 계정 식별자를 포함하므로 git 제외 경로 `scratch/score-roster-selection`에만 보관했다.',
            f"- 원본 순위 SHA-256: `{output['source']['rankingsSha256']}`", '',
            '편성 지정 시 대상 니케와 평가 속성, 배치 순서대로 5명을 알려주면 된다.', '']
    (ROOT / 'docs/mimir-score-team-selection.md').write_text('\n'.join(doc), encoding='utf-8')
    print(json.dumps({'existing': existing_count, 'selected': len(selected), 'userDefined': len(user_defined), 'manual': len(manual),
                      'reasons': dict(Counter(r['status'] for r in results))}))


if __name__ == '__main__':
    main()
