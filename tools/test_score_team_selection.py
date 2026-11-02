"""Validate ranking aggregation and conservative selection boundaries."""
from collections import Counter
import unittest

from select_score_collection_teams import aggregate, choose, load_overrides


class SelectionTests(unittest.TestCase):
    def test_manual_slots_preserved_including_pending_member(self):
        profiles = [{'key': '1:fire', 'nameCode': 1}, {'key': '2:fire', 'nameCode': 2}]
        data = {'groups': [{'profiles': ['1:fire', '2:fire'], 'team': [3, 1, 2, 4, None]}]}
        result = load_overrides(data, profiles, {i: {} for i in range(1, 6)})
        self.assertEqual(result['1:fire'], [3, 1, 2, 4, None])
        self.assertEqual(result['2:fire'], result['1:fire'])

    def test_invalid_manual_party_or_target_rejected(self):
        profiles = [{'key': '1:fire', 'nameCode': 1}]
        local = {i: {} for i in range(1, 7)}
        for keys, team in [(['1:fire'], [2, 3, 4, 5, 6]),
                           (['1:fire'], [1, 1, 2, 3, 4]),
                           (['1:fire'], [1, 2, 3, 4, 999]),
                           (['1:fire'], [1, 2, 3, None, None]),
                           (['1:fire', '1:fire'], [1, 2, 3, 4, 5]),
                           (['1:water'], [1, 2, 3, 4, 5])]:
            with self.subTest(keys=keys, team=team), self.assertRaises(ValueError):
                load_overrides({'groups': [{'profiles': keys, 'team': team}]}, profiles, local)

    def decision(self, frequencies):
        counts, orders = Counter(), {}
        for members, count in frequencies:
            key = tuple(sorted(members))
            counts[key] += count
            orders.setdefault(key, Counter())[tuple(members)] += count
        return choose(counts, orders, 'target')

    def test_aggregation_ignores_embedded_count_and_groups_order(self):
        first = ['target', 'a', 'b', 'c', 'd']
        rows = [{'server': 'KR', 'playerid': str(i),
                 'teams': [{'characters': members, 'count': 999}]}
                for i, members in enumerate([first, first[::-1]])]
        counts, orders, servers = aggregate(rows)
        self.assertEqual(list(counts.values()), [2])
        self.assertEqual(len(next(iter(orders.values()))), 2)
        self.assertEqual(servers, {'KR': 2})

    def test_duplicate_player_rejected(self):
        row = {'server': 'KR', 'playerid': '1', 'teams': []}
        with self.assertRaises(ValueError):
            aggregate([row, row])
        self.assertEqual(aggregate([row, {**row, 'server': 'JP'}])[2], {'KR': 1, 'JP': 1})

    def test_invalid_party_rejected(self):
        for members in [['target'] * 5, ['a', 'b', 'c', 'd']]:
            with self.assertRaises(ValueError):
                aggregate([{'server': 'KR', 'playerid': '1', 'teams': [{'characters': members}]}])

    def test_no_usage_and_small_sample(self):
        self.assertEqual(self.decision([])['status'], 'no_usage')
        self.assertEqual(self.decision([(('target', 'a', 'b', 'c', 'd'), 4)])['status'], 'low_sample')

    def test_clear_winner_preserves_slot_order(self):
        order = ('b', 'target', 'a', 'c', 'd')
        decision = self.decision([(order, 10), (('target', 'a', 'b', 'c', 'e'), 5)])
        self.assertEqual(decision['status'], 'selected')
        self.assertEqual(decision['chosenOrder'], list(order))
        self.assertEqual(decision['targetUses'], 15)

    def test_tie_and_close_runner_up_remain_blank(self):
        for runner_up in [10, 6]:
            decision = self.decision([(('target', 'a', 'b', 'c', 'd'), 10),
                                      (('target', 'a', 'b', 'c', 'e'), runner_up)])
            self.assertEqual(decision['status'], 'split')
            self.assertIsNone(decision['chosenOrder'])

    def test_below_half_remains_blank(self):
        parties = [(('target', 'a', 'b', 'c', str(i)), n) for i, n in enumerate([10, 5, 4, 3])]
        self.assertEqual(self.decision(parties)['status'], 'split')

    def test_order_tie_remains_blank(self):
        order = ('target', 'a', 'b', 'c', 'd')
        decision = self.decision([(order, 5), (order[::-1], 5)])
        self.assertEqual(decision['status'], 'order_tie')
        self.assertIsNone(decision['chosenOrder'])


if __name__ == '__main__':
    unittest.main()
