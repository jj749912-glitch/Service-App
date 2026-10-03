import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'backend_config.dart';
import 'app_theme.dart';
import 'auth_errors.dart';

abstract class AppAuthApi {
  String? get userId;
  Stream<String?> get changes;
  Future<void> signIn(String email, String password);
  Future<bool> signUp(String name, String email, String password);
  Future<void> resendConfirmation(String email);
}

class SupabaseAppAuth implements AppAuthApi {
  final SupabaseClient client;
  final bool worker;
  SupabaseAppAuth(this.client, {this.worker = false});
  @override
  String? get userId =>
      client.auth.currentSession?.user.emailConfirmedAt != null
      ? client.auth.currentSession?.user.id
      : null;
  @override
  Stream<String?> get changes =>
      client.auth.onAuthStateChange.map((_) => userId);
  String get redirect => worker ? workerSite : customerSite;
  @override
  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(email: email, password: password);
    if (userId == null) {
      throw const AuthException('Confirm your email before signing in.');
    }
  }

  @override
  Future<bool> signUp(String name, String email, String password) async {
    final result = await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name},
      emailRedirectTo: redirect,
    );
    return result.session == null || userId == null;
  }

  @override
  Future<void> resendConfirmation(String email) async {
    await client.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: redirect,
    );
  }
}

class AuthGate extends StatefulWidget {
  final AppAuthApi? api;
  final bool worker;
  final WidgetBuilder signedInBuilder;
  final Widget Function(AppAuthApi)? signedOutBuilder;
  const AuthGate({
    super.key,
    this.api,
    this.worker = false,
    required this.signedInBuilder,
    this.signedOutBuilder,
  });
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AppAuthApi api;
  late String? userId;
  StreamSubscription<String?>? subscription;
  @override
  void initState() {
    super.initState();
    api =
        widget.api ??
        SupabaseAppAuth(Supabase.instance.client, worker: widget.worker);
    userId = api.userId;
    subscription = api.changes.listen(
      updateSession,
      onError: (_) => updateSession(null),
    );
  }

  void updateSession(String? id) {
    if (!mounted) return;
    final signedOut = userId != null && id == null;
    setState(() => userId = id);
    if (signedOut) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => userId == null
      ? widget.signedOutBuilder?.call(api) ??
            LoginScreen(api: api, worker: widget.worker)
      : KeyedSubtree(
          key: ValueKey(userId),
          child: widget.signedInBuilder(context),
        );
}

class LoginScreen extends StatefulWidget {
  final AppAuthApi api;
  final bool worker;
  const LoginScreen({super.key, required this.api, this.worker = false});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController();
  bool signup = false, busy = false, showPassword = false, confirmation = false;
  String? error, message;
  @override
  void dispose() {
    for (final c in [name, email, password, confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  String? validateEmail(String? value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '')
      ? null
      : 'Enter a valid email address.';
  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      if (signup) {
        final confirmEmail = await widget.api.signUp(
          name.text.trim(),
          email.text.trim(),
          password.text,
        );
        if (!mounted) return;
        if (confirmEmail) {
          setState(() {
            signup = false;
            confirmation = true;
            message =
                'Check your email to confirm your account, then sign in here.';
            password.clear();
            confirm.clear();
          });
        }
      } else {
        await widget.api.signIn(email.text.trim(), password.text);
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          error = authErrorMessage(e);
          confirmation = e.code == 'email_not_confirmed';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Could not connect. Check your internet connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resend() async {
    if (validateEmail(email.text) != null) {
      setState(() => error = 'Enter your email address first.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.resendConfirmation(email.text.trim());
      if (mounted) {
        setState(
          () => message =
              'Confirmation requested. Check your inbox and spam folder.',
        );
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => error = authErrorMessage(e));
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not resend. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE6F0DF), Color(0xFFF8FAF6), Color(0xFFECF5F0)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          'assets/branding/logo.png',
                          width: 56,
                          height: 56,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        widget.worker ? 'solarcare pro' : 'solarcare',
                        style: const TextStyle(
                          color: ink,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    widget.worker
                        ? 'YOUR SKILLS. YOUR COMMUNITY.'
                        : 'A LITTLE CARE. A BRIGHTER TOMORROW.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: green,
                      fontSize: 11,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    signup
                        ? (widget.worker
                              ? 'Join our professionals.'
                              : 'Make yourself at home.')
                        : (widget.worker
                              ? 'Welcome back, pro.'
                              : 'Welcome home.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.7,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.worker
                        ? 'Sign in to manage your profile and service requests. New workers need admin approval before receiving jobs.'
                        : 'Sign in to find trusted local professionals and book care for your home.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF61756A),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: const BorderSide(color: Color(0xFFE2EBDF)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              signup ? 'Create your account' : 'Sign in',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: ink,
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (signup) ...[
                              TextFormField(
                                controller: name,
                                enabled: !busy,
                                textCapitalization: TextCapitalization.words,
                                autofillHints: const [AutofillHints.name],
                                decoration: const InputDecoration(
                                  labelText: 'Full name',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                maxLength: 100,
                                validator: (v) => (v?.trim().length ?? 0) < 3
                                    ? 'Enter your full name.'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                            ],
                            TextFormField(
                              controller: email,
                              enabled: !busy,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              autocorrect: false,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.mail_outline),
                              ),
                              validator: validateEmail,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: password,
                              enabled: !busy,
                              obscureText: !showPassword,
                              autofillHints: [
                                signup
                                    ? AutofillHints.newPassword
                                    : AutofillHints.password,
                              ],
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: busy
                                      ? null
                                      : () => setState(
                                          () => showPassword = !showPassword,
                                        ),
                                  tooltip: showPassword
                                      ? 'Hide password'
                                      : 'Show password',
                                  icon: Icon(
                                    showPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              validator: (v) => (v?.length ?? 0) < 8
                                  ? 'Use at least 8 characters.'
                                  : null,
                              onFieldSubmitted: (_) {
                                if (!signup && !busy) submit();
                              },
                            ),
                            if (signup) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: confirm,
                                enabled: !busy,
                                obscureText: true,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Confirm password',
                                ),
                                validator: (v) => v != password.text
                                    ? 'Passwords must match.'
                                    : null,
                              ),
                            ],
                            if (message != null) ...[
                              const SizedBox(height: 18),
                              Text(
                                message!,
                                style: const TextStyle(
                                  color: green,
                                  height: 1.5,
                                ),
                              ),
                            ],
                            if (error != null) ...[
                              const SizedBox(height: 18),
                              Text(
                                error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                            const SizedBox(height: 22),
                            FilledButton(
                              onPressed: busy ? null : submit,
                              child: Text(
                                busy
                                    ? 'Please wait…'
                                    : signup
                                    ? 'Create account'
                                    : 'Sign in',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => setState(() {
                                      signup = !signup;
                                      error = null;
                                      message = null;
                                      confirmation = false;
                                      confirm.clear();
                                    }),
                              child: Text(
                                signup
                                    ? 'Already have an account? Sign in'
                                    : 'New here? Create an account',
                              ),
                            ),
                            if (confirmation)
                              TextButton(
                                onPressed: busy ? null : resend,
                                child: const Text('Resend confirmation email'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.worker
                        ? 'WORKER APP · ERNAKULAM & THRISSUR'
                        : 'LOCAL CARE IN ERNAKULAM & THRISSUR',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF61756A),
                      fontSize: 10,
                      letterSpacing: 1.3,
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
