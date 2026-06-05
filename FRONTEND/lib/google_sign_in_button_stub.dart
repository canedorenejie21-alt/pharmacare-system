import 'package:flutter/material.dart';

Widget googleSignInButton({required VoidCallback? onPressed}) {
  return OutlinedButton.icon(
    onPressed: onPressed,
    icon: const Text(
      'G',
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        color: Color(0xFF2567D8),
      ),
    ),
    label: const Text('Continue with Google'),
  );
}
