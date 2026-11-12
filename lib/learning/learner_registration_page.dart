import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'learner_account_store.dart';
import 'learner_api.dart';
import '../teacher/teacher_session_store.dart';
import '../teacher/teacher_login_page.dart';

// ---------------------------------------------------------------------------
// LearnerRegistrationGate
// ---------------------------------------------------------------------------

/// Shown immediately after the role screen for learners.
///
/// If a [LearnerAccount] already exists locally, [onAccountReady] is called
/// immediately (without showing any UI).  Otherwise the registration screen
/// is displayed until the teacher completes registration.
class LearnerRegistrationGate extends StatefulWidget {
  final LearnerAccountStorage? accountStorage;
  final LearnerApi? api;

  /// Called once a valid account is available (new or pre-existing).
  final void Function(LearnerAccount account) onAccountReady;

  const LearnerRegistrationGate({
    super.key,
    this.accountStorage,
    this.api,
    required this.onAccountReady,
  });

  @override
  State<LearnerRegistrationGate> createState() =>
      _LearnerRegistrationGateState();
}

class _LearnerRegistrationGateState extends State<LearnerRegistrationGate> {
  bool _loading = true;
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.45);
    _tts.setVolume(1.0);
    _init();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _init() async {
    final store = widget.accountStorage ?? await LearnerAccountStore.forApplication();
    final existing = await store.load();
    if (!mounted) return;
    if (existing != null) {
      widget.onAccountReady(existing);
      return;
    }
    // No account yet — show the waiting screen.
    setState(() => _loading = false);
    unawaited(_tts.speak(
      'Welcome. Please ask your teacher to help you register.',
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF202124),
      );
    }
    return _AwaitRegistrationScreen(
      accountStorage: widget.accountStorage,
      api: widget.api,
      onRegistered: widget.onAccountReady,
    );
  }
}

// ---------------------------------------------------------------------------
// _AwaitRegistrationScreen
// ---------------------------------------------------------------------------

/// Shown to the learner while they wait for the teacher to register them.
/// Contains a large button the teacher can tap to open the registration form.
class _AwaitRegistrationScreen extends StatefulWidget {
  final LearnerAccountStorage? accountStorage;
  final LearnerApi? api;
  final void Function(LearnerAccount) onRegistered;

  const _AwaitRegistrationScreen({
    this.accountStorage,
    this.api,
    required this.onRegistered,
  });

  @override
  State<_AwaitRegistrationScreen> createState() =>
      _AwaitRegistrationScreenState();
}

