import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gradecalculator/utils/app_text_styles.dart';

// this is the custom text form field I used mostly in the app

class CustField extends StatelessWidget {
  final String label;
  final String hintText;
  final IconData? icon;
  final TextEditingController? controller;
  final bool obscureText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  const CustField({
    super.key,
    required this.label,
    required this.hintText,
    this.icon,
    this.controller,
    this.obscureText = false,
    this.validator,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      debugPrint(
        '[CustField] rebuild label=$label controller=${controller?.hashCode}',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.inputLabel),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          keyboardType: keyboardType,
          style: AppTextStyles.inputText,
          // Performance optimizations
          enableInteractiveSelection: true,
          autocorrect: false,
          enableSuggestions: false,
          maxLines: 1,
          decoration: InputDecoration(
            prefixIcon: icon != null ? Icon(icon, color: Colors.black54) : null,
            hintText: hintText,
            hintStyle: AppTextStyles.inputHint,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF121212), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF6200EE), width: 2),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF6200EE), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFCF6C79), width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFCF6C79), width: 2),
            ),
            errorStyle: AppTextStyles.inputError,
          ),
        ),
      ],
    );
  }
}
