import 'package:flutter/material.dart';

class FileNotFound extends StatelessWidget {
  final String? message;

  const FileNotFound({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              "Page Not Found",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!, style: const TextStyle(color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }
}
