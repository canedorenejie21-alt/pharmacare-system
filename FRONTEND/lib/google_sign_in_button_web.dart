import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

Widget googleSignInButton({required VoidCallback? onPressed}) {
  return Center(
    child: web.renderButton(
      configuration: web.GSIButtonConfiguration(
        size: web.GSIButtonSize.large,
        text: web.GSIButtonText.continueWith,
        shape: web.GSIButtonShape.rectangular,
      ),
    ),
  );
}
