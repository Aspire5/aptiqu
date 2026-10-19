import 'package:flutter/material.dart';

class AptiquTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label, hintText;
  final Widget? prefixIcon, suffixIcon;
  final bool obscureText, readOnly;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final Iterable<String>? autofillHints;
  final bool enabled;
  const AptiquTextField({
    super.key,
    this.controller,
    this.label,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.maxLines = 1,
    this.focusNode,
    this.textInputAction,
    this.onFieldSubmitted,
    this.autofillHints,
    this.enabled = true,
  });
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    focusNode: focusNode,
    textInputAction: textInputAction,
    onFieldSubmitted: onFieldSubmitted,
    autofillHints: autofillHints,
    enabled: enabled,
    obscureText: obscureText,
    keyboardType: keyboardType,
    validator: validator,
    readOnly: readOnly,
    onTap: onTap,
    onChanged: onChanged,
    maxLines: maxLines,
    style: Theme.of(context).textTheme.bodyLarge,
    decoration: InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
    ),
  );
}
