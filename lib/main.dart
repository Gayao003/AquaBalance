import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_page_new.dart';
import 'screens/register_page_new.dart';
import 'screens/main_app_page.dart';
import 'services/auth_service.dart';
import 'services/app_preferences_service.dart';
import 'services/hybrid_sync_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Initialize offline-first hybrid sync service
    await HybridSyncService().initialize();
  } catch (e) {
    print('Firebase initialization error: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final preferences = AppPreferencesService();

    return ValueListenableBuilder<bool>(
      valueListenable: preferences.darkModeNotifier,
      builder: (context, darkMode, _) {
        return MaterialApp(
          title: 'AquaBalance',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          // User is logged in
          return const MainAppPage();
        }

        // User is not logged in
        return const AuthScreen();
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoginPage = true;

  void _togglePage() {
    setState(() {
      _isLoginPage = !_isLoginPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoginPage) {
      return LoginPage(onNavigateToRegister: _togglePage);
    } else {
      return RegisterPageNew(onNavigateToLogin: _togglePage);
    }
  }
}
