import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/features/authentication/domain/auth_repository.dart';
import 'package:bingo/features/authentication/domain/auth_state.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_provider.dart';
import 'package:bingo/features/multiplayer/domain/quick_match.dart';
import 'package:bingo/features/multiplayer/domain/quick_match_rematch.dart';
import 'package:bingo/features/multiplayer/domain/room.dart';
import 'package:bingo/features/multiplayer/quick_match/quick_match_result_screen.dart';
import 'package:bingo/data/supabase/supabase_provider.dart';

class MockMultiplayerRepository implements MultiplayerRepository {
  QuickMatchResultData? resultDataToReturn;
  QuickMatchRematchRequest? pendingRematchToReturn;
  Map<String, dynamic>? rematchResponse;
  bool requestRematchCalled = false;
  bool cancelRematchCalled = false;
  bool respondRematchCalled = false;
  bool? respondAcceptParam;

  @override
  Future<QuickMatchResultData?> getQuickMatchResult(String matchId) async {
    return resultDataToReturn;
  }

  @override
  Future<QuickMatchRematchRequest?> getPendingRematchRequest({String? matchId}) async {
    return pendingRematchToReturn;
  }

  @override
  Future<Map<String, dynamic>> requestQuickMatchRematch(String previousMatchId) async {
    requestRematchCalled = true;
    return rematchResponse ?? {
      'success': true,
      'request_id': 'req-123',
      'status': 'PENDING',
      'expires_at': DateTime.now().add(const Duration(seconds: 30)).toIso8601String(),
      'is_requester': true,
    };
  }

  @override
  Future<Map<String, dynamic>> respondQuickMatchRematch(String requestId, bool accept) async {
    respondRematchCalled = true;
    respondAcceptParam = accept;
    return {'success': true, 'status': accept ? 'ACCEPTED' : 'DECLINED'};
  }

  @override
  Future<Map<String, dynamic>> cancelQuickMatchRematch(String requestId) async {
    cancelRematchCalled = true;
    return {'success': true, 'status': 'CANCELLED'};
  }

  @override
  Stream<QuickMatchRematchRequest?> watchRematchRequest(String requestId) {
    return const Stream.empty();
  }

  @override
  Stream<QuickMatchRematchRequest?> watchUserRematchRequests(String userId) {
    return const Stream.empty();
  }

