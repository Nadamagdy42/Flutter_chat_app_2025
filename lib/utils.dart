import 'package:flutter/material.dart';

/// Shows a centered loading dialog with spinner
void showLoadingDialog(BuildContext context, {String message = 'Loading...'}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Text(message),
        ],
      ),
    ),
  );
}

/// Dismisses the loading dialog
void hideLoadingDialog(BuildContext context) {
  if (Navigator.canPop(context)) {
    Navigator.pop(context);
  }
}

/// Shows a red error snackbar
void showErrorSnackbar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
    ),
  );
}

/// Shows a success snackbar (optional)
void showSuccessSnackbar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 2),
    ),
  );
}