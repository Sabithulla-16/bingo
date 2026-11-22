import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/features/multiplayer/domain/quick_match.dart';

void main() {
  group('Quick Match Domain Models Tests', () {
    test('MatchmakingQueueStatus enum parsing and db strings', () {
      expect(
        MatchmakingQueueStatus.fromString('SEARCHING'),
        equals(MatchmakingQueueStatus.searching),
      );
      expect(
        MatchmakingQueueStatus.fromString('MATCHED'),
        equals(MatchmakingQueueStatus.matched),
      );
      expect(
        MatchmakingQueueStatus.fromString('CANCELLED'),
        equals(MatchmakingQueueStatus.cancelled),
      );
      expect(
        MatchmakingQueueStatus.fromString('EXPIRED'),
        equals(MatchmakingQueueStatus.expired),
      );
      expect(
        MatchmakingQueueStatus.fromString('IDLE'),
        equals(MatchmakingQueueStatus.idle),
      );
      expect(
        MatchmakingQueueStatus.fromString(null),
        equals(MatchmakingQueueStatus.idle),
      );

      expect(MatchmakingQueueStatus.searching.toDbString(), equals('SEARCHING'));
      expect(MatchmakingQueueStatus.matched.toDbString(), equals('MATCHED'));
      expect(MatchmakingQueueStatus.cancelled.toDbString(), equals('CANCELLED'));
      expect(MatchmakingQueueStatus.expired.toDbString(), equals('EXPIRED'));
      expect(MatchmakingQueueStatus.idle.toDbString(), equals('IDLE'));
    });

    test('QuickMatchStatus enum parsing and db strings', () {
      expect(
        QuickMatchStatus.fromString('COUNTDOWN'),
        equals(QuickMatchStatus.countdown),
      );
      expect(
        QuickMatchStatus.fromString('BOARD_PREPARATION'),
        equals(QuickMatchStatus.boardPreparation),
      );
      expect(
        QuickMatchStatus.fromString('PREPARING'),
        equals(QuickMatchStatus.boardPreparation),
      );
      expect(
        QuickMatchStatus.fromString('IN_PROGRESS'),
        equals(QuickMatchStatus.inProgress),
      );
      expect(
        QuickMatchStatus.fromString('PLAYING'),
        equals(QuickMatchStatus.inProgress),
      );
      expect(
        QuickMatchStatus.fromString('COMPLETED'),
        equals(QuickMatchStatus.completed),
      );
      expect(
        QuickMatchStatus.fromString('CANCELLED'),
        equals(QuickMatchStatus.cancelled),
      );
      expect(
        QuickMatchStatus.fromString('FORFEITED'),
        equals(QuickMatchStatus.forfeited),
      );

      expect(QuickMatchStatus.countdown.toDbString(), equals('COUNTDOWN'));
      expect(QuickMatchStatus.boardPreparation.toDbString(), equals('BOARD_PREPARATION'));
      expect(QuickMatchStatus.inProgress.toDbString(), equals('IN_PROGRESS'));
      expect(QuickMatchStatus.completed.toDbString(), equals('COMPLETED'));
      expect(QuickMatchStatus.cancelled.toDbString(), equals('CANCELLED'));
      expect(QuickMatchStatus.forfeited.toDbString(), equals('FORFEITED'));
    });

    test('MatchmakingQueueEntry parsing from JSON', () {
      final now = DateTime.now();
      final json = {
        'id': 'q_123',
        'user_id': 'u_456',
        'status': 'SEARCHING',
        'queued_at': now.toIso8601String(),
        'region': 'us-east',
      };

      final entry = MatchmakingQueueEntry.fromJson(json);
      expect(entry.id, equals('q_123'));
      expect(entry.userId, equals('u_456'));
      expect(entry.status, equals(MatchmakingQueueStatus.searching));
      expect(entry.region, equals('us-east'));
      expect(entry.matchId, isNull);
    });

    test('QuickMatchOpponent parsing and serialization', () {
      final opp = QuickMatchOpponent.fromJson({
        'id': 'u_opp',
        'display_name': 'Maya',
        'avatar_color_hex': '#FF6B5E',
      });

      expect(opp.id, equals('u_opp'));
      expect(opp.displayName, equals('Maya'));
      expect(opp.avatarColorHex, equals('#FF6B5E'));

      final json = opp.toJson();
      expect(json['id'], equals('u_opp'));
      expect(json['display_name'], equals('Maya'));
    });

    test('QuickMatch parsing with currentUserId opponent derivation', () {
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      final json = {
        'match_id': 'm_789',
        'room_id': 'r_123',
        'room_code': 'ABCDEF',
        'game_id': 'g_456',
        'player1_id': 'u_player1',
        'player2_id': 'u_player2',
        'status': 'COUNTDOWN',
        'countdown_deadline': deadline.toIso8601String(),
        'player1': {
          'id': 'u_player1',
          'display_name': 'Player One',
          'avatar_color_hex': '#20243A',
        },
        'player2': {
          'id': 'u_player2',
          'display_name': 'Player Two',
          'avatar_color_hex': '#FC695C',
        },
      };

      // When caller is player1, opponent should be player2
      final qmForP1 = QuickMatch.fromJson(json, currentUserId: 'u_player1');
      expect(qmForP1.id, equals('m_789'));
      expect(qmForP1.status, equals(QuickMatchStatus.countdown));
      expect(qmForP1.opponent, isNotNull);
      expect(qmForP1.opponent!.id, equals('u_player2'));
      expect(qmForP1.opponent!.displayName, equals('Player Two'));

      // When caller is player2, opponent should be player1
      final qmForP2 = QuickMatch.fromJson(json, currentUserId: 'u_player2');
      expect(qmForP2.opponent, isNotNull);
      expect(qmForP2.opponent!.id, equals('u_player1'));
      expect(qmForP2.opponent!.displayName, equals('Player One'));
    });
  });
}
