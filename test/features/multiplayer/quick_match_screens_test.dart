import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/features/multiplayer/domain/quick_match.dart';
import 'package:bingo/features/multiplayer/presentation/opponent_found_notifier.dart';
import 'package:bingo/features/multiplayer/presentation/quick_match_notifier.dart';
import 'package:bingo/features/multiplayer/quick_match/opponent_found_screen.dart';
import 'package:bingo/features/multiplayer/quick_match/quick_match_screen.dart';

void main() {
  group('QuickMatchScreen Widget Tests', () {
    testWidgets('Idle state renders exact approved Stitch components', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            quickMatchProvider.overrideWith((ref) => MockQuickMatchNotifier(
                  const QuickMatchState(
                    status: QuickMatchScreenStatus.idle,
                    currentUserDisplayName: 'Alex',
                    currentUserAvatarColorHex: '#20243A',
                    isGuest: false,
                  ),
                )),
          ],
          child: const MaterialApp(
            home: QuickMatchScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Top Header
      expect(find.text('BINGO'), findsOneWidget);
      expect(find.text('QUICK MATCH'), findsOneWidget);
      expect(find.text('ONLINE'), findsOneWidget);

      // Hero
      expect(find.text('ONLINE MATCHMAKING'), findsOneWidget);
      expect(find.text('Ready for a challenge?'), findsOneWidget);
      expect(find.text('Find a player online and compete for the BINGO!'), findsOneWidget);

      // Match Type Summary Card
      expect(find.text('Quick Match'), findsOneWidget);
      expect(find.text('1 VS 1'), findsOneWidget);
      expect(find.text('Classic 5×5 Bingo · Numbers 1–25'), findsOneWidget);
      expect(find.text('READY'), findsOneWidget);
      expect(find.text('Board Prep: 30s'), findsOneWidget);
      expect(find.text('Turn Time: 20s'), findsOneWidget);

      // Central Stage
      expect(find.text('YOU (Alex)'), findsOneWidget);
      expect(find.text('5×5 MATRIX'), findsOneWidget);
      expect(find.text('FIND OPPONENT'), findsOneWidget);

      // Status
      expect(find.text('Ready to find an opponent?'), findsOneWidget);
      expect(find.text('Tap start below to enter matchmaking queue'), findsOneWidget);

      // Idle Info Card
      expect(find.text('Fast-Paced Online Play'), findsOneWidget);
      expect(
        find.text('Complete 5 lines (horizontal, vertical, or diagonal) to call BINGO and claim victory!'),
        findsOneWidget,
      );

      // Primary Button
      expect(find.text('START SEARCHING'), findsOneWidget);
      expect(find.text('You can cancel matchmaking at any time once started.'), findsOneWidget);
      expect(find.text('CANCEL SEARCH'), findsNothing);
    });

    testWidgets('Searching state renders animated matrix, timer, and cancel button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            quickMatchProvider.overrideWith((ref) => MockQuickMatchNotifier(
                  const QuickMatchState(
                    status: QuickMatchScreenStatus.searching,
                    elapsedSeconds: 14,
                    currentUserDisplayName: 'Alex',
                    serverRegion: 'Auto (US-East)',
                    matchmakingStatusText: 'Searching for players...',
                    isGuest: false,
                  ),
                )),
          ],
          child: const MaterialApp(
            home: QuickMatchScreen(),
          ),
        ),
      );

      await tester.pump();

      // Searching state headings
      expect(find.text('Finding your opponent...'), findsNWidgets(2));
      expect(find.text('Searching for available players'), findsNWidgets(2));
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('MATCHING...'), findsOneWidget);

      // Elapsed Timer
      expect(find.text('ELAPSED: 00:14'), findsOneWidget);

      // Telemetry Cards
      expect(find.text('MATCHMAKING'), findsOneWidget);
      expect(find.text('Searching for players...'), findsOneWidget);
      expect(find.text('SERVER REGION'), findsOneWidget);
      expect(find.text('Auto (US-East)'), findsOneWidget);

      // Primary Button in Searching
      expect(find.text('CANCEL SEARCH'), findsOneWidget);
      expect(find.text('You can cancel anytime before a match is found.'), findsOneWidget);
      expect(find.text('START SEARCHING'), findsNothing);
    });

    testWidgets('Guest restriction view displays account required dialog with redirect', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            quickMatchProvider.overrideWith((ref) => MockQuickMatchNotifier(
                  const QuickMatchState(
                    isGuest: true,
                  ),
                )),
          ],
          child: const MaterialApp(
            home: QuickMatchScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('ACCOUNT REQUIRED'), findsOneWidget);
      expect(find.text('Play Online 1v1 Matches'), findsOneWidget);
      expect(find.text('CREATE ACCOUNT'), findsOneWidget);
      expect(find.text('SIGN IN'), findsOneWidget);
      expect(find.text('NOT NOW'), findsOneWidget);

      // Guest cannot see Start Searching
      expect(find.text('START SEARCHING'), findsNothing);
    });
  });

  group('OpponentFoundScreen Widget Tests', () {
    testWidgets('Renders Match Found hero, VS Arena, and coral countdown', (tester) async {
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      final mockMatch = QuickMatch(
        id: 'qm_test_1',
        roomId: 'room_123',
        roomCode: 'QCK123',
        gameId: 'game_456',
        player1Id: 'u_p1',
        player2Id: 'u_p2',
        status: QuickMatchStatus.countdown,
        countdownDeadline: deadline,
        opponent: const QuickMatchOpponent(
          id: 'u_p2',
          displayName: 'Jordan',
          avatarColorHex: '#FC695C',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            opponentFoundProvider('qm_test_1').overrideWith(
              (ref) => MockOpponentFoundNotifier(
                OpponentFoundState(
                  match: mockMatch,
                  isLoading: false,
                  remainingSeconds: 10,
                  progressFraction: 1.0,
                  currentUserName: 'Alex',
                  opponentName: 'Jordan',
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: OpponentFoundScreen(matchId: 'qm_test_1'),
          ),
        ),
      );

      await tester.pump();

      // Top Bar
      expect(find.text('BINGO'), findsOneWidget);
      expect(find.text('QUICK MATCH'), findsOneWidget);

      // Match Found Hero
      expect(find.text('MATCH FOUND'), findsOneWidget);
      expect(find.text('Opponent Found!'), findsOneWidget);
      expect(find.text('Your next BINGO challenge is locked and ready.'), findsOneWidget);

      // Versus Arena
      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('YOU'), findsOneWidget);
      expect(find.text('VS'), findsOneWidget);
      expect(find.text('1 VS 1'), findsOneWidget);
      expect(find.text('Jordan'), findsOneWidget);
      expect(find.text('OPPONENT'), findsOneWidget);

      // Match Details
      expect(find.text('MODE'), findsOneWidget);
      expect(find.text('Quick Match'), findsOneWidget);
      expect(find.text('PLAYERS'), findsOneWidget);
      expect(find.text('2 Online'), findsOneWidget);
      expect(find.text('CONNECTION'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);

      // Rules Chips
      expect(find.text('Board Preparation: 30s'), findsOneWidget);
      expect(find.text('Turn Time: 20s'), findsOneWidget);
      expect(find.text('5×5 Matrix · Numbers 1–25'), findsOneWidget);

      // Synchronizing Card
      expect(find.text('Both Players Connected'), findsOneWidget);
      expect(find.text('Preparing your match...'), findsOneWidget);

      // Countdown Card
      expect(find.text('MATCH STARTING IN'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('SECONDS'), findsOneWidget);
      expect(find.text('Get ready! Your match is about to begin.'), findsOneWidget);
    });
  });
}

class MockQuickMatchNotifier extends StateNotifier<QuickMatchState>
    implements QuickMatchNotifier {
  MockQuickMatchNotifier(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockOpponentFoundNotifier extends StateNotifier<OpponentFoundState>
    implements OpponentFoundNotifier {
  MockOpponentFoundNotifier(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
