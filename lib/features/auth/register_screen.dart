import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/platform_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/in_app_webview_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _passwordSectionKey = GlobalKey();
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  DateTime? _lastObscureToggle;

  final _formScrollCtrl = ScrollController();
  final _firstFocus = FocusNode();
  final _lastFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();
  final _eyeFocus = FocusNode();
  final _submitFocus = FocusNode();
  final _backFocus = FocusNode();

  late final List<FocusNode> _inputFocusNodes;
  late final List<VoidCallback> _inputFocusListeners;

  /// Any text field (or password eye) open → keep that box above TV keypad.
  bool get _inputFocused =>
      _inputFocusNodes.any((n) => n.hasFocus) || _eyeFocus.hasFocus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inputFocusNodes = [
      _firstFocus,
      _lastFocus,
      _emailFocus,
      _userFocus,
      _passFocus,
    ];
    _inputFocusListeners = [
      for (final node in _inputFocusNodes) () => _onInputFocusChange(node),
    ];
    for (var i = 0; i < _inputFocusNodes.length; i++) {
      _inputFocusNodes[i].addListener(_inputFocusListeners[i]);
    }
    _eyeFocus.addListener(_onEyeFocusChange);
  }

  @override
  void didChangeMetrics() {
    if (_inputFocused) _liftFocusedFieldAboveKeyboard(retries: 2);
  }

  void _onEyeFocusChange() {
    if (!mounted) return;
    setState(() {});
    if (_eyeFocus.hasFocus) {
      _liftFocusedFieldAboveKeyboard(retries: 3);
    }
  }

  void _onInputFocusChange(FocusNode node) {
    if (!mounted) return;
    setState(() {});
    if (node.hasFocus) {
      _liftFocusedFieldAboveKeyboard(retries: 3);
    }
  }

  FocusNode? _currentInputFocus() {
    for (final n in _inputFocusNodes) {
      if (n.hasFocus) return n;
    }
    if (_eyeFocus.hasFocus) return _eyeFocus;
    return null;
  }

  void _liftFocusedFieldAboveKeyboard({int retries = 1}) {
    Future<void> scrollOnce() async {
      if (!mounted) return;
      final focused = _currentInputFocus();
      if (focused == null) return;

      final BuildContext? targetCtx = identical(focused, _eyeFocus) ||
              identical(focused, _passFocus)
          ? (_passwordSectionKey.currentContext ?? focused.context)
          : focused.context;
      if (targetCtx == null || !targetCtx.mounted) return;

      await Scrollable.ensureVisible(
        targetCtx,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: 0.0,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
      if (!mounted || !_inputFocused) return;
      if (!_formScrollCtrl.hasClients) return;

      final latestCtx = identical(focused, _eyeFocus) ||
              identical(focused, _passFocus)
          ? (_passwordSectionKey.currentContext ?? focused.context)
          : focused.context;
      if (latestCtx == null || !latestCtx.mounted) return;
      final box = latestCtx.findRenderObject();
      if (box is! RenderBox || !box.hasSize || !box.attached) return;
      final top = box.localToGlobal(Offset.zero).dy;
      final screenH = MediaQuery.sizeOf(context).height;
      // Active field must stay in the upper area; TV keypad covers the rest.
      final maxAllowedTop = screenH * 0.36;
      if (top <= maxAllowedTop) return;
      final delta = top - screenH * 0.10;
      final next = (_formScrollCtrl.offset + delta)
          .clamp(0.0, _formScrollCtrl.position.maxScrollExtent);
      if ((next - _formScrollCtrl.offset).abs() < 2) return;
      await _formScrollCtrl.animateTo(
        next,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollOnce();
      for (var i = 1; i <= retries; i++) {
        Future<void>.delayed(Duration(milliseconds: 250 * i), () {
          if (!mounted || !_inputFocused) return;
          scrollOnce();
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (var i = 0; i < _inputFocusNodes.length; i++) {
      _inputFocusNodes[i].removeListener(_inputFocusListeners[i]);
    }
    _eyeFocus.removeListener(_onEyeFocusChange);
    _formScrollCtrl.dispose();
    for (final c in [
      _firstCtrl,
      _lastCtrl,
      _emailCtrl,
      _usernameCtrl,
      _passwordCtrl,
    ]) {
      c.dispose();
    }
    for (final f in [
      _firstFocus,
      _lastFocus,
      _emailFocus,
      _userFocus,
      _passFocus,
      _eyeFocus,
      _submitFocus,
      _backFocus,
    ]) {
      f.dispose();
    }
    super.dispose();
  }

  void _toggleObscure() {
    final now = DateTime.now();
    final last = _lastObscureToggle;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 400)) {
      return;
    }
    _lastObscureToggle = now;
    setState(() => _obscure = !_obscure);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      email: _emailCtrl.text.trim(),
      username: _usernameCtrl.text.trim(),
      password: _passwordCtrl.text,
      firstName: _firstCtrl.text.trim(),
      lastName: _lastCtrl.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully! Welcome.'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.of(context).pop();
    } else {
      final err = auth.error ?? '';
      if (err.contains('not allowed') ||
          err.contains('401') ||
          err.contains('403')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening Web Account Setup inside App...'),
            backgroundColor: AppTheme.warning,
          ),
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => InAppWebViewScreen(
              url:
                  'https://albertru50.doptortechllc.com/membership-account/membership-checkout/',
              title: 'Account Registration',
              initialUserData: {
                'username': _usernameCtrl.text.trim(),
                'user_login': _usernameCtrl.text.trim(),
                'email': _emailCtrl.text.trim(),
                'bemail': _emailCtrl.text.trim(),
                'bconfirmemail': _emailCtrl.text.trim(),
                'password': _passwordCtrl.text,
                'first_name': _firstCtrl.text.trim(),
                'bfirstname': _firstCtrl.text.trim(),
                'last_name': _lastCtrl.text.trim(),
                'blastname': _lastCtrl.text.trim(),
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              err.isNotEmpty ? err : 'Registration failed. Please try again.',
            ),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final isTV = PlatformService.isTV;
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            AppTheme.heroBg,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(gradient: AppTheme.heroGradient),
          ),
          SafeArea(
            child: isTV ? _buildTvLayout() : _buildPhoneLayout(),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneLayout() {
    final clearance = _inputFocused
        ? MediaQuery.sizeOf(context).height * 0.45
        : 40.0;
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            focusNode: _backFocus,
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _formScrollCtrl,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(28, 8, 28, clearance),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: _buildGlassCard(
                  child: _buildForm(isTV: false),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTvLayout() {
    final screenH = MediaQuery.sizeOf(context).height;
    final inputOpen = _inputFocused;
    // Same UI as before. When typing, only:
    // 1) pin the form card to the top (not center) so fields can sit above keypad
    // 2) add bottom scroll space so lower fields (username/password) can rise
    final keyboardClearance = inputOpen ? screenH * 0.58 : 24.0;

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(48, 32, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  focusNode: _backFocus,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                Text(
                  'CREATE ACCOUNT',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.gold,
                        fontSize: 14,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Join Alberto50',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontSize: 40,
                        color: AppTheme.textPrimary,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Create your free account to watch live\nhorror events and exclusive content.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 18,
                        height: 1.5,
                      ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 48, 24),
            child: Align(
              // Center looks good at rest; top while typing keeps boxes visible.
              alignment:
                  inputOpen ? Alignment.topCenter : Alignment.center,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 520,
                  maxHeight: screenH * 0.9,
                ),
                child: _buildGlassCard(
                  padding: const EdgeInsets.fromLTRB(36, 28, 36, 28),
                  child: SingleChildScrollView(
                    controller: _formScrollCtrl,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.only(bottom: keyboardClearance),
                    child: _buildForm(isTV: true),
                  ),
                ),
              ),
            ),
          ),
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
    final fs = isTV ? 16.0 : 15.0;
    final btnH = isTV ? 56.0 : 52.0;
    final gap = isTV ? 14.0 : 16.0;

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CREATE ACCOUNT',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontSize: isTV ? 24 : 22,
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
            SizedBox(height: isTV ? 22 : 28),

            // First + Last on one row (phone); stacked on TV to avoid overflow.
            if (isTV) ...[
              FocusTraversalOrder(
                order: const NumericFocusOrder(1),
                child: _field(
                  'First Name',
                  _firstCtrl,
                  _firstFocus,
                  next: _lastFocus,
                  icon: Icons.badge_outlined,
                  isTV: isTV,
                  fontSize: fs,
                  autofocus: true,
                ),
              ),
              SizedBox(height: gap),
              FocusTraversalOrder(
                order: const NumericFocusOrder(2),
                child: _field(
                  'Last Name',
                  _lastCtrl,
                  _lastFocus,
                  next: _emailFocus,
                  icon: Icons.badge_outlined,
                  isTV: isTV,
                  fontSize: fs,
                ),
              ),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: FocusTraversalOrder(
                      order: const NumericFocusOrder(1),
                      child: _field(
                        'First Name',
                        _firstCtrl,
                        _firstFocus,
                        next: _lastFocus,
                        icon: Icons.badge_outlined,
                        isTV: isTV,
                        fontSize: fs,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: FocusTraversalOrder(
                      order: const NumericFocusOrder(2),
                      child: _field(
                        'Last Name',
                        _lastCtrl,
                        _lastFocus,
                        next: _emailFocus,
                        icon: Icons.badge_outlined,
                        isTV: isTV,
                        fontSize: fs,
                      ),
                    ),
                  ),
                ],
              ),
            SizedBox(height: gap),

            FocusTraversalOrder(
              order: const NumericFocusOrder(3),
              child: _field(
                'Email',
                _emailCtrl,
                _emailFocus,
                next: _userFocus,
                icon: Icons.email_outlined,
                isTV: isTV,
                fontSize: fs,
                keyboardType: TextInputType.emailAddress,
              ),
            ),
            SizedBox(height: gap),

            FocusTraversalOrder(
              order: const NumericFocusOrder(4),
              child: _field(
                'Username',
                _usernameCtrl,
                _userFocus,
                next: _passFocus,
                icon: Icons.person_outline,
                isTV: isTV,
                fontSize: fs,
              ),
            ),
            SizedBox(height: gap),

            // Password + eye: scrolls above TV keypad when focused.
            KeyedSubtree(
              key: _passwordSectionKey,
              child: SizedBox(
                height: isTV ? 58 : 52,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: FocusTraversalOrder(
                        order: const NumericFocusOrder(5),
                        child: TextFormField(
                          controller: _passwordCtrl,
                          focusNode: _passFocus,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: fs,
                          ),
                          decoration: _fieldDecoration(
                            label: 'Password',
                            icon: Icons.lock_outline,
                            isTV: isTV,
                          ),
                          onFieldSubmitted: (_) => _submit(),
                          validator: (v) => (v == null || v.length < 6)
                              ? 'Min 6 characters'
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(5.5),
                      child: SizedBox(
                        width: isTV ? 58 : 52,
                        child: _PasswordEyeButton(
                          focusNode: _eyeFocus,
                          obscure: _obscure,
                          onPressed: _toggleObscure,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: isTV ? 24 : 32),

            FocusTraversalOrder(
              order: const NumericFocusOrder(6),
              child: Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  return SizedBox(
                    height: btnH,
                    width: double.infinity,
                    child: ElevatedButton(
                      focusNode: _submitFocus,
                      onPressed: auth.loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, btnH),
                        textStyle: TextStyle(
                          fontSize: fs,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: auth.loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text('CREATE ACCOUNT'),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: isTV ? 12 : 14),

            if (!isTV)
              FocusTraversalOrder(
                order: const NumericFocusOrder(7),
                child: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Already have an account? Sign In',
                      style: TextStyle(color: AppTheme.accentLight),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    FocusNode focusNode, {
    FocusNode? next,
    IconData? icon,
    required bool isTV,
    required double fontSize,
    TextInputType keyboardType = TextInputType.text,
    bool autofocus = false,
  }) {
    return TextFormField(
      controller: ctrl,
      focusNode: focusNode,
      autofocus: autofocus,
      keyboardType: keyboardType,
      textInputAction:
          next != null ? TextInputAction.next : TextInputAction.done,
      style: TextStyle(color: AppTheme.textPrimary, fontSize: fontSize),
      decoration: _fieldDecoration(
        label: label,
        icon: icon ?? Icons.edit_outlined,
        isTV: isTV,
      ),
      onFieldSubmitted: (_) {
        if (next != null) FocusScope.of(context).requestFocus(next);
      },
      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
    );
  }
}

/// Password show/hide — FocusableActionDetector so TV OK and touch both work.
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
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        final focused = focusNode.hasFocus;
        return FocusableActionDetector(
          focusNode: focusNode,
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                onPressed();
                return null;
              },
            ),
          },
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
    );
  }
}
