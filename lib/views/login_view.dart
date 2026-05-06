import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/auth_repository.dart';
import '../viewmodel/login_viewmodel.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  bool _showForm = false;
  bool _logoAtTop = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late LoginViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    final supabase = Supabase.instance.client;
    final authRepository = AuthRepository(supabase);
    _viewModel = LoginViewModel(authRepository);

    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _logoAtTop = true;
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        setState(() {
          _showForm = true;
        });
      });
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text;
    final password = _passwordController.text;

    final success = await _viewModel.login(email, password);

    if (success) {
      Fluttertoast.showToast(
        msg: "Login Successful",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Fluttertoast.showToast(
        msg: _viewModel.errorMessage ?? "Login failed",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Form Section
            if (_showForm)
              Padding(
                padding: const EdgeInsets.only(
                  left: 30.0,
                  right: 30.0,
                  top: 260.0,
                  bottom: 30.0,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Username',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Roboto',
                            color: Color(0xFF5D4B8A),
                          ),
                        ),
                      ),

                      // Username input
                      TextField(
                        controller: _emailController,
                        cursorColor: const Color(0xFFf7e4b0),
                        decoration: InputDecoration(
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SvgPicture.asset(
                              'assets/img/user.svg',
                              height: 20,
                              width: 20,
                              colorFilter: const ColorFilter.mode(
                                Color(0xFFB191FF),
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Password label
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Password',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Roboto',
                            color: Color(0xFF5D4B8A),
                          ),
                        ),
                      ),

                      // Password input
                      TextField(
                        controller: _passwordController,
                        cursorColor: const Color(0xFFf7e4b0),
                        obscureText: true,
                        decoration: InputDecoration(
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SvgPicture.asset(
                              'assets/img/lock.svg',
                              height: 20,
                              width: 20,
                              colorFilter: const ColorFilter.mode(
                                Color(0xFFB191FF),
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Login button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: const Color(0xFFB191FF),
                        ),
                        onPressed: _handleLogin,
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Register link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Don\'t have an account? ',
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w300,
                              color: Color(0xFF5D4B8A),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(context, '/register');
                            },
                            child: const Text(
                              'Register',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF5D4B8A),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/forgot-password');
                        },
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF5D4B8A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 800.ms),

            // Logo animation
            IgnorePointer(
              ignoring: true,
              child: AnimatedAlign(
                alignment: _logoAtTop ? Alignment.topCenter : Alignment.center,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  margin: EdgeInsets.only(top: _logoAtTop ? 0 : 0),
                  height: _logoAtTop ? 300 : 400,
                  width: _logoAtTop ? 300 : 400,
                  child: Image.asset(
                    'assets/img/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
