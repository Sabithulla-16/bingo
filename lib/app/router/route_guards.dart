import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/authentication/domain/auth_state.dart';
import 'app_routes.dart';

/// Route guard evaluating authentication session status and directing routes accordingly.
class RouteGuards {
  const RouteGuards._();

  static bool _isValidRedirect(String? redirect) {
    if (redirect == null || redirect.isEmpty) return false;
    // Must start with '/' and avoid open redirect protocols or malformed schemes
    if (!redirect.startsWith('/') || redirect.startsWith('//')) return false;
    final uri = Uri.tryParse(redirect);
    if (uri == null) return false;
    final path = uri.path;
    // Prevent redirect loops to auth or splash
    if (path == AppRoutes.auth || path == AppRoutes.splash) return false;
    return true;
  }

  static String? authRedirect(
    BuildContext context,
    GoRouterState state,
    AppAuthState authState,
  ) {
    final location = state.matchedLocation;
    final isSplash = location == AppRoutes.splash;
    final isAuth = location == AppRoutes.auth;

    // Splash screen controls its presentation and initialization on cold launch and logout
    if (isSplash) {
      return null;
    }

    if (authState is AuthInitial) {
      return AppRoutes.splash;
    }

    if (authState is Unauthenticated || authState is AuthFailure) {
      // Unauthenticated users are redirected to auth unless already on auth
      if (isAuth) return null;
      return AppRoutes.auth;
    }

    if (authState is Authenticated) {
      // Authenticated users should not revisit auth screen; restore intended destination if present
      if (isAuth) {
        final redirect = state.uri.queryParameters['redirect'] ?? (state.extra as String?);
        if (_isValidRedirect(redirect)) {
          return redirect;
        }
        return AppRoutes.home;
      }
    }

    // Guest users (AuthGuest) are permitted to visit AuthScreen to sign in or register,
    // or access permitted offline/single-player gameplay without being forced to Home.
    return null;
  }
}