  @override
  Future<QuickMatch?> getQuickMatchByRoomId(String roomId) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthRepository implements AuthRepository {
  @override
  String? get currentUserId => 'user-1';

  @override
  bool get isAuthenticated => true;

  @override
  bool get isGuest => false;

  @override
  Stream<AppAuthState> get authStateChanges =>
      Stream.value(Authenticated(
        PlayerProfile(
          id: 'user-1',
          email: 'user1@bingo.app',
          displayName: 'User One',
          avatarColorHex: '#20243A',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Quick Match Rematch & Result Lifecycle Domain Tests', () {
    test('QuickMatchRematchRequest JSON serialization and getters', () {
      final now = DateTime.now();
      final expires = now.add(const Duration(seconds: 30));
      final json = {
        'id': 'rematch-001',
        'previous_match_id': 'match-prev',
        'requester_user_id': 'user-a',
        'opponent_user_id': 'user-b',
        'status': 'PENDING',
        'new_match_id': null,
        'expires_at': expires.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'opponent': {
          'id': 'user-b',
          'display_name': 'Bob',
          'avatar_color_hex': '#FC695C',
        },
      };

      final req = QuickMatchRematchRequest.fromJson(json, currentUserId: 'user-a');
      expect(req.id, equals('rematch-001'));
      expect(req.isPending, isTrue);
      expect(req.isAccepted, isFalse);
      expect(req.isRequester('user-a'), isTrue);
      expect(req.isRequester('user-b'), isFalse);
      expect(req.opponent?.displayName, equals('Bob'));
      expect(req.secondsRemaining, greaterThan(0));
    });

    test('QuickMatchResultData derives victory, defeat and draw correctly', () {
      final data = QuickMatchResultData(
        matchId: 'match-1',
        roomId: 'room-1',
        roomCode: '123456',
        gameId: 'game-1',
        status: QuickMatchStatus.completed,
        winnerUserId: 'user-a',
        totalCalls: 22,
        durationSeconds: 110,
        player1: const QuickMatchParticipantResult(
          id: 'user-a',
          displayName: 'Alice',
          avatarColorHex: '#20243A',
          linesClaimed: 5,
          isWinner: true,
        ),
        player2: const QuickMatchParticipantResult(
          id: 'user-b',
          displayName: 'Bob',
          avatarColorHex: '#FC695C',
          linesClaimed: 3,
          isWinner: false,
        ),
      );

      expect(data.isVictory('user-a'), isTrue);
      expect(data.isVictory('user-b'), isFalse);
      expect(data.isDraw('user-a'), isFalse);
      expect(data.myResult('user-a').linesClaimed, equals(5));
      expect(data.opponentResult('user-a').linesClaimed, equals(3));
    });

    test('Room domain model correctly identifies Quick Match vs Private Room', () {
      final qmRoom = Room(
        id: 'r1',
        code: 'QM001',
        name: 'Quick Match 1v1',
        hostId: 'u1',
        maxPlayers: 2,
        prepTimeSeconds: 30,
        turnTimeSeconds: 20,
        matchType: 'QUICK_MATCH',
        status: RoomStatus.inProgress,
        createdAt: DateTime.now(),
      );
      expect(qmRoom.isQuickMatch, isTrue);

      final privateRoom = Room(
        id: 'r2',
        code: 'PR001',
        name: 'Friday Bingo Club',
        hostId: 'u1',
        maxPlayers: 4,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
        matchType: 'PRIVATE_ROOM',
        status: RoomStatus.waiting,
        createdAt: DateTime.now(),
      );
      expect(privateRoom.isQuickMatch, isFalse);
    });
  });

  group('QuickMatchResultScreen Widget & Exclusion Tests', () {
    late MockMultiplayerRepository mockRepo;
    late FakeAuthRepository fakeAuth;

    setUp(() {
      mockRepo = MockMultiplayerRepository();
      fakeAuth = FakeAuthRepository();

      mockRepo.resultDataToReturn = QuickMatchResultData(
        matchId: 'match-123',
        roomId: 'room-123',
        roomCode: '999888',
        gameId: 'game-123',
        status: QuickMatchStatus.completed,
        winnerUserId: 'user-1',
        totalCalls: 20,
        durationSeconds: 95,
        player1: const QuickMatchParticipantResult(
          id: 'user-1',
          displayName: 'User One',
          avatarColorHex: '#20243A',
          linesClaimed: 5,
          isWinner: true,
        ),
        player2: const QuickMatchParticipantResult(
          id: 'user-2',
          displayName: 'User Two',
          avatarColorHex: '#FC695C',
          linesClaimed: 2,
          isWinner: false,
        ),
      );
    });

    testWidgets('Renders dedicated Quick Match result with ONLY REMATCH and BACK TO HOME',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            multiplayerRepositoryProvider.overrideWithValue(mockRepo),
            authRepositoryProvider.overrideWithValue(fakeAuth),
          ],
          child: const MaterialApp(
            home: QuickMatchResultScreen(matchId: 'match-123'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verified: Displays Victory outcome
      expect(find.text('VICTORY!'), findsOneWidget);
      expect(find.text('QUICK MATCH 1V1 RESULT'), findsOneWidget);
      expect(find.text('Match Statistics'), findsOneWidget);
      expect(find.text('YOU'), findsOneWidget);
      expect(find.text('OPPONENT'), findsOneWidget);

      // Verified: Exactly REMATCH and BACK TO HOME actions present
      expect(find.text('REMATCH'), findsOneWidget);
      expect(find.text('BACK TO HOME'), findsOneWidget);

      // CRITICAL VERIFICATION: No private room actions or room code
      expect(find.text('BACK TO ROOM LOBBY'), findsNothing);
      expect(find.text('VIEW DETAILED ROOM STATS'), findsNothing);
      expect(find.text('START NEXT ROUND'), findsNothing);
      expect(find.text('Room Code'), findsNothing);
      expect(find.text('Room Stats'), findsNothing);
    });

    testWidgets('Tapping REMATCH requests bilateral rematch', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            multiplayerRepositoryProvider.overrideWithValue(mockRepo),
            authRepositoryProvider.overrideWithValue(fakeAuth),
          ],
          child: const MaterialApp(
            home: QuickMatchResultScreen(matchId: 'match-123'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final rematchBtn = find.text('REMATCH');
      expect(rematchBtn, findsOneWidget);
      await tester.ensureVisible(rematchBtn);
      await tester.tap(rematchBtn);
      await tester.pumpAndSettle();

      expect(mockRepo.requestRematchCalled, isTrue);
    });
  });
}
