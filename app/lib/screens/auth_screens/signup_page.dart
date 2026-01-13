// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gradecalculator/components/mainscaffold.dart';
import 'package:gradecalculator/components/auth_text_field.dart';
import 'package:gradecalculator/constants/app_constants.dart';
import 'package:gradecalculator/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:gradecalculator/components/customsnackbar.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    usernameController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final height = size.height;
    final width = size.width;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF6200EE)),
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: size.width * 0.08),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: height * 0.05),
                  Text(
                    AppStrings.createNewAccount,
                    style: GoogleFonts.poppins(
                      fontSize: size.height * 0.04,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  SizedBox(height: height * 0.02),

                  // First Name and Last Name row
                  Row(
                    children: [
                      Expanded(
                        child: AuthTextField(
                          label: AppStrings.firstName,
                          controller: firstNameController,
                          validator: (value) => Validators.required(
                            value,
                            AppStrings.firstName,
                          ),
                        ),
                      ),
                      SizedBox(width: width * 0.05),
                      Expanded(
                        child: AuthTextField(
                          label: AppStrings.lastName,
                          controller: lastNameController,
                          validator: (value) => Validators.required(
                            value,
                            AppStrings.lastName,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Username field
                  AuthTextField(
                    label: AppStrings.username,
                    controller: usernameController,
                    validator: (value) => Validators.required(
                      value,
                      AppStrings.username,
                    ),
                  ),

                  // Email field with email validation
                  AuthTextField(
                    label: AppStrings.email,
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                  ),

                  // Password field
                  AuthTextField(
                    label: AppStrings.password,
                    controller: passwordController,
                    obscureText: !_isPasswordVisible,
                    validator: Validators.password,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),

                  // Confirm Password field
                  AuthTextField(
                    label: AppStrings.confirmPassword,
                    controller: confirmPasswordController,
                    obscureText: !_isConfirmPasswordVisible,
                    validator: (value) => Validators.confirmPassword(
                      value,
                      passwordController.text,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        setState(() {
                          _isConfirmPasswordVisible =
                              !_isConfirmPasswordVisible;
                        });
                      },
                    ),
                  ),

                  SizedBox(height: size.height * 0.06),

                  SizedBox(
                    width: size.width * 0.8,
                    height: size.height * 0.06,
                    child: ElevatedButton(
                      onPressed: _handleSignUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6200EE),
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                      child: Text(
                        AppStrings.signUp,
                        style: GoogleFonts.poppins(
                          fontSize: size.height * 0.020,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Handles sign up form submission
  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    String email = emailController.text.trim();
    String password = passwordController.text.trim();
    String firstName = firstNameController.text.trim();
    String lastName = lastNameController.text.trim();
    String username = usernameController.text.trim();

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    String? result = await context.read<AuthProvider>().signUp(
          email: email,
          password: password,
          firstName: firstName,
          lastName: lastName,
          username: username,
        );

    if (context.mounted) Navigator.pop(context);

    if (result != null) {
      // Show error message
      showCustomSnackbar(
        context,
        result,
        duration: const Duration(seconds: 2),
      );
    } else {
      // Success: Navigate to home screen
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const MainScaffold(),
          transitionsBuilder: (
            context,
            animation,
            secondaryAnimation,
            child,
          ) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;

            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        ),
      );
    }
  }
}
