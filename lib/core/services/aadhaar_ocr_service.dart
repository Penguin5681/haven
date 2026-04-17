import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class AadhaarOcrService {
  AadhaarOcrService._();
  static final AadhaarOcrService instance = AadhaarOcrService._();

  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  // Aadhaar is exactly 12 digits, often printed as XXXX XXXX XXXX
  static final _aadhaarPattern =
      RegExp(r'\b(\d{4}[\s\-]?\d{4}[\s\-]?\d{4})\b');

  /// Runs OCR on [imageFile] and returns the detected Aadhaar number
  /// (digits only, no spaces), or null if not found.
  Future<String?> extractAadhaar(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognized = await _recognizer.processImage(inputImage);

    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final text = line.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        final match = _aadhaarPattern.firstMatch(text);
        if (match != null) {
          // Strip spaces/dashes → pure 12-digit string
          return match.group(1)!.replaceAll(RegExp(r'[\s\-]'), '');
        }
      }
    }
    return null;
  }

  void dispose() => _recognizer.close();
}
