
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../providers/incident_provider.dart';
import '../screens/login_screen.dart';
import '../screens/verify_email_screen.dart';
import '../screens/student_dashboard.dart';
import '../screens/staff_dashboard.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _cachedUserId;
  Future<bool>? _staffCheckFuture;

  // Refresh email verification and user permissions.
  Future<void> _refreshVerification() async {
    try {
      await _auth.currentUser?.reload();
      await _auth.currentUser?.getIdToken(true);

      if (!mounted) return;

      setState(() {
        _cachedUserId = null;
        _staffCheckFuture = null;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ??
                'Could not refresh verification status.',
          ),
        ),
      );
    }
  }

  // Determine whether the user has staff access.
  //
  // Staff access is granted to:
  // 1. Verified ALU staff email accounts.
  // 2. Verified accounts with the Firebase staff custom claim.
  //
  // The second condition preserves the existing test staff account.
  Future<bool> _isStaff(User user) async {
    final email = user.email?.trim().toLowerCase() ?? '';

    // All staff accounts must have verified emails.
    if (!user.emailVerified) {
      return false;
    }

    // Official ALU staff email.
    if (email.endsWith('@alueducation.com')) {
      return true;
    }

    // Existing explicitly authorized staff test account.
    final tokenResult = await user.getIdTokenResult(true);
    final claims = tokenResult.claims ?? {};

    return claims['user_role'] == 'staff';
  }

  // Cache the staff check for the current user.
  Future<bool> _getStaffStatus(User user) {
    if (_cachedUserId != user.uid ||
        _staffCheckFuture == null) {
      _cachedUserId = user.uid;
      _staffCheckFuture = _isStaff(user);
    }

    return _staffCheckFuture!;
  }

  // Determine which dashboard the user can access.
  Widget _buildAuthorizedScreen(User user) {
    return FutureBuilder<bool>(
      key: ValueKey(user.uid),
      future: _getStaffStatus(user),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Color(0xFF8544C4),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Could not verify account permissions.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _cachedUserId = null;
                          _staffCheckFuture = null;
                        });
                      },
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final isStaff = snapshot.data ?? false;

        // Authorized ALU staff or explicitly approved test staff.
        if (isStaff) {
          return const StaffDashboard();
        }

        // Students must use a verified ALU student email.
        final email = user.email?.trim().toLowerCase() ?? '';

        final studentEmailPattern = RegExp(
          r'^[a-z]\.[a-z]+@alustudent\.com$',
        );

        if (studentEmailPattern.hasMatch(email)) {
          return _StudentSession(
            key: ValueKey(user.uid),
            userId: user.uid,
          );
        }

        // No recognized role.
        return const _AccessDeniedScreen();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text(
                'Could not check authentication status.',
              ),
            ),
          );
        }

        final user = snapshot.data;

        // User is signed out.
        if (user == null) {
          _cachedUserId = null;
          _staffCheckFuture = null;

          return const LoginScreen();
        }

        // Email verification is required for every account.
        if (!user.emailVerified) {
          return VerifyEmailScreen(
            onVerified: _refreshVerification,
          );
        }

        return _buildAuthorizedScreen(user);
      },
    );
  }
}

// Manages the student's Provider session.
class _StudentSession extends StatefulWidget {
  final String userId;

  const _StudentSession({
    super.key,
    required this.userId,
  });

  @override
  State<_StudentSession> createState() =>
      _StudentSessionState();
}

class _StudentSessionState extends State<_StudentSession> {
  late final IncidentProvider _incidentProvider;

  @override
  void initState() {
    super.initState();

    _incidentProvider = context.read<IncidentProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _incidentProvider.startListening(widget.userId);
    });
  }

  @override
  void dispose() {
    // Remove private incident data when this session ends.
    _incidentProvider.clear();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const StudentDashboard();
  }
}

// Displayed when an account has no authorized role.
class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAFF),
      appBar: AppBar(
        title: const Text('ALU Campus Care'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 65,
                color: Color(0xFF8544C4),
              ),
              const SizedBox(height: 20),
              const Text(
                'Access Restricted',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'This account does not have permission '
                'to access ALU Campus Care. '
                'Please contact the campus administrator.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
