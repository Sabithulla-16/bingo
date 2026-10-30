import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/authentication/domain/auth_state.dart';
import 'app_routes.dart';

/// Route guard evaluating authentication session status and directing routes accordingly.
class RouteGuards {
  const RouteGuards._();

  static String? authRedirect(
    BuildContext context,
    GoRouterState state,
    AppAuthState authState,
  ) {
    final location = state.matchedLocation;
    final isSplash = location == AppRoutes.splash;
    final isAuth = location == AppRoutes.auth;

    if (authState is AuthInitial) {
      // Allow splash screen to initialize session
      return isSplash ? null : AppRoutes.splash;
    }

    if (authState is Unauthenticated || authState is AuthFailure) {
      // Unauthenticated users are redirected to auth unless already on auth or splash
      if (isSplash || isAuth) return null;
      return AppRoutes.auth;
    }

    if (authState is Authenticated) {
      // Authenticated users should not revisit splash or auth
      if (isSplash || isAuth) {
        return AppRoutes.home;
      }
    }

    return null;
  }
}
