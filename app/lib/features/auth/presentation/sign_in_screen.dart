import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../data/auth_repository.dart';

enum _Mode { signIn, signUp }

/// Sign in / sign up / continue as guest. With [linkMode] it upgrades the
/// current guest account to email + password, keeping the same UID.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.linkMode = false});
  final bool linkMode;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late _Mode _mode = widget.linkMode ? _Mode.signUp : _Mode.signIn;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(AuthRepository repo) action, {VoidCallback? onDone}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(ref.read(authRepositoryProvider));
      onDone?.call();
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final email = _email.text;
    final pw = _password.text;
    if (widget.linkMode) {
      // Capture before the await: this page may be rebuilt when the user changes.
      final messenger = ScaffoldMessenger.of(context);
      final router = GoRouter.of(context);
      _run(
        (r) => r.linkWithEmail(email, pw),
        onDone: () {
          messenger.showSnackBar(const SnackBar(content: Text('Hesabınız e-posta ile bağlandı')));
          router.canPop() ? router.pop() : router.go('/settings');
        },
      );
    } else if (_mode == _Mode.signIn) {
      _run((r) => r.signInWithEmail(email, pw));
    } else {
      _run((r) => r.signUpWithEmail(email, pw));
    }
  }

  Future<void> _forgot() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Şifre sıfırlama için önce e-posta adresinizi yazın.');
      return;
    }
    await _run(
      (r) => r.sendPasswordReset(_email.text),
      onDone: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Şifre sıfırlama bağlantısı gönderildi')));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isSignUp = _mode == _Mode.signUp;

    return Scaffold(
      appBar: widget.linkMode ? AppBar(title: const Text('Hesabı bağla')) : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                children: [
                  if (!widget.linkMode) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppColors.brand, AppColors.accent]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 30),
                      ),
                    ),
                    const Gap(Space.xl),
                    Text(isSignUp ? 'Hesap oluşturun' : 'Tekrar hoş geldiniz', style: t.headlineMedium),
                    const Gap(Space.sm),
                    Text(
                      'Araçlarınız ve raporlarınız hesabınızda güvenle saklanır, cihaz değiştirseniz de kaybolmaz.',
                      style: t.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const Gap(Space.xl),
                    SegmentedButton<_Mode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: _Mode.signIn, label: Text('Giriş yap')),
                        ButtonSegment(value: _Mode.signUp, label: Text('Kayıt ol')),
                      ],
                      selected: {_mode},
                      onSelectionChanged: _busy ? null : (s) => setState(() => _mode = s.first),
                    ),
                  ] else
                    const InfoBanner(
                      icon: Icons.link_rounded,
                      title: 'Misafir hesabınızı kalıcı yapın',
                      message: 'Mevcut araçlarınız ve raporlarınız aynı hesapta kalır; yalnızca giriş bilgisi eklenir.',
                    ),
                  const Gap(Space.xl),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'E-posta',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      if (s.isEmpty) return 'E-posta gerekli';
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) return 'Geçerli bir e-posta girin';
                      return null;
                    },
                  ),
                  const Gap(Space.md),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    autofillHints: [isSignUp ? AutofillHints.newPassword : AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Şifre',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      helperText: isSignUp ? 'En az 6 karakter' : null,
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'Göster' : 'Gizle',
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      ),
                    ),
                    validator: (v) => (v ?? '').length < 6 ? 'Şifre en az 6 karakter olmalı' : null,
                  ),
                  if (_error != null) ...[const Gap(Space.md), InfoBanner(tone: BannerTone.danger, title: _error!)],
                  const Gap(Space.xl),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(widget.linkMode ? 'Hesabı bağla' : (isSignUp ? 'Kayıt ol' : 'Giriş yap')),
                  ),
                  if (!widget.linkMode && !isSignUp)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(onPressed: _busy ? null : _forgot, child: const Text('Şifremi unuttum')),
                    ),
                  if (!widget.linkMode) ...[
                    const Gap(Space.lg),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Space.md),
                          child: Text('veya', style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const Gap(Space.lg),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _run((r) => r.signInAnonymously()),
                      icon: const Icon(Icons.person_outline_rounded),
                      label: const Text('Misafir olarak devam et'),
                    ),
                    const Gap(Space.sm),
                    Text(
                      'Misafir hesabınızı daha sonra Ayarlar\'dan e-posta ile kalıcı hale getirebilirsiniz.',
                      style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