class _AwaitRegistrationScreenState extends State<_AwaitRegistrationScreen> {
  /// Ensures there is a valid teacher session before opening the registration
  /// form.  If no session is saved, shows [TeacherLoginPage] first.
  /// Returns the token string, or null if the teacher dismissed login.
  Future<String?> _ensureTeacherToken() async {
    final store = await TeacherSessionStore.forApplication();
    final existing = await store.load();
    if (existing != null) return existing.token;
    // No session — ask the teacher to log in.
    if (!mounted) return null;
    final session = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute<dynamic>(
        builder: (_) => TeacherLoginPage(sessionStorage: store),
      ),
    );
    if (session == null) return null;
    // session may be a TeacherSession object returned from TeacherLoginPage.
    if (session is TeacherSession) return session.token;
    // Reload from store in case login saved it but returned void.
    final saved = await store.load();
    return saved?.token;
  }

  Future<void> _openRegistration() async {
    final token = await _ensureTeacherToken();
    if (token == null || !mounted) return;
    final account = await Navigator.of(context).push<LearnerAccount>(
      MaterialPageRoute<LearnerAccount>(
        builder: (_) => _TeacherRegistrationForm(
          accountStorage: widget.accountStorage,
          api: widget.api ?? LearnerApi(teacherToken: token),
        ),
      ),
    );
    if (account != null && mounted) {
      widget.onRegistered(account);
    }
  }

  Future<void> _openRestore() async {
    final account = await Navigator.of(context).push<LearnerAccount>(
      MaterialPageRoute<LearnerAccount>(
        builder: (_) => _RestoreAccountForm(
          accountStorage: widget.accountStorage,
          api: widget.api,
        ),
      ),
    );
    if (account != null && mounted) {
      widget.onRegistered(account);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF202124),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.school_outlined,
                color: Color(0xFF8AB4F8),
                size: 72,
              ),
              const SizedBox(height: 24),
              const Text(
                'Welcome',
                style: TextStyle(
                  color: Color(0xFFE8EAED),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Please ask your teacher to help you register.',
                style: TextStyle(
                  color: Color(0xFF9AA0A6),
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Semantics(
                button: true,
                label: 'Teacher: Register learner',
                child: ElevatedButton.icon(
                  key: const ValueKey('register-learner-button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2468D9),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 80),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  icon: const Icon(Icons.app_registration, size: 32),
                  label: const Text('Teacher: Register learner'),
                  onPressed: _openRegistration,
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                key: const ValueKey('already-have-account-button'),
                onPressed: _openRestore,
                child: const Text(
                  'I already have an account',
                  style: TextStyle(
                    color: Color(0xFF8AB4F8),
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TeacherRegistrationForm
// ---------------------------------------------------------------------------

/// Visual form filled in by the teacher. Not voice-driven.
/// On success navigates back with [LearnerAccount] as the result.
class _TeacherRegistrationForm extends StatefulWidget {
  final LearnerAccountStorage? accountStorage;
  final LearnerApi? api;

  const _TeacherRegistrationForm({this.accountStorage, this.api});

  @override
  State<_TeacherRegistrationForm> createState() =>
      _TeacherRegistrationFormState();
}

class _TeacherRegistrationFormState extends State<_TeacherRegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtr = TextEditingController();
  final _phoneCtr = TextEditingController();
  final _emailCtr = TextEditingController();
  final _batchCtr = TextEditingController();
  bool _consent = false;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameCtr.dispose();
    _phoneCtr.dispose();
    _emailCtr.dispose();
    _batchCtr.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final phone = _phoneCtr.text.trim();
    final email = _emailCtr.text.trim();
    if (phone.isEmpty && email.isEmpty) {
      setState(() => _errorMessage =
          'Please supply at least a phone number or an email address.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = widget.api ?? LearnerApi();
      final account = await api.register(
        name: _nameCtr.text.trim(),
        phone: phone.isEmpty ? null : phone,
        email: email.isEmpty ? null : email,
        batch: _batchCtr.text.trim().isEmpty ? null : _batchCtr.text.trim(),
        preferredLanguage: 'English',
        consent: _consent,
      );
      final store = widget.accountStorage ?? await LearnerAccountStore.forApplication();
      await store.save(account);
      if (!mounted) return;
      // Show code screen, then return account to caller.
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => _CodeDisplayScreen(
            account: account,
            onDone: () => Navigator.of(context).pop(account),
          ),
        ),
      );
    } on LearnerApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      const msg = 'Cannot connect to server. Please check your network connection and server settings.';
      setState(() => _errorMessage = msg);
      // Announce audibly as well so visually impaired learners/assistants are aware
      try {
        final tts = FlutterTts();
        tts.speak(msg);
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF202124),
      appBar: AppBar(
        backgroundColor: const Color(0xFF202124),
        foregroundColor: const Color(0xFFE8EAED),
        title: const Text('Register Learner'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field(
                controller: _nameCtr,
                label: 'Learner name *',
                hint: 'Full name',
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Name is required.';
                  if (v.trim().length > 100) return 'Name is too long.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _field(
                controller: _phoneCtr,
                label: 'Phone number',
                hint: 'Digits only (required if no email)',
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null; // optional
                  if (!RegExp(r'^\d{7,15}$').hasMatch(v.trim())) {
                    return 'Enter 7–15 digits.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _field(
                controller: _emailCtr,
                label: 'Email (optional)',
                hint: 'used if phone is not available',
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim())) {
                    return 'Enter a valid email address.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _field(
                controller: _batchCtr,
                label: 'Batch / class (optional)',
                hint: 'e.g. Grade 6 – Section A',
              ),
              const SizedBox(height: 16),
              // Preferred language — English only for now.
              _readonlyField('Preferred language', 'English'),
              const SizedBox(height: 24),
              // Consent checkbox
              CheckboxListTile(
                key: const ValueKey('consent-checkbox'),
                value: _consent,
                activeColor: const Color(0xFF2468D9),
                tileColor: const Color(0xFF303134),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                title: const Text(
                  'The learner (or guardian) agrees to progress being shared with the teacher.',
                  style: TextStyle(
                    color: Color(0xFFE8EAED),
                    fontSize: 14,
                  ),
                ),
                onChanged: (v) => setState(() => _consent = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                key: const ValueKey('submit-registration-button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2468D9),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 64),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: (_submitting || !_consent) ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(color: Color(0xFFE8EAED)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFF9AA0A6)),
        hintStyle: const TextStyle(color: Color(0xFF5F6368)),
        filled: true,
        fillColor: const Color(0xFF303134),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _readonlyField(String label, String value) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF9AA0A6)),
        filled: true,
        fillColor: const Color(0xFF303134),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      child: Text(
        value,
        style: const TextStyle(color: Color(0xFFE8EAED), fontSize: 16),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CodeDisplayScreen
// ---------------------------------------------------------------------------

/// Shown immediately after successful registration.
///
/// TTS reads the code digit by digit, then offers "say 'repeat code'" (or the
/// user taps the repeat button).  The teacher can also read it on-screen.
class _CodeDisplayScreen extends StatefulWidget {
  final LearnerAccount account;
  final VoidCallback onDone;

  const _CodeDisplayScreen({required this.account, required this.onDone});

  @override
  State<_CodeDisplayScreen> createState() => _CodeDisplayScreenState();
}

class _CodeDisplayScreenState extends State<_CodeDisplayScreen> {
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.35); // slower for digit-by-digit reading
    _tts.setVolume(1.0);
    _speakCode();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _speakCode() async {
    final code = widget.account.learnerCode;
    final digits = code.split('').join(', ');
    await _tts.stop();
    await _tts.speak(
      'Registration complete. Your learner code is: $digits. '
      'Tap Repeat Code to hear it again.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.account.learnerCode;
    return Scaffold(
      backgroundColor: const Color(0xFF202124),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF34A853),
                size: 72,
              ),
              const SizedBox(height: 24),
              const Text(
                'Registration complete!',
                style: TextStyle(
                  color: Color(0xFFE8EAED),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.account.name,
                style: const TextStyle(
                  color: Color(0xFF9AA0A6),
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              const Text(
                'Learner code',
                style: TextStyle(
                  color: Color(0xFF9AA0A6),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Semantics(
                label: 'Learner code: ${code.split('').join(', ')}',
                child: Text(
                  code,
                  style: const TextStyle(
                    color: Color(0xFF8AB4F8),
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Write this code down. It is needed to restore the account on a new device.',
                style: TextStyle(color: Color(0xFF9AA0A6), fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              OutlinedButton.icon(
                key: const ValueKey('repeat-code-button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF8AB4F8),
                  side: const BorderSide(color: Color(0xFF8AB4F8)),
                  minimumSize: const Size(220, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.volume_up_outlined),
                label: const Text(
                  'Repeat code',
                  style: TextStyle(fontSize: 18),
                ),
                onPressed: _speakCode,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                key: const ValueKey('continue-button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2468D9),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 64),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: widget.onDone,
                child: const Text('Continue to learning'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _RestoreAccountForm
// ---------------------------------------------------------------------------

/// Allows an existing learner (or their teacher) to restore the account on a
/// new device using the contact detail + 6-digit learner code.
class _RestoreAccountForm extends StatefulWidget {
  final LearnerAccountStorage? accountStorage;
  final LearnerApi? api;

  const _RestoreAccountForm({this.accountStorage, this.api});

  @override
  State<_RestoreAccountForm> createState() => _RestoreAccountFormState();
}

class _RestoreAccountFormState extends State<_RestoreAccountForm> {
  final _formKey = GlobalKey<FormState>();
  final _contactCtr = TextEditingController();
  final _codeCtr = TextEditingController();
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _contactCtr.dispose();
    _codeCtr.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      final api = widget.api ?? LearnerApi();
      final account = await api.restore(
        phoneOrEmail: _contactCtr.text.trim(),
        code: _codeCtr.text.trim(),
      );
      final store = widget.accountStorage ?? await LearnerAccountStore.forApplication();
      await store.save(account);
      if (!mounted) return;
      Navigator.of(context).pop(account);
    } on LearnerApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      const msg = 'Cannot connect to server. Please check your network connection and server settings.';
      setState(() => _errorMessage = msg);
      try {
        final tts = FlutterTts();
        tts.speak(msg);
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF202124),
      appBar: AppBar(
        backgroundColor: const Color(0xFF202124),
        foregroundColor: const Color(0xFFE8EAED),
        title: const Text('Restore Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter the phone number or email used at registration, plus the 6-digit learner code.',
                style: TextStyle(color: Color(0xFF9AA0A6), fontSize: 15),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _contactCtr,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Color(0xFFE8EAED)),
                decoration: _inputDec(
                    'Phone number or email', 'digits or user@example.com'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Phone number or email is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeCtr,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                style: const TextStyle(color: Color(0xFFE8EAED)),
                decoration:
                    _inputDec('6-digit learner code', '000000'),
                validator: (v) {
                  if (v == null || !RegExp(r'^\d{6}$').hasMatch(v.trim())) {
                    return 'Enter the 6-digit code.';
                  }
                  return null;
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style:
                      const TextStyle(color: Colors.redAccent, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                key: const ValueKey('restore-button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2468D9),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 64),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Restore account'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec(String label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFF9AA0A6)),
        hintStyle: const TextStyle(color: Color(0xFF5F6368)),
        filled: true,
        fillColor: const Color(0xFF303134),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      );
}

