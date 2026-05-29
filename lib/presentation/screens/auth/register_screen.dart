import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authCodeController = TextEditingController();

  String _selectedRole = 'STUDENT';
  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirmPass = true;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final name = _selectedRole == 'STUDENT'
        ? _nameController.text.trim()
        : email.split('@')[0];
    final password = _passwordController.text.trim();
    final idNumber =
        _selectedRole == 'STUDENT' ? _idController.text.trim() : 'N/A';

    // Enforce domain
    if (_selectedRole == 'STUDENT') {
      if (!email.endsWith('@shs.nu-dasma.edu.ph')) {
        _showError('Students must use an @shs.nu-dasma.edu.ph email address.');
        return;
      }
    } else {
      if (!email.endsWith('@nu-dasma.edu.ph')) {
        _showError(
            'Faculty and Staff must use an @nu-dasma.edu.ph email address.');
        return;
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus();

    try {
      // STEP 1: Create Firebase user
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) throw Exception('User creation returned null.');

      // STEP 2: Reload user object to ensure it is fresh
      await user.reload();
      final freshUser = FirebaseAuth.instance.currentUser;
      if (freshUser == null) throw Exception('Could not refresh user after creation.');

      // STEP 3: Sync to backend
      final result = await ApiService.registerWithResult({
        'name': name,
        'username': email,
        'email': email,
        'password': password,
        'role': _selectedRole,
        'idNumber': idNumber,
        'firebaseUid': freshUser.uid,
      });

      if (result['success'] != true) {
        // Rollback: delete the Firebase user
        try {
          await freshUser.delete();
          print('[REGISTER] Rolled back Firebase user — backend sync failed.');
        } catch (rollbackError) {
          print('[REGISTER] Rollback failed: $rollbackError');
        }
        if (!mounted) return;
        _showError('We could not complete your registration right now. Please try again in a few minutes or contact support if the problem continues.');
        return;
      }

      // STEP 4: Send verification email via your OWN backend (bypasses Firebase
      // default sender which gets blocked by institutional Outlook/Exchange servers
      // due to SPF/DKIM failures on Firebase's shared sending IP).
      //
      // Your Node.js backend should use nodemailer with your school SMTP or a
      // transactional service (SendGrid / Mailgun / SES) so the email comes from
      // a trusted sender that Outlook won't reject.
      //
      // FALLBACK: also attempt Firebase's built-in send — if the school IT has
      // whitelisted firebaseapp.com this will work; otherwise the backend send
      // above is the reliable path.
      bool emailSent = false;

      // --- Primary: backend-triggered email (your Node.js + nodemailer) ---
      try {
        final emailResult = await ApiService.sendVerificationEmail({
          'email': email,
          'name': name,
          'firebaseUid': freshUser.uid,
        });
        if (emailResult['success'] == true) {
          emailSent = true;
          print('[REGISTER] Verification email sent via backend SMTP.');
        } else {
          print('[REGISTER] Backend email failed: ${emailResult['message']}');
        }
      } catch (backendEmailError) {
        print('[REGISTER] Backend email error: $backendEmailError');
      }

      // --- Fallback: Firebase built-in send ---
      if (!emailSent) {
        try {
          await freshUser.sendEmailVerification(
            ActionCodeSettings(
              url: 'https://autodemy-test-database.web.app',
              handleCodeInApp: false,
            ),
          );
          emailSent = true;
          print('[REGISTER] Verification email sent via Firebase.');
        } on FirebaseAuthException catch (verifyError) {
          // Surface the EXACT error code so you can diagnose it
          print('[REGISTER] Firebase email error code: ${verifyError.code}');
          print('[REGISTER] Firebase email error message: ${verifyError.message}');
        } catch (verifyError) {
          print('[REGISTER] Firebase email unexpected error: $verifyError');
        }
      }

      if (!emailSent) {
        // Registration succeeded but email couldn't be sent — still show
        // success but warn user to check spam or contact support.
        print('[REGISTER] WARNING: Could not send verification email by any method.');
      }

      if (!mounted) return;
      await FirebaseAuth.instance.signOut();
      _showSuccessDialog(email, emailSent: emailSent);

    } on FirebaseAuthException catch (e) {
      print('[REGISTER] FirebaseAuthException: code=${e.code} msg=${e.message}');
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'This email is already registered. Try logging in instead.';
          break;
        case 'invalid-email':
          errorMessage = 'That email address looks invalid. Please check and try again.';
          break;
        case 'weak-password':
          errorMessage = 'Your password is too weak. Use at least 8 characters, including letters and numbers.';
          break;
        case 'network-request-failed':
          errorMessage = 'We could not reach the server. Check your internet connection and try again.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many attempts. Please wait a few minutes and try again.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password registration is not available right now.';
          break;
        default:
          errorMessage = 'Registration failed. Please check your information and try again.';
      }
      if (!mounted) return;
      _showError(errorMessage);
    } catch (e) {
      print('[REGISTER] Unexpected error: $e');
      if (!mounted) return;
      _showError('We could not complete your registration right now. Please try again or contact support.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(String email, {bool emailSent = true}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Success',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32)),
              contentPadding: const EdgeInsets.all(32),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mark_email_read_rounded,
                        color: Colors.green, size: 48),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Account Created!',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    emailSent
                        ? 'A verification link has been sent to $email.\n\nPlease check your inbox AND your Junk/Spam folder, then click the link to activate your account.'
                        : 'Your account was created, but we could not send the verification email right now.\n\nPlease contact support or try logging in to request a new verification link.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                        height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text('GOT IT, THANKS!',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2)),
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

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 5),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create Account',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Register using your university email',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 16),
                ),
                const SizedBox(height: 40),

                // Role Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: InputDecoration(
                    labelText: 'Select Role',
                    prefixIcon: const Icon(Icons.badge_rounded,
                        color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'STUDENT', child: Text('Student')),
                    DropdownMenuItem(
                        value: 'TEACHER',
                        child: Text('Teacher/Professor')),
                    DropdownMenuItem(
                        value: 'ADMIN', child: Text('Administrator')),
                  ],
                  onChanged: (val) {
                    if (val != null)
                      setState(() => _selectedRole = val);
                  },
                ),
                const SizedBox(height: 16),

                if (_selectedRole == 'STUDENT') ...[
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: const Icon(Icons.person_rounded,
                          color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none),
                    ),
                    validator: (val) =>
                        val == null || val.isEmpty
                            ? 'Enter your name'
                            : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _idController,
                    decoration: InputDecoration(
                      labelText: 'ID / Student Number',
                      prefixIcon: const Icon(Icons.badge_rounded,
                          color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none),
                    ),
                    validator: (val) =>
                        val == null || val.isEmpty
                            ? 'Enter your ID number'
                            : null,
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  TextFormField(
                    controller: _authCodeController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Authorization Code',
                      hintText: 'Enter secret key',
                      prefixIcon: const Icon(Icons.key_rounded,
                          color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none),
                    ),
                    validator: (val) =>
                        val == null || val.isEmpty
                            ? 'Required for this role'
                            : null,
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'University Email',
                    hintText:
                        'e.g., @shs.nu-dasma.edu.ph or @nu-dasma.edu.ph',
                    prefixIcon: const Icon(Icons.email_rounded,
                        color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty)
                      return 'Enter your email';
                    if (!val.contains('@'))
                      return 'Invalid email address';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePass,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_rounded,
                        color: AppTheme.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscurePass
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty)
                      return 'Enter a password';
                    if (val.length < 8) return 'Min 8 characters';
                    if (!RegExp(r'[A-Z]').hasMatch(val))
                      return 'Requires uppercase letter';
                    if (!RegExp(r'[a-z]').hasMatch(val))
                      return 'Requires lowercase letter';
                    if (!RegExp(r'[0-9]').hasMatch(val))
                      return 'Requires a number';
                    if (!RegExp(r'[!@#\$&*~]').hasMatch(val))
                      return r'Requires special character (!@#$&*~)';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPass,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_clock_rounded,
                        color: AppTheme.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscureConfirmPass
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey),
                      onPressed: () => setState(
                          () => _obscureConfirmPass = !_obscureConfirmPass),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none),
                  ),
                  validator: (val) {
                    if (val != _passwordController.text)
                      return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isLoading
                            ? Colors.grey.shade300
                            : AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: _isLoading ? 0 : 8,
                        shadowColor: AppTheme.primary.withOpacity(0.4),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppTheme.primary,
                              ),
                            )
                          : const Text(
                              'REGISTER NOW',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}