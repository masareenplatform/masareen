import 'dart:typed_data';
import 'package:printing/printing.dart';

Future<void> savePdfBytes(String filename, Uint8List bytes) async {
  await Printing.sharePdf(bytes: bytes, filename: filename);
}
