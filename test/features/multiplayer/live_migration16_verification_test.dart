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

  Future<String> getUserId(String token) async {
    final res = await restGet('/auth/v1/user', bearerToken: token);
    return res['body']['id'] as String;
  }

  String extractId(dynamic body) {
    if (body is List && body.isNotEmpty) return body.first['id'] as String;
    if (body is Map && body.containsKey('id')) return body['id'] as String;
    throw StateError('Cannot extract id from $body');
  }

  String generate6CharRoomCode() {
    final numStr = (DateTime.now().millisecondsSinceEpoch % 100000).toString().padLeft(5, '0');
    return 'F$numStr';
  }

  final dummyBoard = List<int>.generate(25, (i) => i + 1);

  group('Migration 16 Live Supabase Verification Tests', () {
    late String tokenA, tokenB, tokenC, tokenD;
    late String userAId, userBId, userCId, userDId;

    setUpAll(() async {
      tokenA = (await getAuthToken('live_audit_host@bingo.dev', 'LivePassword123!', 'Live Host Alice'))!;
      tokenB = (await getAuthToken('live_audit_guest@bingo.dev', 'LivePassword123!', 'Live Guest Bob'))!;
      tokenC = (await getAuthToken('live_audit_player3@bingo.dev', 'LivePassword123!', 'Live Player Charlie'))!;
      tokenD = (await getAuthToken('live_audit_player4@bingo.dev', 'LivePassword123!', 'Live Player Dave'))!;

      userAId = await getUserId(tokenA);
      userBId = await getUserId(tokenB);
      userCId = await getUserId(tokenC);
      userDId = await getUserId(tokenD);
    });

    test('1. Two-player forfeit: forfeiter removed from room_players, opponent wins, history preserved', () async {
      final code = generate6CharRoomCode();
      final createRes = await restPost('/rest/v1/rooms', {
        'name': 'Live 2P Match',
        'code': code,
        'host_id': userAId,
        'max_players': 2,
        'status': 'waiting',
        'prep_time_seconds': 30,
        'turn_time_seconds': 15,
      }, bearerToken: tokenA);
      expect(createRes['statusCode'], inInclusiveRange(200, 201), reason: '${createRes['body']}');
      final roomId = extractId(createRes['body']);

      // Join seats
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

      // Start game
      final startRes = await restPost('/rest/v1/rpc/rpc_start_game', {
        'p_room_id': roomId,
      }, bearerToken: tokenA);
      expect(startRes['statusCode'], equals(200));
      final gameId = (startRes['body'] as Map)['game_id'] as String;

      // Submit boards
      await restPost('/rest/v1/rpc/rpc_submit_board', {'p_game_id': gameId, 'p_board': dummyBoard}, bearerToken: tokenA);
      await restPost('/rest/v1/rpc/rpc_submit_board', {'p_game_id': gameId, 'p_board': dummyBoard}, bearerToken: tokenB);

      // Verify game is in_progress
      final gameProgRes = await restGet('/rest/v1/games?id=eq.$gameId', bearerToken: tokenA);
      expect((gameProgRes['body'] as List).first['status'], equals('in_progress'));

      // Player B forfeits
      final forfeitRes = await restPost('/rest/v1/rpc/rpc_forfeit_match', {
        'p_game_id': gameId,
        'p_room_id': roomId,
      }, bearerToken: tokenB);
      expect(forfeitRes['statusCode'], equals(200));
      final forfeitBody = forfeitRes['body'];
      expect(forfeitBody['success'], isTrue);
      expect(forfeitBody['match_completed'], isTrue);
      expect(forfeitBody['winner_id'], equals(userAId));

      // VERIFY ROOM MEMBERSHIP: Player B must be REMOVED from room_players!
      final roomPlayersRes = await restGet('/rest/v1/room_players?room_id=eq.$roomId', bearerToken: tokenA);
      final remainingMembers = roomPlayersRes['body'] as List;
      expect(remainingMembers.any((rp) => rp['user_id'] == userBId), isFalse,
          reason: 'Forfeited player must be removed from room_players');
      expect(remainingMembers.any((rp) => rp['user_id'] == userAId), isTrue,
          reason: 'Winner must remain in room_players');

      // VERIFY HISTORICAL GAME PARTICIPATION: Player B MUST be preserved in game_player_states with is_forfeited = true!
      final gpsRes = await restGet('/rest/v1/game_player_states?game_id=eq.$gameId', bearerToken: tokenA);
      final playerStates = gpsRes['body'] as List;
      expect(playerStates.length, equals(2), reason: 'Both players must remain recorded in game_player_states');
      final forfeiterGps = playerStates.firstWhere((p) => p['user_id'] == userBId);
      expect(forfeiterGps['is_forfeited'], isTrue);
      final winnerGps = playerStates.firstWhere((p) => p['user_id'] == userAId);
      expect(winnerGps['is_winner'], isTrue);

      // VERIFY MATCH HISTORY: room_match_history must record both players and indicate forfeit
      final historyRes = await restGet('/rest/v1/room_match_history?game_id=eq.$gameId', bearerToken: tokenA);
      final historyList = historyRes['body'] as List;
      expect(historyList.isNotEmpty, isTrue);
      final history = historyList.first;
      expect(history['is_forfeit'], isTrue);
      expect(history['winner_id'] ?? history['winner_user_id'], equals(userAId));
      final outcomes = history['player_outcomes'] ?? history['outcomes'];
      final outcomeList = outcomes is String ? jsonDecode(outcomes) as List : outcomes as List;
      expect(outcomeList.length, equals(2), reason: 'Historical match outcomes must retain all original participants');
      expect(outcomeList.any((o) => o['user_id'] == userBId && o['is_forfeited'] == true), isTrue);
    });

    test('2. Three-player forfeit: forfeiter removed, remaining 2 continue, second forfeit finalizes match', () async {
      final code = generate6CharRoomCode();
      final createRes = await restPost('/rest/v1/rooms', {
        'name': 'Live 3P Match',
        'code': code,
        'host_id': userAId,
        'max_players': 3,
        'status': 'waiting',
      }, bearerToken: tokenA);
      final roomId = extractId(createRes['body']);

      // Join 3 seats
      await restPost('/rest/v1/room_players', {'room_id': roomId, 'user_id': userAId, 'seat_index': 0, 'is_host': true, 'is_ready': true}, bearerToken: tokenA);
      await restPost('/rest/v1/room_players', {'room_id': roomId, 'user_id': userBId, 'seat_index': 1, 'is_host': false, 'is_ready': true}, bearerToken: tokenB);
      await restPost('/rest/v1/room_players', {'room_id': roomId, 'user_id': userCId, 'seat_index': 2, 'is_host': false, 'is_ready': true}, bearerToken: tokenC);

      final startRes = await restPost('/rest/v1/rpc/rpc_start_game', {'p_room_id': roomId}, bearerToken: tokenA);
      final gameId = (startRes['body'] as Map)['game_id'] as String;

      // Submit boards
      await restPost('/rest/v1/rpc/rpc_submit_board', {'p_game_id': gameId, 'p_board': dummyBoard}, bearerToken: tokenA);
      await restPost('/rest/v1/rpc/rpc_submit_board', {'p_game_id': gameId, 'p_board': dummyBoard}, bearerToken: tokenB);
      await restPost('/rest/v1/rpc/rpc_submit_board', {'p_game_id': gameId, 'p_board': dummyBoard}, bearerToken: tokenC);

      // Player B forfeits (1st forfeit in 3P)
      final forfeit1Res = await restPost('/rest/v1/rpc/rpc_forfeit_match', {
        'p_game_id': gameId,
        'p_room_id': roomId,
      }, bearerToken: tokenB);
      expect(forfeit1Res['statusCode'], equals(200));
      final f1Body = forfeit1Res['body'];
      expect(f1Body['success'], isTrue);
      expect(f1Body['match_completed'], isFalse, reason: 'Game must continue with remaining 2 players');
      expect(f1Body['active_players_count'], equals(2));

      // Player B must be removed from room_players
      final rp1 = await restGet('/rest/v1/room_players?room_id=eq.$roomId', bearerToken: tokenA);
      final rp1List = rp1['body'] as List;
      expect(rp1List.length, equals(2));
      expect(rp1List.any((p) => p['user_id'] == userBId), isFalse);

      // Game must still be in_progress
      final g1 = await restGet('/rest/v1/games?id=eq.$gameId', bearerToken: tokenA);
      expect((g1['body'] as List).first['status'], equals('in_progress'));

      // Player C forfeits (2nd forfeit -> only Host A remains)
      final forfeit2Res = await restPost('/rest/v1/rpc/rpc_forfeit_match', {
        'p_game_id': gameId,
        'p_room_id': roomId,
      }, bearerToken: tokenC);
      expect(forfeit2Res['statusCode'], equals(200));
      final f2Body = forfeit2Res['body'];
      expect(f2Body['success'], isTrue);
      expect(f2Body['match_completed'], isTrue, reason: 'Game must complete when only 1 active player remains');
      expect(f2Body['winner_id'], equals(userAId));

      // Player C must now also be removed from room_players
      final rp2 = await restGet('/rest/v1/room_players?room_id=eq.$roomId', bearerToken: tokenA);
      final rp2List = rp2['body'] as List;
      expect(rp2List.length, equals(1));
      expect(rp2List.first['user_id'], equals(userAId));

      // All 3 participants must be preserved in match history outcomes!
      final histRes = await restGet('/rest/v1/room_match_history?game_id=eq.$gameId', bearerToken: tokenA);
      final history = (histRes['body'] as List).first;
      final outcomes = history['player_outcomes'] ?? history['outcomes'];
      final outcomeList = outcomes is String ? jsonDecode(outcomes) as List : outcomes as List;
      expect(outcomeList.length, equals(3), reason: 'Match history must retain all 3 original participants');
      expect(outcomeList.where((o) => o['is_forfeited'] == true).length, equals(2));
    });

    test('3. Four-player forfeit: forfeiter removed, remaining 3 continue', () async {
      final code = generate6CharRoomCode();
      final createRes = await restPost('/rest/v1/rooms', {
        'name': 'Live 4P Match',
        'code': code,
        'host_id': userAId,
        'max_players': 4,
        'status': 'waiting',
      }, bearerToken: tokenA);
      final roomId = extractId(createRes['body']);

      // Join 4 seats
      await restPost('/rest/v1/room_players', {'room_id': roomId, 'user_id': userAId, 'seat_index': 0, 'is_host': true, 'is_ready': true}, bearerToken: tokenA);
      await restPost('/rest/v1/room_players', {'room_id': roomId, 'user_id': userBId, 'seat_index': 1, 'is_host': false, 'is_ready': true}, bearerToken: tokenB);
      await restPost('/rest/v1/room_players', {'room_id': roomId, 'user_id': userCId, 'seat_index': 2, 'is_host': false, 'is_ready': true}, bearerToken: tokenC);
      await restPost('/rest/v1/room_players', {'room_id': roomId, 'user_id': userDId, 'seat_index': 3, 'is_host': false, 'is_ready': true}, bearerToken: tokenD);

      final startRes = await restPost('/rest/v1/rpc/rpc_start_game', {'p_room_id': roomId}, bearerToken: tokenA);
      final gameId = (startRes['body'] as Map)['game_id'] as String;

      await restPost('/rest/v1/rpc/rpc_submit_board', {'p_game_id': gameId, 'p_board': dummyBoard}, bearerToken: tokenA);
      await restPost('/rest/v1/rpc/rpc_submit_board', {'p_game_id': gameId, 'p_board': dummyBoard}, bearerToken: tokenB);
      await restPost('/rest/v1/rpc/rpc_submit_board', {'p_game_id': gameId, 'p_board': dummyBoard}, bearerToken: tokenC);
      await restPost('/rest/v1/rpc/rpc_submit_board', {'p_game_id': gameId, 'p_board': dummyBoard}, bearerToken: tokenD);

      // Player D forfeits
      final forfeitRes = await restPost('/rest/v1/rpc/rpc_forfeit_match', {
        'p_game_id': gameId,
        'p_room_id': roomId,
      }, bearerToken: tokenD);
      expect(forfeitRes['statusCode'], equals(200));
      final fBody = forfeitRes['body'];
      expect(fBody['success'], isTrue);
      expect(fBody['match_completed'], isFalse, reason: '4-player match continues with remaining 3 players');
      expect(fBody['active_players_count'], equals(3));

      // Player D seat removed from room_players
      final rpRes = await restGet('/rest/v1/room_players?room_id=eq.$roomId', bearerToken: tokenA);
      final rpList = rpRes['body'] as List;
      expect(rpList.length, equals(3));
      expect(rpList.any((p) => p['user_id'] == userDId), isFalse);

      // Game remains in_progress
      final gRes = await restGet('/rest/v1/games?id=eq.$gameId', bearerToken: tokenA);
      expect((gRes['body'] as List).first['status'], equals('in_progress'));
    });

    test('4. Host forfeits during active game: host transfers to remaining player, match continues', () async {
      final code = generate6CharRoomCode();
      final createRes = await restPost('/rest/v1/rooms', {
        'name': 'Live Host Forfeit',
        'code': code,
        'host_id': userAId,
        'max_players': 3,
        'status': 'waiting',
      }, bearerToken: tokenA);
      final roomId = extractId(createRes['body']);

      await restPost('/rest/v1/room_players', {'room_id': roomId, 'user_id': userAId, 'seat_index': 0, 'is_host': true, 'is_ready': true}, bearerToken: tokenA);
      await restPost('/rest/v1/room_players', {'room_id': roomId, 'user_id': userBId, 'seat_index': 1, 'is_host': false, 'is_ready': true}, bearerToken: tokenB);
      await restPost('/rest/v1/room_players', {'room_id': roomId, 'user_id': userCId, 'seat_index': 2, 'is_host': false, 'is_ready': true}, bearerToken: tokenC);

      final startRes = await restPost('/rest/v1/rpc/rpc_start_game', {'p_room_id': roomId}, bearerToken: tokenA);
      final gameId = (startRes['body'] as Map)['game_id'] as String;

      await restPost('/rest/v1/rpc/rpc_submit_board', {'p_game_id': gameId, 'p_board': dummyBoard}, bearerToken: tokenA);
      await restPost('/rest/v1/rpc/rpc_submit_board', {'p_game_id': gameId, 'p_board': dummyBoard}, bearerToken: tokenB);
      await restPost('/rest/v1/rpc/rpc_submit_board', {'p_game_id': gameId, 'p_board': dummyBoard}, bearerToken: tokenC);

      // Host A forfeits
      final hostForfeitRes = await restPost('/rest/v1/rpc/rpc_forfeit_match', {
        'p_game_id': gameId,
        'p_room_id': roomId,
      }, bearerToken: tokenA);
      expect(hostForfeitRes['statusCode'], equals(200));

      // Host A removed from room_players
      final rpRes = await restGet('/rest/v1/room_players?room_id=eq.$roomId', bearerToken: tokenB);
      final rpList = rpRes['body'] as List;
      expect(rpList.length, equals(2));
      expect(rpList.any((p) => p['user_id'] == userAId), isFalse);

      // Verify rooms.host_id has transferred to an active remaining player (User B or User C)
      final roomRes = await restGet('/rest/v1/rooms?id=eq.$roomId', bearerToken: tokenB);
      final updatedRoom = (roomRes['body'] as List).first;
      expect(updatedRoom['host_id'], isNot(equals(userAId)));
      expect(updatedRoom['host_id'] == userBId || updatedRoom['host_id'] == userCId, isTrue);

      // Match remains active
      final gRes = await restGet('/rest/v1/games?id=eq.$gameId', bearerToken: tokenB);
      expect((gRes['body'] as List).first['status'], equals('in_progress'));
    });

    test('5. Repeated forfeit: idempotent, no duplicate history or stats', () async {
      final code = generate6CharRoomCode();
      final createRes = await restPost('/rest/v1/rooms', {
        'name': 'Live Idempotency',
        'code': code,
        'host_id': userAId,
        'max_players': 2,
        'status': 'waiting',
      }, bearerToken: tokenA);
      final roomId = extractId(createRes['body']);

      await restPost('/rest/v1/room_players', {'room_id': roomId, 'user_id': userAId, 'seat_index': 0, 'is_host': true, 'is_ready': true}, bearerToken: tokenA);
      await restPost('/rest/v1/room_players', {'room_id': roomId, 'user_id': userBId, 'seat_index': 1, 'is_host': false, 'is_ready': true}, bearerToken: tokenB);

      final startRes = await restPost('/rest/v1/rpc/rpc_start_game', {'p_room_id': roomId}, bearerToken: tokenA);
      final gameId = (startRes['body'] as Map)['game_id'] as String;

      await restPost('/rest/v1/rpc/rpc_submit_board', {'p_game_id': gameId, 'p_board': dummyBoard}, bearerToken: tokenA);
      await restPost('/rest/v1/rpc/rpc_submit_board', {'p_game_id': gameId, 'p_board': dummyBoard}, bearerToken: tokenB);

      // First forfeit
      final f1 = await restPost('/rest/v1/rpc/rpc_forfeit_match', {
        'p_game_id': gameId,
        'p_room_id': roomId,
      }, bearerToken: tokenB);
      expect(f1['statusCode'], equals(200));

      // Second forfeit (duplicate attempt)
      final f2 = await restPost('/rest/v1/rpc/rpc_forfeit_match', {
        'p_game_id': gameId,
        'p_room_id': roomId,
      }, bearerToken: tokenB);
      expect(f2['statusCode'], equals(200));
      expect(f2['body']['success'], isTrue);

      // Verify exactly 1 history row exists for this game_id
      final histRes = await restGet('/rest/v1/room_match_history?game_id=eq.$gameId', bearerToken: tokenA);
      final histList = histRes['body'] as List;
      expect(histList.length, equals(1), reason: 'Duplicate forfeit must not create duplicate history rows');
    });
  });
}
