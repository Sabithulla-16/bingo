import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:bingo/core/errors/app_error_code.dart';
import 'package:bingo/core/errors/app_error.dart';
import 'package:bingo/core/errors/error_mapper.dart';

void main() {
  group('ErrorMapper Tests', () {
    test('maps AppError directly without remapping', () {
      final custom = AppError(
        code: AppErrorCode.numberAlreadyCalled,
        message: 'That number has already been called.',
      );
      final mapped = ErrorMapper.map(custom);
      expect(mapped.code, equals(AppErrorCode.numberAlreadyCalled));
      expect(mapped.message, equals('That number has already been called.'));
    });

    group('Network & Connectivity Errors', () {
      test('maps SocketException to networkUnavailable', () {
        const error = SocketException(
          'OS Error: No address associated with hostname',
        );
        final mapped = ErrorMapper.map(error);
        expect(mapped.code, equals(AppErrorCode.networkUnavailable));
        expect(
          mapped.message,
          equals(
            'Unable to connect. Check your internet connection and try again.',
          ),
        );
        expect(mapped.recoveryActionLabel, equals('RETRY'));
      });

      test(
        'maps ClientException with failed host lookup to networkUnavailable',
        () {
          const error =
              "ClientException with Socket Failed host lookup: 'pqkrqppxbnrjcgxvmogn.supabase.co' (OS Error: No address associated with hostname, errno = 7)";
          final mapped = ErrorMapper.map(error);
          expect(mapped.code, equals(AppErrorCode.networkUnavailable));
          expect(
            mapped.message,
            equals(
              'Unable to connect. Check your internet connection and try again.',
            ),
          );
        },
      );

      test('maps TimeoutException to timeout error', () {
        final error = TimeoutException('Connection timed out after 30 seconds');
        final mapped = ErrorMapper.map(error);
        expect(mapped.code, equals(AppErrorCode.timeout));
        expect(
          mapped.message,
          equals('This is taking longer than expected. Please try again.'),
        );
        expect(mapped.recoveryActionLabel, equals('RETRY'));
      });
    });

    group('Authentication Errors', () {
      test('maps invalid login credentials', () {
        final error = sb.AuthException('Invalid login credentials');
        final mapped = ErrorMapper.map(error);
        expect(mapped.code, equals(AppErrorCode.invalidCredentials));
        expect(
          mapped.message,
          equals('Incorrect email or password. Please try again.'),
        );
      });

      test('maps email already registered', () {
        final error = sb.AuthException('User already registered');
        final mapped = ErrorMapper.map(error);
        expect(mapped.code, equals(AppErrorCode.emailAlreadyRegistered));
        expect(
          mapped.message,
          equals(
            'An account with this email already exists. Try signing in instead.',
          ),
        );
      });

      test('maps weak password', () {
        final error = sb.AuthException(
          'Password should be at least 6 characters',
        );
        final mapped = ErrorMapper.map(error);
        expect(mapped.code, equals(AppErrorCode.weakPassword));
        expect(
          mapped.message,
          equals(
            'Your password is too weak. Please choose a stronger password.',
          ),
        );
      });

      test('maps unconfirmed/unverified email', () {
        final error = sb.AuthException('Email not confirmed');
        final mapped = ErrorMapper.map(error);
        expect(mapped.code, equals(AppErrorCode.emailNotVerified));
        expect(
          mapped.message,
          equals('Please verify your email address before signing in.'),
        );
      });

      test('maps rate limiting / too many requests', () {
        final error = sb.AuthException('rate limit exceeded. wait 60 seconds');
        final mapped = ErrorMapper.map(error);
        expect(mapped.code, equals(AppErrorCode.tooManyAttempts));
        expect(
          mapped.message,
          equals(
            'Too many attempts. Please wait a moment before trying again.',
          ),
        );
      });

      test('maps session expired or invalid token', () {
        final error = sb.AuthException('JWT expired');
        final mapped = ErrorMapper.map(error);
        expect(mapped.code, equals(AppErrorCode.sessionExpired));
        expect(
          mapped.message,
          equals('Your session has expired. Please sign in again.'),
        );
      });
    });

    group('Gameplay Errors', () {
      test('maps number already called', () {
        const error = 'number 14 has already been called in this round';
        final mapped = ErrorMapper.map(error);
        expect(mapped.code, equals(AppErrorCode.numberAlreadyCalled));
        expect(mapped.message, equals('That number has already been called.'));
      });

      test('maps not your turn', () {
        const error = 'it is not your turn to call a number';
        final mapped = ErrorMapper.map(error);
        expect(mapped.code, equals(AppErrorCode.notYourTurn));
        expect(mapped.message, equals("It's not your turn yet."));
      });

      test('maps line not complete', () {
        const error = 'this line is not complete';
        final mapped = ErrorMapper.map(error);
        expect(mapped.code, equals(AppErrorCode.lineIncomplete));
        expect(mapped.message, equals("This line isn't complete yet."));
      });

      test('maps line already claimed', () {
        const error = 'line row_1 already claimed';
        final mapped = ErrorMapper.map(error);
        expect(mapped.code, equals(AppErrorCode.lineAlreadyClaimed));
        expect(mapped.message, equals("You've already claimed this line."));
      });

      test('maps round ended', () {
        const error = 'the game has ended';
        final mapped = ErrorMapper.map(error);
        expect(mapped.code, equals(AppErrorCode.roundAlreadyEnded));
        expect(mapped.message, equals('The round has already ended.'));
      });
    });

    group('Multiplayer Room Errors', () {
      test('maps room not found', () {
        const error = 'room not found with provided code';
        final mapped = ErrorMapper.map(error);
        expect(mapped.code, equals(AppErrorCode.roomNotFound));
        expect(
          mapped.message,
          equals("We couldn't find that room. Check the code and try again."),
        );
      });

      test('maps room is full', () {
        const error = 'room is full';
        final mapped = ErrorMapper.map(error);
        expect(mapped.code, equals(AppErrorCode.roomFull));
        expect(mapped.message, equals('This room is full.'));
      });

      test('maps room expired or closed', () {
        const error = 'room expired and cannot be rejoined';
        final mapped = ErrorMapper.map(error);
        expect(mapped.code, equals(AppErrorCode.roomExpired));
        expect(mapped.message, equals('This room is no longer available.'));
      });

      test('maps connection lost in game', () {
        const error = 'connection lost to multiplayer channel';
        final mapped = ErrorMapper.map(error);
        expect(mapped.code, equals(AppErrorCode.connectionLost));
        expect(
          mapped.message,
          equals('Connection lost. Trying to reconnect...'),
        );
      });

      test('maps player kicked or removed', () {
        const error = 'player was kicked from lobby';
        final mapped = ErrorMapper.map(error);
        expect(mapped.code, equals(AppErrorCode.playerRemoved));
        expect(
          mapped.message,
          equals('You are no longer a member of this room.'),
        );
      });
    });

    group('Database and Fallback Errors', () {
      test('maps database load failure without leaking schema', () {
        const error = 'could not load profile data from pgrst116';
        final mapped = ErrorMapper.map(error);
        expect(mapped.code, equals(AppErrorCode.loadFailed));
        expect(
          mapped.message,
          equals("We couldn't load this information. Please try again."),
        );
        expect(mapped.recoveryActionLabel, equals('RELOAD'));
      });

      test('maps unknown exception to generic friendly message', () {
        final error = FormatException('unexpected token at 0x9328');
        final mapped = ErrorMapper.map(error);
        expect(mapped.code, equals(AppErrorCode.unknown));
        expect(
          mapped.message,
          equals("We're having trouble connecting. Please try again."),
        );
        expect(mapped.recoveryActionLabel, equals('TRY AGAIN'));
      });
    });
  });
}
