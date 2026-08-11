// Driver harness for screenshot capture during `flutter drive`.
// Run: flutter drive --driver=testing_driver.dart --target=integration_test/app_test.dart
import 'dart:io';
import 'package:flutter_driver/driver_extension.dart';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() async {
  enableFlutterDriverExtension();
  // Screenshots are written by the test via ServicesBinding / integrationDriver.
  await integrationDriver(
    onScreenshot: (name, bytes, [pixels]) async {
      final file = File('screenshots/$name.png');
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    },
  );
}
