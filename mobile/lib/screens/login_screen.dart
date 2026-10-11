import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/server_settings.dart';
import 'customer_screen.dart';
import 'home_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _boutique = TextEditingController();
  final _phone = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _hide = true;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (_register) {
        await Api.instance.register(_user.text.trim(), _pass.text, _boutique.text.trim(), _phone.text.trim());
      } else {
        await Api.instance.login(_user.text.trim(), _pass.text);
      }
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeShell()));
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.plumDeep,
      body: Stack(children: [
        // Decorative background: soft gold "thread" circles.
        Positioned(top: -80, right: -60, child: _Ring(220, AppColors.gold.withValues(alpha: 0.25))),
        Positioned(top: 120, left: -90, child: _Ring(180, AppColors.plumSoft.withValues(alpha: 0.5))),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: 'Server settings',
                      onPressed: () => showServerSettings(context),
                      icon: const Icon(Icons.settings_rounded, color: Colors.white70),
                    ),
                  ),
                  Container(
                    width: 76,
                    height: 76,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [AppColors.gold, Color(0xFFE8CF97)]),
                      boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.4), blurRadius: 24)],
                    ),
                    child: const Icon(Icons.checkroom_rounded, size: 40, color: AppColors.plumDeep),
                  ),
                  const SizedBox(height: 18),
                  const Text('Boutique Rentals',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  const SizedBox(height: 6),
                  const Text('Every outfit out. Every outfit back. On time.',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(color: AppColors.ivory, borderRadius: BorderRadius.circular(28)),
                    child: Form(
                      key: _form,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text(_register ? 'Create boutique account' : 'Owner login',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 16),
                        if (_register) ...[
                          TextFormField(
                            controller: _boutique,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                                labelText: 'Boutique name', prefixIcon: Icon(Icons.storefront_rounded)),
                            validator: (v) => (v ?? '').trim().length < 2 ? 'Enter your boutique name' : null,
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _user,
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: 'Username',
                            prefixIcon: const Icon(Icons.person_rounded),
                            helperText: _register ? 'Letters, numbers, _ or . — customers use this as Boutique code' : null,
                          ),
                          validator: (v) {
                            final s = (v ?? '').trim();
                            if (s.length < 3) return 'At least 3 characters';
                            if (_register && !RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(s)) {
                              return 'Only letters, numbers, _ and .';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _pass,
                          obscureText: _hide,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                              onPressed: () => setState(() => _hide = !_hide),
                            ),
                          ),
                          validator: (v) => (v ?? '').length < 6 ? 'At least 6 characters' : null,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        if (_register) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                                labelText: 'Phone (optional)', prefixIcon: Icon(Icons.phone_rounded)),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(
                                  width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                              : Text(_register ? 'Create account' : 'Login'),
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: () => setState(() => _register = !_register),
                          child: Text(_register ? 'Already have an account? Login' : 'New boutique? Create account'),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.goldSoft,
                      side: const BorderSide(color: AppColors.gold, width: 1.4),
                    ),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerScreen())),
                    icon: const Icon(Icons.search_rounded),
                    label: const Text("I'm a customer — is my dress free?"),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring(this.size, this.color);
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 18)),
      );
}
