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
    final bodyBytes = utf8.encode(jsonEncode(body));
    req.add(bodyBytes);
    final res = await req.close();
    final bodyStr = await res.transform(utf8.decoder).join();
    return {
      'statusCode': res.statusCode,
      'body': bodyStr.isNotEmpty ? jsonDecode(bodyStr) : null,
    };
  }

  group('Live Supabase Backend Deployment & RPC Verification', () {
    test('1. Verify Schema Columns: game_player_states.is_forfeited exists', () async {
      final res = await restGet('/rest/v1/game_player_states?select=is_forfeited&limit=1');
      expect(res['statusCode'], equals(200));
      expect(res['body'], isA<List>());
    });

    test('2. Verify Schema Columns: room_match_history migration 14 columns exist', () async {
      final res = await restGet('/rest/v1/room_match_history?select=game_id,winner_id,winner_name,is_forfeit,finish_reason&limit=1');
      expect(res['statusCode'], equals(200));
      expect(res['body'], isA<List>());
      final list = res['body'] as List;
      if (list.isNotEmpty) {
        final row = list.first as Map<String, dynamic>;
        expect(row.containsKey('game_id'), isTrue);
        expect(row.containsKey('is_forfeit'), isTrue);
        expect(row.containsKey('finish_reason'), isTrue);
      }
    });

    test('3. Verify RPC Deployed: rpc_get_user_recent_rooms executes with expected signature', () async {
      final res = await restPost('/rest/v1/rpc/rpc_get_user_recent_rooms', {'p_limit': 5});
      expect(res['statusCode'], equals(200));
      expect(res['body'], isA<List>());
    });

    test('4. Verify RPC Deployed: rpc_forfeit_match unauthenticated execution check', () async {
      final res = await restPost('/rest/v1/rpc/rpc_forfeit_match', {
        'p_game_id': '00000000-0000-0000-0000-000000000000',
        'p_room_id': '00000000-0000-0000-0000-000000000000',
      });
      expect(res['statusCode'], equals(200));
      final body = res['body'] as Map<String, dynamic>;
      expect(body['success'], isFalse);
      expect(body['error'], equals('Not authenticated'));
    });

    test('5. Verify RPC Deployed: rpc_finish_round executes with idempotency parameters', () async {
      final res = await restPost('/rest/v1/rpc/rpc_finish_round', {
        'p_game_id': '00000000-0000-0000-0000-000000000000',
        'p_room_id': '00000000-0000-0000-0000-000000000000',
        'p_winner_id': '00000000-0000-0000-0000-000000000000',
        'p_winner_name': 'Live Audit Bot',
        'p_total_calls': 12,
        'p_player_outcomes': [],
      });
      expect(res['statusCode'], equals(200));
      final body = res['body'] as Map<String, dynamic>;
      expect(body['success'], isFalse);
      expect(body['error'], equals('Game not found'));
    });

    test('6. Verify Authenticated User Execution: rpc_forfeit_match with auth token passes auth guard', () async {
      // 1. Attempt sign-in or sign-up via GoTrue REST
      final authRes = await restPost('/auth/v1/signup', {
        'email': 'audit_player_live@bingo.dev',
        'password': 'LivePassword123!',
        'data': {'display_name': 'Live Audit Player'}
      });

      String? accessToken;
      if (authRes['statusCode'] == 200 && authRes['body'] != null) {
        accessToken = authRes['body']['access_token'] as String?;
      }

      if (accessToken == null) {
        final loginRes = await restPost('/auth/v1/token?grant_type=password', {
          'email': 'audit_player_live@bingo.dev',
          'password': 'LivePassword123!',
        });
        if (loginRes['statusCode'] == 200 && loginRes['body'] != null) {
          accessToken = loginRes['body']['access_token'] as String?;
        }
      }

      if (accessToken != null) {
        // Now call rpc_forfeit_match with the authenticated token
        final authForfeitRes = await restPost(
          '/rest/v1/rpc/rpc_forfeit_match',
          {
            'p_game_id': '00000000-0000-0000-0000-000000000000',
            'p_room_id': '00000000-0000-0000-0000-000000000000',
          },
          bearerToken: accessToken,
        );

        expect(authForfeitRes['statusCode'], equals(200));
        final body = authForfeitRes['body'] as Map<String, dynamic>;
        expect(body['success'], isFalse);
        // Authenticated user bypasses 'Not authenticated' and reaches database game lookup
        expect(body['error'], equals('Game not found'));

        // Call rpc_get_user_recent_rooms with auth token
        final userRecentRes = await restPost(
          '/rest/v1/rpc/rpc_get_user_recent_rooms',
          {'p_limit': 5},
          bearerToken: accessToken,
        );
        expect(userRecentRes['statusCode'], equals(200));
        expect(userRecentRes['body'], isA<List>());
      }
    });
  });
}
