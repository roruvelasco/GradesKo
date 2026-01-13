/// Unified text field component for authentication screens
/// Supports dark theme with underline border style
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;

  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.validator,
    this.suffixIcon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: size.height * 0.02),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        validator: validator,
        keyboardType: keyboardType,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: size.height * 0.018,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: size.height * 0.016,
          ),
          suffixIcon: suffixIcon,
          filled: false,
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF6200EE)),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF6200EE), width: 2),
          ),
          errorBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFCF6C79), width: 2),
          ),
          focusedErrorBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFCF6C79), width: 2),
          ),
          errorStyle: GoogleFonts.poppins(
            color: const Color(0xFFCF6C79),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
