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

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  final _firstFocus = FocusNode();
  final _lastFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();
  final _submitFocus = FocusNode();
  final _backFocus = FocusNode();

  @override
  void dispose() {
    for (final c in [
      _firstCtrl, _lastCtrl, _emailCtrl, _usernameCtrl, _passwordCtrl
    ]) {
      c.dispose();
    }
    for (final f in [
      _firstFocus, _lastFocus, _emailFocus, _userFocus, _passFocus, _submitFocus,
      _backFocus,
    ]) {
      f.dispose();
    }
    super.dispose();
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
      if (err.contains('not allowed') || err.contains('401') || err.contains('403')) {
        // WordPress REST API forbids unauthenticated user registration by default
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening Web Account Setup inside App...'),
            backgroundColor: AppTheme.warning,
          ),
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => InAppWebViewScreen(
              url: 'https://albertru50.doptortechllc.com/membership-account/membership-checkout/',
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
            content: Text(err.isNotEmpty ? err : 'Registration failed. Please try again.'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTV = PlatformService.isTV;
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isTV ? 540 : double.infinity),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isTV ? 0 : 28,
              vertical: isTV ? 0 : 32,
            ),
            child: FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Join Alberto50',
                        style: Theme.of(context).textTheme.displaySmall),
                    const SizedBox(height: 6),
                    Text('Create your free account',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: FocusTraversalOrder(
                            order: const NumericFocusOrder(1),
                            child: _field('First Name', _firstCtrl, _firstFocus,
                                next: _lastFocus,
                                icon: Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: FocusTraversalOrder(
                            order: const NumericFocusOrder(2),
                            child: _field('Last Name', _lastCtrl, _lastFocus,
                                next: _emailFocus,
                                icon: Icons.badge_outlined),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(3),
                      child: _field('Email', _emailCtrl, _emailFocus,
                          next: _userFocus,
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress),
                    ),
                    const SizedBox(height: 16),
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(4),
                      child: _field('Username', _usernameCtrl, _userFocus,
                          next: _passFocus, icon: Icons.person_outline),
                    ),
                    const SizedBox(height: 16),
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(5),
                      child: TextFormField(
                        controller: _passwordCtrl,
                        focusNode: _passFocus,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline,
                              color: AppTheme.textMuted),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppTheme.textMuted,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) =>
                            (v == null || v.length < 6)
                                ? 'Min 6 characters'
                                : null,
                      ),
                    ),
                    const SizedBox(height: 32),
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(6),
                      child: Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          return ElevatedButton(
                            focusNode: _submitFocus,
                            onPressed: auth.loading ? null : _submit,
                            child: auth.loading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Create Account'),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Wrap in FocusTraversalOrder so TV remote can Tab to this.
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(7),
                      child: TextButton(
                        focusNode: _backFocus,
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Already have an account? Sign In',
                          style: TextStyle(color: AppTheme.accentLight),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: ctrl,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction:
          next != null ? TextInputAction.next : TextInputAction.done,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null
            ? Icon(icon, color: AppTheme.textMuted)
            : null,
      ),
      onFieldSubmitted: (_) {
        if (next != null) FocusScope.of(context).requestFocus(next);
      },
      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
    );
  }
}
