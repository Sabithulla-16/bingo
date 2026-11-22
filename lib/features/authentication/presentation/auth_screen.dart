import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/bingo_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/supabase/supabase_provider.dart';
import '../../profile/domain/player_profile.dart';
import '../../splash/presentation/widgets/splash_animated_board.dart';

enum AuthMode { register, signIn, forgotPassword }

/// Authentication & Registration Screen (Stitch Screen ID: `152948b85345400fb54e55f8ba807a09`)
class AuthScreen extends ConsumerStatefulWidget {
  final AuthMode initialMode;
  final String? redirectUrl;

  const AuthScreen({
    super.key,
    this.initialMode = AuthMode.register,
    this.redirectUrl,
  });

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late AuthMode _authMode;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _rememberMe = true;
  bool _agreedToTerms = true;
  String? _errorMessage;
  bool _resetInstructionsSent = false;

  PlayerProfile? _registeredProfileForModal;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _authMode = widget.initialMode;
    _passwordController.addListener(_onFieldChanged);
    _confirmPasswordController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _nameController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onFieldChanged);
    _confirmPasswordController.removeListener(_onFieldChanged);
    _emailController.removeListener(_onFieldChanged);
    _nameController.removeListener(_onFieldChanged);

    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _isEmailValid {
    final email = _emailController.text.trim();
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return regex.hasMatch(email);
  }

  int get _passwordStrength {
    final pwd = _passwordController.text;
    if (pwd.isEmpty) return 0;
    int score = 0;
    if (pwd.length >= 6) score++;
    if (pwd.length >= 8 && RegExp(r'[0-9]').hasMatch(pwd)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(pwd)) score++;
    return score; // 0, 1, 2, or 3
  }

  String get _passwordStrengthLabel {
    switch (_passwordStrength) {
      case 1:
        return 'Weak';
      case 2:
        return 'Good';
      case 3:
        return 'Strong';
      default:
        return 'Too short';
    }
  }

  Color get _passwordStrengthColor {
    switch (_passwordStrength) {
      case 1:
        return AppColors.primaryCoral;
      case 2:
        return AppColors.softYellow;
      case 3:
        return AppColors.readyGreen;
      default:
        return AppColors.textTertiary;
    }
  }

  bool get _isPasswordMatch {
    final p1 = _passwordController.text;
    final p2 = _confirmPasswordController.text;
    return p1.isNotEmpty && p1 == p2;
  }

  String _formatErrorMessage(Object error, {String operation = 'auth'}) {
    final appError = ErrorHandler.handle(
      error,
      operation: operation,
      presentation: ErrorPresentation.silent,
    );
    return appError.message;
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (_authMode == AuthMode.forgotPassword) {
      if (!_isEmailValid) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Please enter a valid email address.';
        });
        return;
      }

      try {
        final authRepo = ref.read(authRepositoryProvider);
        await authRepo.sendPasswordReset(email);
        setState(() {
          _resetInstructionsSent = true;
        });
      } catch (e) {
        setState(() {
          _errorMessage = _formatErrorMessage(e);
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please fill in all required fields.';
      });
      return;
    }

    if (!_isEmailValid) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please enter a valid email address format.';
      });
      return;
    }

    if (_authMode == AuthMode.register) {
      if (!_agreedToTerms) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'You must agree to the Terms of Service & Privacy Policy.';
        });
        return;
      }

      if (password != _confirmPasswordController.text) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Passwords do not match.';
        });
        return;
      }

      if (password.length < 6) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Password must be at least 6 characters.';
        });
        return;
      }
    }

    try {
      final authNotifier = ref.read(authStateProvider.notifier);
      if (_authMode == AuthMode.register) {
        await authNotifier.signUp(
          email: email,
          password: password,
          displayName: name.isNotEmpty ? name : 'Player',
        );

        final profile = ref.read(currentProfileProvider);
        if (mounted && profile != null) {
          final target = widget.redirectUrl;
          if (target != null &&
              target.isNotEmpty &&
              target != AppRoutes.auth &&
              target != AppRoutes.splash) {
            context.go(target);
            return;
          }
          setState(() {
            _registeredProfileForModal = profile;
          });
          return;
        }
      } else {
        await authNotifier.signIn(
          email: email,
          password: password,
          rememberMe: _rememberMe,
        );
      }

      if (mounted) {
        final target = widget.redirectUrl;
        if (target != null &&
            target.isNotEmpty &&
            target != AppRoutes.auth &&
            target != AppRoutes.splash) {
          context.go(target);
        } else {
          context.go(AppRoutes.home);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = _formatErrorMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGuestPlay() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final name = _nameController.text.trim();
      await ref
          .read(authStateProvider.notifier)
          .signInAsGuest(displayName: name.isNotEmpty ? name : 'Guest Valtry');

      final profile = ref.read(currentProfileProvider);
      if (mounted && profile != null) {
        setState(() {
          _registeredProfileForModal = profile;
        });
      } else if (mounted) {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      setState(() {
        _errorMessage = _formatErrorMessage(e);
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
    return Stack(
      children: [
        ResponsiveScaffold(
          appBar: Navigator.of(context).canPop()
              ? AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.primaryNavy,
                    ),
                    tooltip: 'Back',
                    onPressed: () => context.pop(),
                  ),
                )
              : null,
          body: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Column(
              children: [
                const BingoLogo(fontSize: 36),
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
                      ? 'Sign in to continue your BINGO journey.'
                      : "Enter your registered email address and we'll send you instructions to reset your password.",
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySm,
                ),
                const SizedBox(height: 18),

                // Animated 5x5 Bingo Board with Diagonal Strikethrough (matching Splash screen)
                const SplashAnimatedBingoBoard(size: 240.0),

                const SizedBox(height: 20),

                // Pill Segmented Switcher (Hidden in Forgot Password mode)
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
                            onTap: () => setState(() {
                              _authMode = AuthMode.register;
                              _errorMessage = null;
                            }),
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
                            onTap: () => setState(() {
                              _authMode = AuthMode.signIn;
                              _errorMessage = null;
                            }),
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

                const SizedBox(height: 18),

                // Main Form AppCard
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.errorRed.withAlpha(25),
                            borderRadius: AppRadii.roundedMd,
                            border: Border.all(
                              color: AppColors.errorRed.withAlpha(80),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.errorRed,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: AppTypography.bodySm.copyWith(
                                    color: AppColors.errorRed,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Register Form Fields
                      if (_authMode == AuthMode.register) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'YOUR NAME',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '${_nameController.text.length}/20',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        AppTextField(
                          hintText: 'Enter your display name',
                          controller: _nameController,
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            size: 20,
                          ),
                          maxLength: 20,
                        ),
                        Text(
                          'Visible to other players in multiplayer rooms',
                          style: AppTypography.bodySm.copyWith(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Email Field
                      Text(
                        'EMAIL ADDRESS',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AppTextField(
                        hintText: 'Enter your email',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: const Icon(Icons.mail_outline, size: 20),
                        suffixIcon: _emailController.text.isNotEmpty
                            ? Icon(
                                _isEmailValid
                                    ? Icons.check_circle
                                    : Icons.cancel_outlined,
                                color: _isEmailValid
                                    ? AppColors.readyGreen
                                    : AppColors.primaryCoral,
                                size: 18,
                              )
                            : null,
                      ),

                      // Password Fields
                      if (_authMode != AuthMode.forgotPassword) ...[
                        const SizedBox(height: 14),
                        Text(
                          'PASSWORD',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AppTextField(
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

                        // Password strength bar (on register)
                        if (_authMode == AuthMode.register &&
                            _passwordController.text.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: AppRadii.roundedFull,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          height: 4,
                                          color: _passwordStrength >= 1
                                              ? _passwordStrengthColor
                                              : AppColors.surfaceContainerHigh,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Container(
                                          height: 4,
                                          color: _passwordStrength >= 2
                                              ? _passwordStrengthColor
                                              : AppColors.surfaceContainerHigh,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Container(
                                          height: 4,
                                          color: _passwordStrength >= 3
                                              ? _passwordStrengthColor
                                              : AppColors.surfaceContainerHigh,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _passwordStrengthLabel,
                                style: AppTypography.labelSm.copyWith(
                                  color: _passwordStrengthColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],

                      // Confirm Password (on register)
                      if (_authMode == AuthMode.register) ...[
                        const SizedBox(height: 14),
                        Text(
                          'CONFIRM PASSWORD',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AppTextField(
                          hintText: 'Re-enter your password',
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          prefixIcon: const Icon(Icons.lock_reset, size: 20),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_confirmPasswordController.text.isNotEmpty)
                                Icon(
                                  _isPasswordMatch
                                      ? Icons.check_circle
                                      : Icons.cancel_outlined,
                                  color: _isPasswordMatch
                                      ? AppColors.readyGreen
                                      : AppColors.primaryCoral,
                                  size: 18,
                                ),
                              IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                  () => _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Checkbox(
                              value: _agreedToTerms,
                              activeColor: AppColors.primaryCoral,
                              onChanged: (val) =>
                                  setState(() => _agreedToTerms = val ?? false),
                            ),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  text: 'I agree to the ',
                                  style: AppTypography.bodySm.copyWith(
                                    fontSize: 12,
                                  ),
                                  children: [
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: GestureDetector(
                                        onTap: () => _showTermsDialog(context),
                                        child: Text(
                                          'Terms of Service',
                                          style: AppTypography.bodySm.copyWith(
                                            fontSize: 12,
                                            color: AppColors.primaryCoral,
                                            fontWeight: FontWeight.bold,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const TextSpan(text: ' and '),
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: GestureDetector(
                                        onTap: () =>
                                            _showPrivacyPolicyDialog(context),
                                        child: Text(
                                          'Privacy Policy',
                                          style: AppTypography.bodySm.copyWith(
                                            fontSize: 12,
                                            color: AppColors.primaryCoral,
                                            fontWeight: FontWeight.bold,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const TextSpan(text: '.'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Remember Me & Forgot Password (on sign in)
                      if (_authMode == AuthMode.signIn) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _rememberMe,
                                  activeColor: AppColors.primaryCoral,
                                  onChanged: (val) =>
                                      setState(() => _rememberMe = val ?? true),
                                ),
                                Text(
                                  'Remember me',
                                  style: AppTypography.bodySm,
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () => setState(() {
                                _authMode = AuthMode.forgotPassword;
                                _resetInstructionsSent = false;
                                _errorMessage = null;
                              }),
                              child: Text(
                                'Forgot Password?',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.primaryCoral,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Forgot Password Status Box
                      if (_authMode == AuthMode.forgotPassword &&
                          _resetInstructionsSent) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.lightLavender,
                            borderRadius: AppRadii.roundedMd,
                            border: Border.all(
                              color: AppColors.primaryNavy.withAlpha(30),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.mark_email_read,
                                    color: AppColors.primaryCoral,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Instructions Dispatched',
                                    style: AppTypography.labelMd.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryNavy,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'A password reset link was dispatched for ${_emailController.text.trim()}.',
                                style: AppTypography.bodySm.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '• Check your Inbox and Spam / Junk folder.\n'
                                '• Rate limit notice: Free Supabase tiers limit reset emails to 3 per hour. If you recently sent a request, please allow a few minutes.\n'
                                '• If you used guest mode or need immediate access, tap "Continue as Guest" below.',
                                style: AppTypography.bodySm.copyWith(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Primary Action CTA Button
                      PrimaryButton(
                        label: _authMode == AuthMode.register
                            ? 'Create Account'
                            : _authMode == AuthMode.signIn
                            ? 'Sign In'
                            : 'Send Reset Link',
                        icon: _authMode == AuthMode.forgotPassword
                            ? Icons.send
                            : Icons.arrow_forward,
                        isLoading: _isLoading,
                        onPressed: _handleSubmit,
                      ),

                      // Return to Sign In (from forgot password)
                      if (_authMode == AuthMode.forgotPassword) ...[
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _authMode = AuthMode.signIn;
                            _errorMessage = null;
                          }),
                          icon: const Icon(
                            Icons.arrow_back,
                            size: 16,
                            color: AppColors.primaryNavy,
                          ),
                          label: Text(
                            'Return to Sign In',
                            style: AppTypography.labelMd.copyWith(
                              color: AppColors.primaryNavy,
                            ),
                          ),
                        ),
                      ],

                      // Guest Mode / Quick Play Button
                      if (_authMode != AuthMode.forgotPassword) ...[
                        const SizedBox(height: 12),
                        SecondaryButton(
                          label: 'Continue as Guest',
                          icon: Icons.flash_on_rounded,
                          onPressed: _isLoading ? null : _handleGuestPlay,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Security & Privacy Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Secure end-to-end authentication • Privacy guaranteed',
                        style: AppTypography.bodySm.copyWith(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Registration / Welcome Success Celebration Modal
        if (_registeredProfileForModal != null)
          _buildSuccessCelebrationModal(_registeredProfileForModal!),
      ],
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedXl),
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            const Icon(Icons.gavel_rounded, color: AppColors.primaryCoral),
            const SizedBox(width: 8),
            Text('Terms of Service', style: AppTypography.headlineSm),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to BINGO! By creating an account or playing as a guest, you agree to these Terms of Service.',
                  style: AppTypography.bodySm,
                ),
                const SizedBox(height: 12),
                _buildPolicySection(
                  '1. Fair Play & Gameplay Integrity',
                  'Players must play fairly without using automated scripts, third-party tampering, or exploiting synchronization latencies. All calls and line claims are verified by the game engine.',
                ),
                _buildPolicySection(
                  '2. Virtual Chips & Rewards',
                  'Chips are virtual game items with no cash or real-world monetary value. Chips cannot be traded, sold, or redeemed for currency and are used solely for in-game room stakes and friendly competition.',
                ),
                _buildPolicySection(
                  '3. Multiplayer Rooms & Conduct',
                  'Custom room hosts and players must maintain respectful conduct. Harassment, offensive usernames, or disruptive behavior may lead to temporary or permanent multiplayer suspension.',
                ),
                _buildPolicySection(
                  '4. Account Responsibility',
                  'You are responsible for maintaining the security of your login credentials and room codes. We are not liable for unauthorized access resulting from shared credentials.',
                ),
                _buildPolicySection(
                  '5. Modifications & Updates',
                  'We reserve the right to update gameplay rules, scoring algorithms, and terms of service to enhance multiplayer balance and player experience.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              foregroundColor: AppColors.textLight,
              shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedMd),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedXl),
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            const Icon(
              Icons.privacy_tip_outlined,
              color: AppColors.primaryCoral,
            ),
            const SizedBox(width: 8),
            Text('Privacy Policy', style: AppTypography.headlineSm),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your privacy is essential to us. This policy details how BINGO handles your information.',
                  style: AppTypography.bodySm,
                ),
                const SizedBox(height: 12),
                _buildPolicySection(
                  '1. Information We Collect',
                  '• Profile data: Display name, email address, chosen avatar icon and color.\n• Game stats: Matches played, victory count, current win streaks, and chip balances.\n• Session data: Real-time room presence and game board state.',
                ),
                _buildPolicySection(
                  '2. Purpose of Collection',
                  'We use this data to deliver real-time multiplayer gameplay, match leaderboards, player stats, and secure authentication.',
                ),
                _buildPolicySection(
                  '3. Data Protection & Encryption',
                  'User passwords and sensitive credentials are encrypted using industry-standard hashing. Match state and profile records are secured via Supabase Row-Level Security (RLS) policies.',
                ),
                _buildPolicySection(
                  '4. Zero Third-Party Monetization',
                  'We do not sell, rent, or trade your personal information, email address, or gameplay statistics to advertisers or third-party data aggregators.',
                ),
                _buildPolicySection(
                  '5. Your Rights & Data Deletion',
                  'You may modify your display name and avatar at any time in the Profile section, or request account and profile deletion by contacting support.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              foregroundColor: AppColors.textLight,
              shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedMd),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicySection(String heading, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: AppTypography.labelMd.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  /// Success Celebration Modal Overlay (Stitch Screen 2 specification)
  Widget _buildSuccessCelebrationModal(PlayerProfile profile) {
    return Container(
      color: AppColors.scrimOverlayColor,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.roundedXl,
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.primaryCoral,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.celebration_rounded,
                  color: AppColors.textLight,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              const StatusBadge(
                label: 'READY TO PLAY',
                icon: Icons.verified_rounded,
              ),
              const SizedBox(height: 10),
              Text(
                'Welcome to BINGO!',
                style: AppTypography.headlineMd,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Your player credentials have been verified and your profile is initialized.',
                style: AppTypography.bodySm,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),

              // Profile snapshot container
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: AppRadii.roundedLg,
                ),
                child: Column(
                  children: [
                    _buildSnapshotRow(
                      'PLAYER ID',
                      profile.shortPlayerId,
                      AppColors.primaryCoral,
                    ),
                    const Divider(height: 16),
                    _buildSnapshotRow(
                      'CODENAME',
                      profile.displayName,
                      AppColors.primaryNavy,
                    ),
                    const Divider(height: 16),
                    _buildSnapshotRow(
                      'STARTING BALANCE',
                      '${profile.chips} Chips',
                      AppColors.primaryNavy,
                      icon: Icons.token_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: widget.redirectUrl != null ? 'Continue to Game' : 'Enter Game Lobby',
                icon: Icons.sports_esports_rounded,
                onPressed: () {
                  setState(() {
                    _registeredProfileForModal = null;
                  });
                  final target = widget.redirectUrl;
                  if (target != null &&
                      target.isNotEmpty &&
                      target != AppRoutes.auth &&
                      target != AppRoutes.splash) {
                    context.go(target);
                  } else {
                    context.go(AppRoutes.home);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSnapshotRow(
    String label,
    String value,
    Color valueColor, {
    IconData? icon,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.labelSm.copyWith(color: AppColors.textSecondary),
        ),
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: AppColors.softYellow),
              const SizedBox(width: 4),
            ],
            Text(
              value,
              style: AppTypography.labelMd.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
