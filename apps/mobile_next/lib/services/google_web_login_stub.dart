import 'package:flutter/widgets.dart';

void clearWebAuthHash() {}

String? readWebAuthToken() => null;

class GoogleSignInButton extends StatelessWidget {
  final Future<void> Function(String credential) onCredential;
  final bool dark;

  const GoogleSignInButton({
    super.key,
    required this.onCredential,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
