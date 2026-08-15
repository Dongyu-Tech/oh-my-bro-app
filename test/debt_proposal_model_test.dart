import 'package:flutter_test/flutter_test.dart';

import 'package:heymybro/core/error/result.dart';
import 'package:heymybro/shared/debt/debt_actions.dart';
import 'package:heymybro/shared/models/debt_proposal_model.dart';
import 'package:heymybro/shared/repositories/debt_repository.dart';

void main() {
  // reportDebtOutcome reaches for the global ScaffoldMessenger key, and
  // GlobalKey.currentState needs a binding even when there is no messenger to
  // find.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses a my_debt_proposals row', () {
    final model = DebtProposalModel.fromJson({
      'id': 'p1',
      'proposer_id': 'me',
      'counterparty_id': 'them',
      'debtor_id': 'them',
      'title': '晚餐',
      'amount': 400,
      'original_amount': 500,
      'status': 'pending',
      'awaiting_id': 'me',
      'round': 1,
      'reject_reason': null,
      'created_at': '2026-08-15T00:00:00Z',
      'updated_at': '2026-08-15T01:00:00Z',
      'resolved_at': null,
      'other_id': 'them',
      'other_handle': 'ahua',
      'other_display_name': '阿華',
      'other_avatar_url': null,
    });

    expect(model.amount, 400);
    expect(model.originalAmount, 500, reason: 'so the card can show "was 500"');
    expect(model.isMyTurn('me'), isTrue);
    expect(model.isMyTurn('them'), isFalse);
    expect(model.iOwe('me'), isFalse);
    expect(model.bestOtherName, '阿華');
  });

  test('falls back to the handle when the display name is blank', () {
    final model = DebtProposalModel.fromJson({
      'id': 'p1',
      'proposer_id': 'me',
      'counterparty_id': 'them',
      'debtor_id': 'me',
      'title': '車錢',
      'amount': null,
      'original_amount': null,
      'status': 'rejected',
      'awaiting_id': null,
      'round': 0,
      'reject_reason': '那頓我付的',
      'created_at': '2026-08-15T00:00:00Z',
      'updated_at': '2026-08-15T00:00:00Z',
      'resolved_at': '2026-08-15T00:00:00Z',
      'other_id': 'them',
      'other_handle': 'ahua',
      'other_display_name': '   ',
      'other_avatar_url': null,
    });

    expect(model.bestOtherName, 'ahua');
    expect(model.isDeadEnd, isTrue);
    expect(model.isPending, isFalse);
    expect(model.iOwe('me'), isTrue);
    expect(model.rejectReason, '那頓我付的');
  });

  test('a blank amount survives the round trip as null, not zero', () {
    final model = DebtProposalModel.fromJson({
      'id': 'p1',
      'proposer_id': 'me',
      'counterparty_id': 'them',
      'debtor_id': 'them',
      'title': '待填',
      'amount': null,
      'status': 'pending',
      'awaiting_id': 'them',
      'created_at': '2026-08-15T00:00:00Z',
      'updated_at': '2026-08-15T00:00:00Z',
    });

    expect(model.amount, isNull);
    expect(model.round, 0, reason: 'defaults when the server omits it');
  });

  group('DebtOutcome', () {
    test('stale counts as success — the end state already holds', () {
      expect(DebtOutcome.parse('stale'), DebtOutcome.stale);
      expect(DebtOutcome.stale.isSuccess, isTrue);
      expect(DebtOutcome.ok.isSuccess, isTrue);
    });

    test('an unknown wire value degrades instead of throwing', () {
      expect(
        DebtOutcome.parse('something_the_server_added'),
        DebtOutcome.unknown,
      );
      expect(DebtOutcome.parse(null), DebtOutcome.unknown);
      expect(DebtOutcome.unknown.isSuccess, isFalse);
    });

    test('maps every failure code the RPCs can return', () {
      expect(DebtOutcome.parse('not_yours'), DebtOutcome.notYours);
      expect(DebtOutcome.parse('not_found'), DebtOutcome.notFound);
      expect(DebtOutcome.parse('not_friends'), DebtOutcome.notFriends);
      expect(DebtOutcome.parse('no_amount'), DebtOutcome.noAmount);
      expect(DebtOutcome.parse('round_exhausted'), DebtOutcome.roundExhausted);
      expect(DebtOutcome.parse('self'), DebtOutcome.self);
      expect(DebtOutcome.parse('bad_amount'), DebtOutcome.badInput);
      expect(DebtOutcome.parse('bad_title'), DebtOutcome.badInput);
      expect(DebtOutcome.parse('bad_debtor'), DebtOutcome.badInput);
      expect(DebtOutcome.parse('bad_action'), DebtOutcome.badInput);
    });

    test('every outcome is reported, and only success reports success', () {
      // The UI collapses most failures into one sentence, so a value that
      // slipped through unhandled would look exactly like one that is
      // handled. This walks the whole enum instead.
      for (final outcome in DebtOutcome.values) {
        expect(
          reportDebtOutcome(Result.ok(outcome)),
          outcome.isSuccess,
          reason: '$outcome must not be mistaken for the opposite',
        );
      }
      expect(reportDebtOutcome(Result.error(Exception('boom'))), isFalse);
    });

    test('every failure code is a failure', () {
      for (final outcome in DebtOutcome.values) {
        if (outcome == DebtOutcome.ok || outcome == DebtOutcome.stale) continue;
        expect(outcome.isSuccess, isFalse, reason: '$outcome must not pass');
      }
    });
  });
}
