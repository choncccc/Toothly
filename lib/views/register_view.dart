import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/auth_repository.dart';
import '../viewmodel/register_viewmodel.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  // Controllers now belong to the VIEW, not controller
  final TextEditingController _fNameController = TextEditingController();
  final TextEditingController _lNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? selectedYear;

  late RegisterViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    final supabase = Supabase.instance.client;
    final authRepository = AuthRepository(supabase);
    _viewModel = RegisterViewModel(authRepository);
  }

  @override
  void dispose() {
    _fNameController.dispose();
    _lNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    // _usernameController.dispose();
    super.dispose();
  }

  final List<String> yearItems = [
    "1st Year",
    "2nd Year",
    "3rd Year",
    "4th Year",
  ];

  Future<void> _handleRegister() async {
    final success = await _viewModel.register(
      firstName: _fNameController.text,
      lastName: _lNameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      year: selectedYear ?? "",
    );

    if (success) {
      Fluttertoast.showToast(
        msg: "Registered Successfully",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/');
    } else {
      Fluttertoast.showToast(
        msg: _viewModel.errorMessage ?? "Registration failed",
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Image.asset(
                    'assets/img/logo.png',
                    height: 260,
                    width: 260,
                    fit: BoxFit.contain,
                  ),
                ),

                Transform.translate(
                  offset: const Offset(0, -30),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // First Name label
                        const Padding(
                          padding: EdgeInsets.only(left: 20.0),
                          child: Text(
                            'First Name',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Roboto',
                              color: Color(0xFF5D4B8A),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // First Name
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18.0),
                          child: TextField(
                            controller: _fNameController,
                            cursorColor: Color(0xFFD4AF37),
                            decoration: InputDecoration(
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: SvgPicture.asset(
                                  'assets/img/user-square.svg',
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
                        ),
                        const SizedBox(height: 10),

                        // Last Name label
                        const Padding(
                          padding: EdgeInsets.only(left: 20.0),
                          child: Text(
                            'Last Name',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Roboto',
                              color: Color(0xFF5D4B8A),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Last name
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18.0),
                          child: TextField(
                            controller: _lNameController,
                            cursorColor: Color(0xFFD4AF37),
                            decoration: InputDecoration(
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: SvgPicture.asset(
                                  'assets/img/user-square.svg',
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
                        ),
                        const SizedBox(height: 10),

                        //Year label
                        const Padding(
                          padding: EdgeInsets.only(left: 20.0),
                          child: Text(
                            'Year',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Roboto',
                              color: Color(0xFF5D4B8A),
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18.0),
                          child: GestureDetector(
                            onTap: () => _showYearPicker(),
                            child: AbsorbPointer(
                              // prevents keyboard
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: selectedYear ?? "Select Year",
                                  hintStyle: const TextStyle(
                                    color: Colors.grey,
                                  ),
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: SvgPicture.asset(
                                      'assets/img/calendar-week.svg',
                                      height: 20,
                                      width: 20,
                                      colorFilter: const ColorFilter.mode(
                                        Color(0xFFB191FF),
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                  suffixIcon: const Icon(Icons.arrow_drop_down),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Email label
                        const Padding(
                          padding: EdgeInsets.only(left: 20.0),
                          child: Text(
                            'Email Address',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Roboto',
                              color: Color(0xFF5D4B8A),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Email input
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18.0),
                          child: TextField(
                            controller: _emailController,
                            cursorColor: Color(0xFFD4AF37),
                            decoration: InputDecoration(
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: SvgPicture.asset(
                                  'assets/img/mail.svg',
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
                        ),
                        const SizedBox(height: 10),

                        // Password label
                        const Padding(
                          padding: EdgeInsets.only(left: 20.0),
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
                        const SizedBox(height: 6),

                        // Password
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18.0),
                          child: TextField(
                            controller: _passwordController,
                            cursorColor: Color(0xFFD4AF37),
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
                        ),
                        const SizedBox(height: 30),

                        // Register button
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18.0),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              backgroundColor: const Color(0xFFB191FF),
                            ),
                            onPressed: _handleRegister,
                            child: const Text(
                              'Register',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Already have an account? ',
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w300,
                                color: Color(0xFF5D4B8A),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.pushReplacementNamed(context, '/');
                              },
                              child: const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Roboto',
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF5D4B8A),
                                ),
                              ),
                            ),
                          ],
                        ),
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

  void _showYearPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ListView(
          shrinkWrap: true,
          children: yearItems.map((year) {
            return ListTile(
              title: Text(year),
              onTap: () {
                setState(() => selectedYear = year);
                Navigator.pop(context);
              },
            );
          }).toList(),
        );
      },
    );
  }
}
