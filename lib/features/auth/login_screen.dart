import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/platform_service.dart';
import '../../shared/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  DateTime? _lastObscureToggle;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  // TV focus nodes
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _eyeFocus = FocusNode();
  final _loginBtnFocus = FocusNode();
  final _registerBtnFocus = FocusNode();
  // Listener node for the form-level KeyboardListener — stored to avoid leaks.
  final _formListenerFocus = FocusNode(skipTraversal: true, canRequestFocus: false);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _fadeCtrl.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _eyeFocus.dispose();
    _loginBtnFocus.dispose();
    _registerBtnFocus.dispose();
    _formListenerFocus.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    required bool isTV,
  }) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isTV ? 18 : 14,
      ),
      prefixIcon: Icon(icon, color: AppTheme.textMuted, size: isTV ? 24 : 22),
      prefixIconConstraints: BoxConstraints(
        minWidth: isTV ? 52 : 48,
        minHeight: isTV ? 52 : 48,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final auth = context.read<AuthProvider>();
    await auth.login(_usernameCtrl.text.trim(), _passwordCtrl.text.trim());
    if (!mounted) return;
    if (auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error!),
          backgroundColor: AppTheme.danger,
        ),
      );
      auth.clearError();
    }
  }

  void _toggleObscure() {
    // Remote OK can arrive twice; without this the eye toggles open then shut.
    final now = DateTime.now();
    final last = _lastObscureToggle;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 400)) {
      return;
    }
    _lastObscureToggle = now;
    setState(() => _obscure = !_obscure);
  }

  @override
  Widget build(BuildContext context) {
    final isTV = PlatformService.isTV;
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Hero background image ──────────────────────────────────────
          Image.asset(
            AppTheme.heroBg,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          // ── Dark gradient overlay ──────────────────────────────────────
          DecoratedBox(decoration: BoxDecoration(gradient: AppTheme.heroGradient)),
          // ── Content ───────────────────────────────────────────────────
          FadeTransition(
            opacity: _fadeAnim,
            child: isTV ? _buildTvLayout() : _buildPhoneLayout(),
          ),
        ],
      ),
    );
  }

  // ─── Phone Layout ────────────────────────────────────────────────────────
  Widget _buildPhoneLayout() {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 80),
              // Brand logo from asset
              _buildBrandLogo(),
              const SizedBox(height: 48),
              // Glass card form
              _buildGlassCard(child: _buildForm(isTV: false)),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ─── TV Layout ───────────────────────────────────────────────────────────
  Widget _buildTvLayout() {
    return Row(
      children: [
        // Left — branding (transparent, bg shows through)
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.all(64),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBrandLogo(size: 100),
                const SizedBox(height: 32),
                Text(
                  'THE QUEEN OF HORROR',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.gold,
                        fontSize: 14,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your Host, Sarah',
                  style: TextStyle(
                    fontFamily: 'serif',
                    color: AppTheme.accent,
                    fontSize: 36,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Watch live horror events, classic films,\nand exclusive member content.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 18,
                        height: 1.6,
                      ),
                ),
              ],
            ),
          ),
        ),
        // Right — glass form panel
        Expanded(
          flex: 4,
          child: Center(
            child: SizedBox(
              width: 440,
              child: _buildGlassCard(
                padding: const EdgeInsets.all(48),
                child: _buildForm(isTV: true),
              ),
            ),
          ),
        ),
        const SizedBox(width: 64),
      ],
    );
  }

  Widget _buildBrandLogo({double size = 64}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.whatshot_rounded, color: AppTheme.accent, size: size * 0.5),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('HORROR',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontSize: size * 0.35,
                      color: AppTheme.textPrimary,
                    )),
            Text('AFTER DARK',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontSize: size * 0.32,
                      color: AppTheme.accent,
                    )),
          ],
        ),
      ],
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerRed, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: 0.15),
            blurRadius: 40,
            spreadRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildForm({required bool isTV}) {
    final fs = isTV ? 17.0 : 15.0;
    final btnH = isTV ? 58.0 : 52.0;

    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return KeyboardListener(
          // Intercept Enter / Select / OK from TV remote on the whole form.
          // Uses the stored _formListenerFocus to avoid a resource leak.
          focusNode: _formListenerFocus,
          onKeyEvent: (event) {
            if (event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                    event.logicalKey == LogicalKeyboardKey.select ||
                    event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
              // Only fire submit when a text field is not focused
              // (prevents double-submit from field's onFieldSubmitted)
              final primary = FocusManager.instance.primaryFocus;
              if (primary == _loginBtnFocus || primary == _registerBtnFocus) {
                return; // Let the button handle it
              }
            }
          },
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'SIGN IN',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontSize: isTV ? 28 : 22,
                        color: AppTheme.textPrimary,
                      ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 48,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: isTV ? 32 : 28),

                // Username
                FocusTraversalOrder(
                  order: const NumericFocusOrder(1),
                  child: TextFormField(
                    controller: _usernameCtrl,
                    focusNode: _usernameFocus,
                    autofocus: isTV,
                    textInputAction: TextInputAction.next,
                    style: TextStyle(
                        color: AppTheme.textPrimary, fontSize: fs),
                    decoration: _fieldDecoration(
                      label: 'Username or Email',
                      icon: Icons.person_outline,
                      isTV: isTV,
                    ),
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_passwordFocus);
                    },
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                ),
                SizedBox(height: isTV ? 20 : 16),

                // Password + visibility toggle share one height so the
                // eye icon's focus ring is not clipped inside the field.
                IntrinsicHeight(
                  child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: FocusTraversalOrder(
                        order: const NumericFocusOrder(2),
                        child: TextFormField(
                          controller: _passwordCtrl,
                          focusNode: _passwordFocus,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          style: TextStyle(
                              color: AppTheme.textPrimary, fontSize: fs),
                          decoration: _fieldDecoration(
                            label: 'Password',
                            icon: Icons.lock_outline,
                            isTV: isTV,
                          ),
                          onFieldSubmitted: (_) => _submit(),
                          validator: (v) =>
                              (v == null || v.length < 4) ? 'Required' : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(2.5),
                      child: SizedBox(
                        width: isTV ? 58 : 52,
                        child: SizedBox.expand(
                          child: _PasswordEyeButton(
                            focusNode: _eyeFocus,
                            obscure: _obscure,
                            onPressed: _toggleObscure,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                ),
                SizedBox(height: isTV ? 36 : 28),

                // Sign In button
                FocusTraversalOrder(
                  order: const NumericFocusOrder(3),
                  child: SizedBox(
                    height: btnH,
                    child: ElevatedButton(
                      focusNode: _loginBtnFocus,
                      onPressed: auth.loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, btnH),
                        textStyle: TextStyle(
                            fontSize: fs, fontWeight: FontWeight.w700),
                      ),
                      child: auth.loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white),
                            )
                          : const Text('SIGN IN'),
                    ),
                  ),
                ),
                SizedBox(height: isTV ? 20 : 16),

                // Divider with OR
                Row(
                  children: [
                    Expanded(
                        child: Divider(
                            color: AppTheme.textDim, thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OR',
                          style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                              letterSpacing: 1)),
                    ),
                    Expanded(
                        child: Divider(
                            color: AppTheme.textDim, thickness: 1)),
                  ],
                ),
                SizedBox(height: isTV ? 20 : 16),

                // Register button
                FocusTraversalOrder(
                  order: const NumericFocusOrder(4),
                  child: SizedBox(
                    height: btnH,
                    child: OutlinedButton(
                      focusNode: _registerBtnFocus,
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/register'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size(double.infinity, btnH),
                        textStyle: TextStyle(fontSize: fs),
                      ),
                      child: const Text('CREATE ACCOUNT'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      },
    );
  }
}

/// Visibility toggle kept outside the password field so its box matches the
/// field height and the TV focus ring is not clipped by the input decorator.
class _PasswordEyeButton extends StatelessWidget {
  final FocusNode focusNode;
  final bool obscure;
  final VoidCallback onPressed;

  const _PasswordEyeButton({
    required this.focusNode,
    required this.obscure,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onPressed();
            return true;
          },
        ),
      },
      child: ListenableBuilder(
        listenable: focusNode,
        builder: (context, _) {
          final focused = focusNode.hasFocus;
          return Focus(
            focusNode: focusNode,
            child: Material(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(12),
                canRequestFocus: false,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: focused ? AppTheme.gold : AppTheme.divider,
                      width: focused ? 3 : 1.5,
                    ),
                  ),
                  child: Icon(
                    obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: focused ? AppTheme.gold : AppTheme.textSecondary,
                    size: 24,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
