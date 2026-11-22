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

  Future<Map<String, dynamic>> restGet(String path, {String? bearerToken}) async {
    final uri = Uri.parse('$supabaseUrl$path');
    final req = await httpClient.getUrl(uri);
    req.headers.set('apikey', supabaseAnonKey);
    req.headers.set('Authorization', 'Bearer ${bearerToken ?? supabaseAnonKey}');
    final res = await req.close();
    final bodyStr = await res.transform(utf8.decoder).join();
    return {
      'statusCode': res.statusCode,
      'body': bodyStr.isNotEmpty ? jsonDecode(bodyStr) : null,
    };
  }

  Future<Map<String, dynamic>> restPost(String path, Map<String, dynamic> body, {String? bearerToken}) async {
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
    return {
      'statusCode': res.statusCode,
      'body': bodyStr.isNotEmpty ? jsonDecode(bodyStr) : null,
    };
  }

  Future<String?> getAuthToken(String email, String password, String displayName) async {
    final loginRes = await restPost('/auth/v1/token?grant_type=password', {
      'email': email,
      'password': password,
    });
    if (loginRes['statusCode'] == 200 && loginRes['body'] != null) {
      return loginRes['body']['access_token'] as String?;
    }
    final signupRes = await restPost('/auth/v1/signup', {
      'email': email,
      'password': password,
      'data': {'display_name': displayName}
    });
    if (signupRes['statusCode'] == 200 && signupRes['body'] != null) {
      return signupRes['body']['access_token'] as String?;
    }
    return null;
  }

  group('Live End-to-End Supabase Gameplay & Forfeit Verification', () {
    test('Authenticate two real users and verify live room creation, board prep, game start, and 2-player forfeit', () async {
      final tokenA = await getAuthToken('live_audit_host@bingo.dev', 'LivePassword123!', 'Live Host Alice');
      final tokenB = await getAuthToken('live_audit_guest@bingo.dev', 'LivePassword123!', 'Live Guest Bob');

      expect(tokenA, isNotNull);
      expect(tokenB, isNotNull);

      // Verify user profile IDs
      final userARes = await restGet('/auth/v1/user', bearerToken: tokenA);
      expect(userARes['statusCode'], equals(200));
      final userAId = userARes['body']['id'] as String;

      final userBRes = await restGet('/auth/v1/user', bearerToken: tokenB);
      expect(userBRes['statusCode'], equals(200));
      final userBId = userBRes['body']['id'] as String;

      // 1. Host creates room on Supabase
      final roomCode = 'Z${DateTime.now().millisecondsSinceEpoch % 100000}';
      final createRoomRes = await restPost('/rest/v1/rooms', {
        'name': 'Live Audit Duel',
        'code': roomCode,
        'host_id': userAId,
        'max_players': 2,
        'status': 'waiting',
        'prep_time_seconds': 30,
        'turn_time_seconds': 15,
      }, bearerToken: tokenA);

      expect(createRoomRes['statusCode'], inInclusiveRange(200, 201));
      final roomId = (createRoomRes['body'] as List).first['id'] as String;

      // Host seats at seat 0
      await restPost('/rest/v1/room_players', {
        'room_id': roomId,
        'user_id': userAId,
        'seat_index': 0,
        'is_host': true,
        'is_ready': true,
      }, bearerToken: tokenA);

      // Guest seats at seat 1
      await restPost('/rest/v1/room_players', {
        'room_id': roomId,
        'user_id': userBId,
        'seat_index': 1,
        'is_host': false,
        'is_ready': true,
      }, bearerToken: tokenB);

      // 2. Host starts board preparation via rpc_start_game
      final startRes = await restPost('/rest/v1/rpc/rpc_start_game', {
        'p_room_id': roomId,
      }, bearerToken: tokenA);

      expect(startRes['statusCode'], equals(200));
      final startBody = startRes['body'] as Map<String, dynamic>;
      expect(startBody['success'], isTrue);
      final gameId = startBody['game_id'] as String;

      // 3. Both submit valid 25-number boards
      final boardA = List.generate(25, (i) => i + 1);
      final boardB = List.generate(25, (i) => 25 - i);

      final submitARes = await restPost('/rest/v1/rpc/rpc_submit_board', {
        'p_game_id': gameId,
        'p_board': boardA,
      }, bearerToken: tokenA);
      expect(submitARes['statusCode'], equals(200));

      final submitBRes = await restPost('/rest/v1/rpc/rpc_submit_board', {
        'p_game_id': gameId,
        'p_board': boardB,
      }, bearerToken: tokenB);
      expect(submitBRes['statusCode'], equals(200));

      // 4. Verify game transitioned to in_progress
      final gameRes = await restGet('/rest/v1/games?id=eq.$gameId', bearerToken: tokenA);
      expect(gameRes['statusCode'], equals(200));
      final gameRow = (gameRes['body'] as List).first;
      expect(gameRow['status'], equals('in_progress'));

      // 5. Host executes rpc_forfeit_match on live Supabase backend
      final forfeitRes = await restPost('/rest/v1/rpc/rpc_forfeit_match', {
        'p_game_id': gameId,
        'p_room_id': roomId,
      }, bearerToken: tokenA);

      expect(forfeitRes['statusCode'], equals(200));
      final forfeitBody = forfeitRes['body'] as Map<String, dynamic>;

      expect(forfeitBody['success'], isTrue);
      expect(forfeitBody['match_completed'], isTrue);
      expect(forfeitBody['winner_id'], equals(userBId));
      expect(forfeitBody['is_forfeit'], isTrue);

      // 6. Verify remote room_match_history on Supabase
      final historyRes = await restGet('/rest/v1/room_match_history?game_id=eq.$gameId', bearerToken: tokenA);
      expect(historyRes['statusCode'], equals(200));
      final historyList = historyRes['body'] as List;
      expect(historyList, isNotEmpty);
      final historyRecord = historyList.first as Map<String, dynamic>;
      expect(historyRecord['is_forfeit'], isTrue);
      expect(historyRecord['finish_reason'], equals('forfeit'));
      expect(historyRecord['winner_id'], equals(userBId));

      // 7. Verify remote games table status is 'completed' (queried by winner tokenB)
      final completedGameRes = await restGet('/rest/v1/games?id=eq.$gameId', bearerToken: tokenB);
      final completedGameRow = (completedGameRes['body'] as List).first;
      expect(completedGameRow['status'], equals('completed'));
      expect(completedGameRow['winner_user_id'], equals(userBId));

      // Verify forfeiter tokenA no longer has active room membership (RLS protects game)
      final forfeiterGameCheck = await restGet('/rest/v1/games?id=eq.$gameId', bearerToken: tokenA);
      expect((forfeiterGameCheck['body'] as List).isEmpty, isTrue,
          reason: 'Forfeited player must no longer access room game via RLS');

      // 8. Verify host is_forfeited is TRUE in game_player_states
      final statesRes = await restGet('/rest/v1/game_player_states?game_id=eq.$gameId', bearerToken: tokenB);
      final states = statesRes['body'] as List;
      final hostState = states.firstWhere((p) => p['user_id'] == userAId);
      final guestState = states.firstWhere((p) => p['user_id'] == userBId);
      expect(hostState['is_forfeited'], isTrue);
      expect(guestState['is_forfeited'], isFalse);

      // 9. Verify Idempotency on Supabase: Calling rpc_forfeit_match a second time returns match already completed
      final secondForfeitRes = await restPost('/rest/v1/rpc/rpc_forfeit_match', {
        'p_game_id': gameId,
        'p_room_id': roomId,
      }, bearerToken: tokenA);
      expect(secondForfeitRes['statusCode'], equals(200));
      final secondForfeitBody = secondForfeitRes['body'] as Map<String, dynamic>;
      expect(secondForfeitBody['match_completed'], isTrue);

      // 10. Verify rpc_get_user_recent_rooms does NOT contain room for forfeiter (membership removed)
      final recentRes = await restPost('/rest/v1/rpc/rpc_get_user_recent_rooms', {'p_limit': 5}, bearerToken: tokenA);
      expect(recentRes['statusCode'], equals(200));
      final recentList = recentRes['body'] as List;
      expect(recentList.any((r) => r['id'] == roomId), isFalse,
          reason: 'Forfeited player was removed from room_players');

      // But winner tokenB still has room membership
      final recentBRes = await restPost('/rest/v1/rpc/rpc_get_user_recent_rooms', {'p_limit': 5}, bearerToken: tokenB);
      expect(recentBRes['statusCode'], equals(200));
      final recentBList = recentBRes['body'] as List;
      expect(recentBList.any((r) => r['id'] == roomId), isTrue);
    });

    test('3-Player Live Match: Forfeit in 3-player match keeps game active and second forfeit awards victory', () async {
      final tokenA = await getAuthToken('live_audit_host@bingo.dev', 'LivePassword123!', 'Live Host Alice');
      final tokenB = await getAuthToken('live_audit_guest@bingo.dev', 'LivePassword123!', 'Live Guest Bob');
      final tokenC = await getAuthToken('live_audit_guest_c@bingo.dev', 'LivePassword123!', 'Live Guest Charlie');

      final userAId = (await restGet('/auth/v1/user', bearerToken: tokenA))['body']['id'] as String;
      final userBId = (await restGet('/auth/v1/user', bearerToken: tokenB))['body']['id'] as String;
      final userCId = (await restGet('/auth/v1/user', bearerToken: tokenC))['body']['id'] as String;

      // 1. Create 3-player room
      final roomCode = 'Y${DateTime.now().millisecondsSinceEpoch % 100000}';
      final createRoomRes = await restPost('/rest/v1/rooms', {
        'name': 'Live 3-Player Arena',
        'code': roomCode,
        'host_id': userAId,
        'max_players': 3,
        'status': 'waiting',
        'prep_time_seconds': 30,
        'turn_time_seconds': 15,
      }, bearerToken: tokenA);
      final roomId = (createRoomRes['body'] as List).first['id'] as String;

      await restPost('/rest/v1/room_players', {
        'room_id': roomId,
        'user_id': userAId,
        'seat_index': 0,
        'is_host': true,
        'is_ready': true,
      }, bearerToken: tokenA);

      await restPost('/rest/v1/room_players', {
        'room_id': roomId,
        'user_id': userBId,
        'seat_index': 1,
        'is_host': false,
        'is_ready': true,
      }, bearerToken: tokenB);

      await restPost('/rest/v1/room_players', {
        'room_id': roomId,
        'user_id': userCId,
        'seat_index': 2,
        'is_host': false,
        'is_ready': true,
      }, bearerToken: tokenC);

      // 2. Start game
      final startRes = await restPost('/rest/v1/rpc/rpc_start_game', {'p_room_id': roomId}, bearerToken: tokenA);
      final gameId = startRes['body']['game_id'] as String;

      // 3. Submit boards for all 3 players
      final board = List.generate(25, (i) => i + 1);
      await restPost('/rest/v1/rpc/rpc_submit_board', {'p_game_id': gameId, 'p_board': board}, bearerToken: tokenA);
      await restPost('/rest/v1/rpc/rpc_submit_board', {'p_game_id': gameId, 'p_board': board}, bearerToken: tokenB);
      await restPost('/rest/v1/rpc/rpc_submit_board', {'p_game_id': gameId, 'p_board': board}, bearerToken: tokenC);

      // Verify game is in_progress
      final gameRes = await restGet('/rest/v1/games?id=eq.$gameId', bearerToken: tokenA);
      expect((gameRes['body'] as List).first['status'], equals('in_progress'));

      // 4. Bob (User B) forfeits: should NOT complete match, 2 active players remain
      final forfeitBRes = await restPost('/rest/v1/rpc/rpc_forfeit_match', {
        'p_game_id': gameId,
        'p_room_id': roomId,
      }, bearerToken: tokenB);

      expect(forfeitBRes['statusCode'], equals(200));
      final forfeitBBody = forfeitBRes['body'] as Map<String, dynamic>;
      expect(forfeitBBody['success'], isTrue);
      expect(forfeitBBody['match_completed'], isFalse);
      expect(forfeitBBody['active_players_count'], equals(2));

      // Game must still be in_progress
      final gameStillActive = await restGet('/rest/v1/games?id=eq.$gameId', bearerToken: tokenA);
      expect((gameStillActive['body'] as List).first['status'], equals('in_progress'));

      // 5. Alice (Host, User A) forfeits: now only Charlie (User C) remains -> Match completes with Charlie as winner
      final forfeitARes = await restPost('/rest/v1/rpc/rpc_forfeit_match', {
        'p_game_id': gameId,
        'p_room_id': roomId,
      }, bearerToken: tokenA);

      expect(forfeitARes['statusCode'], equals(200));
      final forfeitABody = forfeitARes['body'] as Map<String, dynamic>;
      expect(forfeitABody['success'], isTrue);
      expect(forfeitABody['match_completed'], isTrue);
      expect(forfeitABody['winner_id'], equals(userCId));

      // Verify final game state on Supabase (queried by winner tokenC)
      final finalGameRes = await restGet('/rest/v1/games?id=eq.$gameId', bearerToken: tokenC);
      final finalGameRow = (finalGameRes['body'] as List).first;
      expect(finalGameRow['status'], equals('completed'));
      expect(finalGameRow['winner_user_id'], equals(userCId));

      // Verify forfeiter tokenA cannot query private game via RLS after seat removal
      final forfeiterCheck = await restGet('/rest/v1/games?id=eq.$gameId', bearerToken: tokenA);
      expect((forfeiterCheck['body'] as List).isEmpty, isTrue);
    });
  });
}
