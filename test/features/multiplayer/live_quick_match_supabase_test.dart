// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  const supabaseUrl = 'https://pqkrqppxbnrjcgxvmogn.supabase.co';
  const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBxa3JxcHB4Ym5yamNneHZtb2duIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMzNzQxNjAsImV4cCI6MjEwODk1MDE2MH0.9x4_jbX5e0fCWv50baeL5tOsIVOh8M7yiwzOcP-OvFg';

  late HttpClient httpClient;

  setUpAll(() {
    HttpOverrides.global = null;
    httpClient = HttpClient();
  });

  tearDownAll(() {
    httpClient.close();
  });

  Future<Map<String, dynamic>> restGet(String path, {String? bearerToken}) async {
    final uri = Uri.parse('$supabaseUrl$path');
    final req = await httpClient.getUrl(uri);
    req.headers.set('apikey', supabaseAnonKey);
    req.headers.set('Authorization', 'Bearer ${bearerToken ?? supabaseAnonKey}');
    final res = await req.close();
    final bodyStr = await res.transform(utf8.decoder).join();
    dynamic parsedBody;
    try {
      parsedBody = bodyStr.isNotEmpty ? jsonDecode(bodyStr) : null;
    } catch (_) {
      parsedBody = bodyStr;
    }
    return {
      'statusCode': res.statusCode,
      'body': parsedBody,
    };
  }

  Future<Map<String, dynamic>> restPost(
    String path,
    Map<String, dynamic> body, {
    String? bearerToken,
  }) async {
    final uri = Uri.parse('$supabaseUrl$path');
    final req = await httpClient.postUrl(uri);
    req.headers.set('apikey', supabaseAnonKey);
    req.headers.set('Authorization', 'Bearer ${bearerToken ?? supabaseAnonKey}');
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('Prefer', 'return=representation');
    final bodyBytes = utf8.encode(jsonEncode(body));
    req.add(bodyBytes);
    final res = await req.close();
    final bodyStr = await res.transform(utf8.decoder).join();
    dynamic parsedBody;
    try {
      parsedBody = bodyStr.isNotEmpty ? jsonDecode(bodyStr) : null;
    } catch (_) {
      parsedBody = bodyStr;
    }
    return {
      'statusCode': res.statusCode,
      'body': parsedBody,
    };
  }

  Future<Map<String, dynamic>> getAuthSession(
    String email,
    String password,
    String displayName,
  ) async {
    final signInRes = await restPost('/auth/v1/token?grant_type=password', {
      'email': email,
      'password': password,
    });

    if (signInRes['statusCode'] == 200 && signInRes['body'] != null) {
      final token = signInRes['body']['access_token'] as String;
      final userId = signInRes['body']['user']['id'] as String;
      return {'token': token, 'userId': userId};
    }

    // Attempt Sign Up
    final signUpRes = await restPost('/auth/v1/signup', {
      'email': email,
      'password': password,
      'data': {'display_name': displayName, 'avatar_color_hex': '#20243A'},
    });

    if (signUpRes['statusCode'] == 200 && signUpRes['body'] != null) {
      final token = signUpRes['body']['access_token'] as String?;
      final user = signUpRes['body']['user'] as Map<String, dynamic>? ??
          (signUpRes['body'] as Map<String, dynamic>);
      final userId = user['id'] as String;

      if (token != null) {
        return {'token': token, 'userId': userId};
      }

      // Retry sign in
      final retry = await restPost('/auth/v1/token?grant_type=password', {
        'email': email,
        'password': password,
      });
      return {
        'token': retry['body']['access_token'] as String,
        'userId': retry['body']['user']['id'] as String,
      };
    }

    throw StateError('Could not authenticate session for $email: ${signUpRes['body']}');
  }

  group('Migration 17 Full Post-Deployment Live Verification Suite', () {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    late Map<String, dynamic> sessionA;
    late Map<String, dynamic> sessionB;
    late Map<String, dynamic> sessionC;

    String? createdMatchId;
    String? createdRoomId;
    String? createdGameId;

    setUpAll(() async {
      // Drain any stale waiting players so queue starts completely empty
      final drainUser = await getAuthSession(
        'qm_drain_$timestamp@bingo.app',
        'BingoTest2026!',
        'Drain User',
      );
      for (int i = 0; i < 5; i++) {
        final res = await restPost(
          '/rest/v1/rpc/rpc_enter_matchmaking_queue',
          {'p_region': 'auto'},
          bearerToken: drainUser['token'],
        );
        if (res['statusCode'] == 200 && res['body']['status'] == 'SEARCHING') {
          await restPost(
            '/rest/v1/rpc/rpc_cancel_matchmaking_queue',
            {},
            bearerToken: drainUser['token'],
          );
          break;
        }
      }

      sessionA = await getAuthSession(
        'qm_user_a_$timestamp@bingo.app',
        'BingoTest2026!',
        'User A $timestamp',
      );
      sessionB = await getAuthSession(
        'qm_user_b_$timestamp@bingo.app',
        'BingoTest2026!',
        'User B $timestamp',
      );
      sessionC = await getAuthSession(
        'qm_user_c_$timestamp@bingo.app',
        'BingoTest2026!',
        'User C $timestamp',
      );
    });

    test('1. Verify Migration 17 Deployed Objects & RPC Signatures', () async {
      // Check matchmaking_queue table via REST
      final queueRes = await restGet(
        '/rest/v1/matchmaking_queue?limit=1',
        bearerToken: sessionA['token'],
      );
      expect(queueRes['statusCode'], equals(200));

      // Check quick_matches table via REST
      final matchesRes = await restGet(
        '/rest/v1/quick_matches?limit=1',
        bearerToken: sessionA['token'],
      );
      expect(matchesRes['statusCode'], equals(200));

      // Verify rpc_get_active_quick_match returns 200 for clean user
      final activeRpc = await restPost(
        '/rest/v1/rpc/rpc_get_active_quick_match',
        {},
        bearerToken: sessionA['token'],
      );
      expect(activeRpc['statusCode'], equals(200));
      expect(activeRpc['body']['has_active_match'], isFalse);

      // Verify rpc_cancel_matchmaking_queue returns 200
      final cancelRpc = await restPost(
        '/rest/v1/rpc/rpc_cancel_matchmaking_queue',
        {},
        bearerToken: sessionA['token'],
      );
      expect(cancelRpc['statusCode'], equals(200));
      expect(cancelRpc['body']['success'], isTrue);
    });

    test('2. Two-Session Atomic Pairing (Player A and Player B)', () async {
      // Step A: Player A enters matchmaking queue
      final resA = await restPost(
        '/rest/v1/rpc/rpc_enter_matchmaking_queue',
        {'p_region': 'auto'},
        bearerToken: sessionA['token'],
      );
      expect(resA['statusCode'], equals(200));
      expect(resA['body']['success'], isTrue);
      expect(resA['body']['status'], equals('SEARCHING'));
      expect(resA['body']['queue_id'], isNotNull);

      // Verify Player A queue row exists with SEARCHING status
      final queueCheckA = await restGet(
        '/rest/v1/matchmaking_queue?user_id=eq.${sessionA['userId']}&status=eq.SEARCHING',
        bearerToken: sessionA['token'],
      );
      expect(queueCheckA['statusCode'], equals(200));
      final rowsA = queueCheckA['body'] as List;
      expect(rowsA.isNotEmpty, isTrue);
      expect(rowsA.first['status'], equals('SEARCHING'));

      // Step B: Player B enters matchmaking queue
      final resB = await restPost(
        '/rest/v1/rpc/rpc_enter_matchmaking_queue',
        {'p_region': 'auto'},
        bearerToken: sessionB['token'],
      );
      expect(resB['statusCode'], equals(200));
      expect(resB['body']['success'], isTrue);
      expect(resB['body']['status'], equals('MATCHED'));

      createdMatchId = resB['body']['match_id'] as String;
      createdRoomId = resB['body']['room_id'] as String;
      createdGameId = resB['body']['game_id'] as String;

      expect(createdMatchId, isNotNull);
      expect(createdRoomId, isNotNull);
      expect(createdGameId, isNotNull);

      // Verify Player A now sees the same MATCHED state via rpc_get_active_quick_match
      final activeA = await restPost(
        '/rest/v1/rpc/rpc_get_active_quick_match',
        {},
        bearerToken: sessionA['token'],
      );
      expect(activeA['statusCode'], equals(200));
      expect(activeA['body']['has_active_match'], isTrue);
      expect(activeA['body']['match_id'], equals(createdMatchId));
      expect(activeA['body']['room_id'], equals(createdRoomId));
      expect(activeA['body']['game_id'], equals(createdGameId));

      // Verify both queue entries became MATCHED (tested per session under RLS)
      final qRowA = await restGet(
        '/rest/v1/matchmaking_queue?match_id=eq.$createdMatchId',
        bearerToken: sessionA['token'],
      );
      expect(qRowA['statusCode'], equals(200));
      final entriesA = qRowA['body'] as List;
      expect(entriesA.length, equals(1));
      expect(entriesA.first['status'], equals('MATCHED'));
      expect(entriesA.first['user_id'], equals(sessionA['userId']));

      final qRowB = await restGet(
        '/rest/v1/matchmaking_queue?match_id=eq.$createdMatchId',
        bearerToken: sessionB['token'],
      );
      expect(qRowB['statusCode'], equals(200));
      final entriesB = qRowB['body'] as List;
      expect(entriesB.length, equals(1));
      expect(entriesB.first['status'], equals('MATCHED'));
      expect(entriesB.first['user_id'], equals(sessionB['userId']));
    });

    test('3. Realtime Opponent Details & State Synchronization', () async {
      expect(createdMatchId, isNotNull);

      // Player A fetches match details
      final detailsA = await restPost(
        '/rest/v1/rpc/rpc_get_quick_match_details',
        {'p_match_id': createdMatchId},
        bearerToken: sessionA['token'],
      );
      expect(detailsA['statusCode'], equals(200));
      expect(detailsA['body']['success'], isTrue);
      expect(detailsA['body']['player1'], isNotNull);
      expect(detailsA['body']['player2'], isNotNull);

      // Player B fetches match details
      final detailsB = await restPost(
        '/rest/v1/rpc/rpc_get_quick_match_details',
        {'p_match_id': createdMatchId},
        bearerToken: sessionB['token'],
      );
      expect(detailsB['statusCode'], equals(200));
      expect(detailsB['body']['success'], isTrue);

      // Ensure identical deadlines and synchronized references
      expect(detailsA['body']['countdown_deadline'], equals(detailsB['body']['countdown_deadline']));
      expect(detailsA['body']['game_id'], equals(detailsB['body']['game_id']));
      expect(detailsA['body']['room_id'], equals(detailsB['body']['room_id']));
    });

    test('4. 10-Second Countdown & Transition to Board Preparation', () async {
      expect(createdMatchId, isNotNull);

      // Transition to Board Preparation
      final transRes = await restPost(
        '/rest/v1/rpc/rpc_transition_to_board_prep',
        {'p_match_id': createdMatchId},
        bearerToken: sessionA['token'],
      );
      expect(transRes['statusCode'], equals(200));
      expect(transRes['body']['success'], isTrue);
      expect(transRes['body']['status'], equals('BOARD_PREPARATION'));
      expect(transRes['body']['prep_deadline'], isNotNull);

      // Repeated call is idempotent
      final transRepeat = await restPost(
        '/rest/v1/rpc/rpc_transition_to_board_prep',
        {'p_match_id': createdMatchId},
        bearerToken: sessionB['token'],
      );
      expect(transRepeat['statusCode'], equals(200));
      expect(transRepeat['body']['success'], isTrue);
      expect(transRepeat['body']['status'], equals('BOARD_PREPARATION'));
    });

    test('5. Board Preparation & Gameplay Integration (Board Submissions & Numbers)', () async {
      expect(createdGameId, isNotNull);

      // Generate valid 5x5 boards for both players (numbers 1-25)
      final boardA = List.generate(25, (i) => i + 1);
      final boardB = List.generate(25, (i) => 25 - i);

      // Player A submits board
      final subA = await restPost(
        '/rest/v1/rpc/rpc_submit_board',
        {
          'p_game_id': createdGameId,
          'p_board': boardA,
        },
        bearerToken: sessionA['token'],
      );
      expect(subA['statusCode'], equals(200));
      expect(subA['body']['success'], isTrue);

      // Player B submits board
      final subB = await restPost(
        '/rest/v1/rpc/rpc_submit_board',
        {
          'p_game_id': createdGameId,
          'p_board': boardB,
        },
        bearerToken: sessionB['token'],
      );
      expect(subB['statusCode'], equals(200));
      expect(subB['body']['success'], isTrue);

      // When both players submit boards, game transitions to in_progress automatically
      final gameCheck = await restGet(
        '/rest/v1/games?id=eq.$createdGameId',
        bearerToken: sessionA['token'],
      );
      expect(gameCheck['statusCode'], equals(200));
      final gamesList = gameCheck['body'] as List;
      expect(gamesList.isNotEmpty, isTrue);
      final gameRecord = gamesList.first;
      expect(gameRecord['status'], equals('in_progress'));

      // Call number with active turn user (void returns 200 or 204 in PostgREST)
      final turnUserId = gameRecord['current_turn_user_id'] as String?;
      if (turnUserId != null) {
        final activeCallerToken = turnUserId == sessionA['userId'] ? sessionA['token'] : sessionB['token'];
        final callRes = await restPost(
          '/rest/v1/rpc/rpc_call_number',
          {
            'p_game_id': createdGameId,
            'p_number': 15,
          },
          bearerToken: activeCallerToken,
        );
        expect(callRes['statusCode'] == 200 || callRes['statusCode'] == 204, isTrue);
      }
    });

    test('6. Cancellation and Failure Cases', () async {
      // 6a: Player C enters queue
      final enterC = await restPost(
        '/rest/v1/rpc/rpc_enter_matchmaking_queue',
        {'p_region': 'auto'},
        bearerToken: sessionC['token'],
      );
      expect(enterC['statusCode'], equals(200));
      expect(enterC['body']['status'], equals('SEARCHING'));

      // 6b: Duplicate Start Searching cancels previous and creates fresh SEARCHING entry without orphaned duplicates
      final dupEnterC = await restPost(
        '/rest/v1/rpc/rpc_enter_matchmaking_queue',
        {'p_region': 'auto'},
        bearerToken: sessionC['token'],
      );
      expect(dupEnterC['statusCode'], equals(200));
      expect(dupEnterC['body']['status'], equals('SEARCHING'));

      // Check that only ONE active SEARCHING entry exists for Player C
      final activeEntriesC = await restGet(
        '/rest/v1/matchmaking_queue?user_id=eq.${sessionC['userId']}&status=eq.SEARCHING',
        bearerToken: sessionC['token'],
      );
      expect(activeEntriesC['statusCode'], equals(200));
      final rowsC = activeEntriesC['body'] as List;
      expect(rowsC.length, equals(1));

      // 6c: Player C cancels before pairing
      final cancelC = await restPost(
        '/rest/v1/rpc/rpc_cancel_matchmaking_queue',
        {},
        bearerToken: sessionC['token'],
      );
      expect(cancelC['statusCode'], equals(200));
      expect(cancelC['body']['success'], isTrue);
      expect(cancelC['body']['status'], equals('CANCELLED'));

      // Verify no SEARCHING entry remains for Player C
      final searchingAfterCancel = await restGet(
        '/rest/v1/matchmaking_queue?user_id=eq.${sessionC['userId']}&status=eq.SEARCHING',
        bearerToken: sessionC['token'],
      );
      expect(searchingAfterCancel['statusCode'], equals(200));
      expect((searchingAfterCancel['body'] as List).isEmpty, isTrue);

      // 6d: Duplicate Cancel Search is handled safely
      final dupCancelC = await restPost(
        '/rest/v1/rpc/rpc_cancel_matchmaking_queue',
        {},
        bearerToken: sessionC['token'],
      );
      expect(dupCancelC['statusCode'], equals(200));
      expect(dupCancelC['body']['success'], isTrue);

      // 6e: User with existing active match attempts to search
      // Player A is currently in an active match created in test 2
      final searchWithActiveMatch = await restPost(
        '/rest/v1/rpc/rpc_enter_matchmaking_queue',
        {'p_region': 'auto'},
        bearerToken: sessionA['token'],
      );
      expect(searchWithActiveMatch['statusCode'], equals(200));
      expect(searchWithActiveMatch['body']['is_existing_match'], isTrue);
      expect(searchWithActiveMatch['body']['match_id'], equals(createdMatchId));
    });
  });
}
