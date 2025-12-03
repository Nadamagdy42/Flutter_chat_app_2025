import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
// Ensure these imports point to the correct files in your project
import 'screens/chat_list_screen.dart';
import 'screens/chat_screen.dart';
import 'services/user_service.dart';
import 'utils.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Chat App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const AuthGate(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/chatList': (_) => ChatListScreen(), // Removed const here as ChatListScreen might not be const constructor
        '/chat': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as ChatScreenArgs;
          return ChatScreen(
            chatId: args.chatId,
            otherUserId: args.otherUserId,
          );
        },
      },
    );
  }
}

//////////// AUTH GATE ////////////
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data == null
            ? const LoginScreen()
            : ChatListScreen();
      },
    );
  }
}

//////////// LOGIN SCREEN ////////////
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true); // Added setState to show loader

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // AuthGate will automatically route to ChatList
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        // Assuming showErrorSnackbar is defined in utils.dart as imported
        showErrorSnackbar(context, 'Sign in failed: ${e.message}');
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => v!.isEmpty ? 'Enter email' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (v) => v!.isEmpty ? 'Enter password' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _signIn,
                child: _loading
                    ? const SizedBox(
                        height: 20, 
                        width: 20, 
                        child: CircularProgressIndicator(color: Colors.white)
                      )
                    : const Text('Sign In'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                child: const Text("Create an account"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//////////// REGISTER SCREEN ////////////
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    // Assuming showLoadingDialog is defined in utils.dart as imported
    showLoadingDialog(context, message: 'Creating account...'); 
    final username = _usernameController.text.trim().toLowerCase();
    final email = _emailController.text.trim();

    try {
      // Check username
      final exists = await FirebaseFirestore.instance
          .collection('usernames')
          .doc(username)
          .get();

      if (exists.exists) {
        if (mounted) hideLoadingDialog(context); // Assuming hideLoadingDialog is in utils.dart
        if (mounted) showErrorSnackbar(context, 'Username already taken');
        return;
      }

      // Create Firebase Auth User
      final userCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      // Save profile
      await UserService().createUserProfile(
        uid: userCred.user!.uid,
        email: email,
        username: username,
      );

      if (mounted) hideLoadingDialog(context);
      if (mounted) Navigator.pop(context); // Go back to login or let AuthGate handle it
      
    } on FirebaseAuthException catch (e) {
      if (mounted) hideLoadingDialog(context);
      if (mounted) showErrorSnackbar(context, 'Registration failed: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (v) => v!.isEmpty ? 'Enter username' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => v!.isEmpty ? 'Enter email' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (v) => v!.length < 6
                    ? 'Password min 6 chars'
                    : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Create Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatScreenArgs {
  final String chatId;
  final String otherUserId;

  ChatScreenArgs({
    required this.chatId,
    required this.otherUserId,
  });
}