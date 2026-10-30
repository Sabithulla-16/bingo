import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/bingo_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/supabase/supabase_provider.dart';

enum AuthMode { register, signIn, forgotPassword }

/// Authentication & Registration Screen (Stitch Screen ID: `152948b85345400fb54e55f8ba807a09`)
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  AuthMode _authMode = AuthMode.register;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please enter both email and password.';
      });
      return;
    }

    try {
      final authNotifier = ref.read(authStateProvider.notifier);
      if (_authMode == AuthMode.register) {
        if (password != _confirmPasswordController.text) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Passwords do not match.';
          });
          return;
        }
        await authNotifier.signUp(
          email: email,
          password: password,
          displayName: name.isNotEmpty ? name : 'Player',
        );
      } else if (_authMode == AuthMode.signIn) {
        await authNotifier.signIn(email: email, password: password);
      } else if (_authMode == AuthMode.forgotPassword) {
        final authRepo = ref.read(authRepositoryProvider);
        await authRepo.sendPasswordReset(email);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password reset instructions sent to your email.'),
            ),
          );
          setState(() {
            _authMode = AuthMode.signIn;
          });
        }
      }

      if (mounted && _authMode != AuthMode.forgotPassword) {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Column(
          children: [
            const BingoLogo(fontSize: 32),
            const SizedBox(height: 16),
            const StatusBadge(label: 'WELCOME TO BINGO', icon: Icons.stars),
            const SizedBox(height: 12),
            Text(
              _authMode == AuthMode.register
                  ? "Let's get you started!"
                  : _authMode == AuthMode.signIn
                  ? 'Welcome back!'
                  : 'Reset your password',
              textAlign: TextAlign.center,
              style: AppTypography.headlineLgMobile,
            ),
            const SizedBox(height: 4),
            Text(
              _authMode == AuthMode.register
                  ? 'Create your account and start playing BINGO with friends.'
                  : _authMode == AuthMode.signIn
                  ? 'Sign in to access your boards, rooms, and social stats.'
                  : "We'll send secure verification instructions to your email.",
              textAlign: TextAlign.center,
              style: AppTypography.bodySm,
            ),
            const SizedBox(height: 20),
            // Segmented mode switcher
            if (_authMode != AuthMode.forgotPassword)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: AppRadii.roundedFull,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () =>
                            setState(() => _authMode = AuthMode.register),
                        borderRadius: AppRadii.roundedFull,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _authMode == AuthMode.register
                                ? AppColors.surface
                                : Colors.transparent,
                            borderRadius: AppRadii.roundedFull,
                            boxShadow: _authMode == AuthMode.register
                                ? const [
                                    BoxShadow(
                                      color: AppColors.cardShadowColor,
                                      blurRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Create Account',
                            style: AppTypography.labelMd.copyWith(
                              color: _authMode == AuthMode.register
                                  ? AppColors.primaryNavy
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () =>
                            setState(() => _authMode = AuthMode.signIn),
                        borderRadius: AppRadii.roundedFull,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _authMode == AuthMode.signIn
                                ? AppColors.surface
                                : Colors.transparent,
                            borderRadius: AppRadii.roundedFull,
                            boxShadow: _authMode == AuthMode.signIn
                                ? const [
                                    BoxShadow(
                                      color: AppColors.cardShadowColor,
                                      blurRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Sign In',
                            style: AppTypography.labelMd.copyWith(
                              color: _authMode == AuthMode.signIn
                                  ? AppColors.primaryNavy
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            // Form Card
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.errorRed.withAlpha(25),
                        borderRadius: AppRadii.roundedMd,
                      ),
                      child: Text(
                        _errorMessage!,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.errorRed,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_authMode == AuthMode.register) ...[
                    AppTextField(
                      label: 'Your Name',
                      hintText: 'Enter your display name',
                      controller: _nameController,
                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                      maxLength: 20,
                    ),
                    const SizedBox(height: 14),
                  ],
                  AppTextField(
                    label: 'Email Address',
                    hintText: 'Enter your email',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(Icons.mail_outline, size: 20),
                  ),
                  if (_authMode != AuthMode.forgotPassword) ...[
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'Password',
                      hintText: _authMode == AuthMode.register
                          ? 'Create a password'
                          : 'Enter your password',
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                  ],
                  if (_authMode == AuthMode.register) ...[
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'Confirm Password',
                      hintText: 'Re-enter your password',
                      controller: _confirmPasswordController,
                      obscureText: _obscurePassword,
                      prefixIcon: const Icon(Icons.lock_reset, size: 20),
                    ),
                  ],
                  if (_authMode == AuthMode.signIn) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () =>
                            setState(() => _authMode = AuthMode.forgotPassword),
                        child: Text(
                          'Forgot Password?',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.primaryCoral,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: _authMode == AuthMode.register
                        ? 'Create Account'
                        : _authMode == AuthMode.signIn
                        ? 'Sign In'
                        : 'Send Reset Link',
                    icon: Icons.arrow_forward,
                    isLoading: _isLoading,
                    onPressed: _handleSubmit,
                  ),
                  if (_authMode == AuthMode.forgotPassword) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () =>
                          setState(() => _authMode = AuthMode.signIn),
                      child: Text(
                        'Return to Sign In',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.primaryNavy,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
