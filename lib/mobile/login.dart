import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth_gate.dart';
import '../auth_errors.dart';
import 'components.dart';
import 'design.dart';

class MobileLoginScreen extends StatefulWidget {
  final AppAuthApi api;
  const MobileLoginScreen({super.key, required this.api});
  @override
  State<MobileLoginScreen> createState() => _MobileLoginScreenState();
}

class _MobileLoginScreenState extends State<MobileLoginScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController();
  bool signup = false, busy = false, visible = false, confirmation = false;
  String? error, message;
  @override
  void dispose() {
    for (final controller in [name, email, password, confirm]) {
      controller.dispose();
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
        final needsConfirmation = await widget.api.signUp(
          name.text.trim(),
          email.text.trim(),
          password.text,
        );
        if (needsConfirmation && mounted) {
          setState(() {
            signup = false;
            confirmation = true;
            password.clear();
            confirm.clear();
            message =
                'Check your email to confirm your account, then sign in here.';
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
              'Could not connect. Check your internet connection and retry.',
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
      if (mounted) setState(() => error = 'Could not resend. Please retry.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
    child: Scaffold(
      body: SingleChildScrollView(
        child: SolarBackdrop(
          height: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  25,
                  MediaQuery.paddingOf(context).top + 30,
                  25,
                  0,
                ),
                child: const ServeBrand(size: 32),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 42, 25, 35),
                child: PageHeading(
                  signup ? 'A Brighter Start.' : 'Welcome Back.',
                  subtitle: signup
                      ? 'Create your account and find trusted\nprofessionals for your home.'
                      : 'Cleaner Homes. Brighter Tomorrows.\nSign in to start your solar journey.',
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
                decoration: const BoxDecoration(
                  color: serveBackground,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        signup
                            ? 'Create Your Account'
                            : 'Login to Your Account',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.6,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Local care in Ernakulam & Thrissur',
                        style: TextStyle(color: serveMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 23),
                      if (signup) ...[
                        TextFormField(
                          controller: name,
                          enabled: !busy,
                          maxLength: 100,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.name],
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: serveBlue,
                            ),
                          ),
                          validator: (v) => (v?.trim().length ?? 0) < 3
                              ? 'Enter your full name.'
                              : null,
                        ),
                        const SizedBox(height: 13),
                      ],
                      TextFormField(
                        controller: email,
                        enabled: !busy,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(
                            Icons.mail_outline,
                            color: serveBlue,
                          ),
                        ),
                        validator: validateEmail,
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: password,
                        enabled: !busy,
                        obscureText: !visible,
                        autofillHints: [
                          signup
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: serveBlue,
                          ),
                          suffixIcon: IconButton(
                            onPressed: busy
                                ? null
                                : () => setState(() => visible = !visible),
                            tooltip: visible
                                ? 'Hide password'
                                : 'Show password',
                            icon: Icon(
                              visible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: serveMuted,
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
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: confirm,
                          enabled: !busy,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirm password',
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: serveBlue,
                            ),
                          ),
                          validator: (v) => v != password.text
                              ? 'Passwords must match.'
                              : null,
                        ),
                      ],
                      if (message != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 15),
                          child: Text(
                            message!,
                            style: const TextStyle(
                              color: Color(0xFF04945C),
                              fontSize: 12,
                              height: 1.6,
                            ),
                          ),
                        ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 15),
                          child: Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 23),
                      YellowButton(
                        busy
                            ? 'Please Wait…'
                            : signup
                            ? 'Create Account'
                            : 'Login',
                        onPressed: busy ? null : submit,
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
                              ? 'Already registered? Login'
                              : 'New to SolarServe? Create an account',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      if (confirmation)
                        TextButton(
                          onPressed: busy ? null : resend,
                          child: const Text('Resend Confirmation Email'),
                        ),
                      const SizedBox(height: 20),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: serveBlue,
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Your Home. Our Care.',
                            style: TextStyle(color: serveMuted, fontSize: 11),
                          ),
                        ],
                      ),
                      SizedBox(height: MediaQuery.paddingOf(context).bottom),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
