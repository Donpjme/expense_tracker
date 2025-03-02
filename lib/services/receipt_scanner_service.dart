import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:logger/logger.dart';

class ReceiptScannerService {
  final Logger _logger = Logger();
  final TextRecognizer _textRecognizer = TextRecognizer();

  Future<Map<String, dynamic>> scanReceipt(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      _logger.i('Text recognized from receipt: ${recognizedText.text}');

      // Parse recognized text to extract expense details
      return _parseReceiptText(recognizedText.text);
    } catch (e) {
      _logger.e('Error scanning receipt: $e');
      return {};
    }
  }

  Map<String, dynamic> _parseReceiptText(String text) {
    // Initialize the result map
    final Map<String, dynamic> result = {
      'title': '',
      'amount': 0.0,
      'date': DateTime.now(),
      'category': 'Miscellaneous', // Default category
    };

    try {
      // Convert text to lowercase to make pattern matching easier
      final lowercaseText = text.toLowerCase();
      final lines = lowercaseText.split('\n');

      // Try to find the store/vendor name (usually at the top of receipt)
      if (lines.isNotEmpty) {
        // First line that's not empty and has more than 3 characters
        for (final line in lines) {
          if (line.trim().length > 3 &&
              !line.contains('receipt') &&
              !line.contains('invoice')) {
            result['title'] = line.trim();
            break;
          }
        }
      }

      // Try to find the total amount
      final totalPattern = RegExp(r'total[\s:]*\$?(\d+\.\d{2})');
      final totalMatch = totalPattern.firstMatch(lowercaseText);
      if (totalMatch != null && totalMatch.groupCount >= 1) {
        final totalStr = totalMatch.group(1);
        if (totalStr != null) {
          result['amount'] = double.tryParse(totalStr) ?? 0.0;
        }
      } else {
        // Alternative: look for a number that appears to be a total
        final amountPattern = RegExp(r'\$(\d+\.\d{2})');
        final amounts = amountPattern
            .allMatches(lowercaseText)
            .map((m) => double.tryParse(m.group(1) ?? '') ?? 0.0)
            .where((amount) => amount > 0)
            .toList();

        // Use the largest amount as the total
        if (amounts.isNotEmpty) {
          amounts.sort();
          result['amount'] = amounts.last;
        }
      }

      // Try to find the date
      final datePatterns = [
        RegExp(
            r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})'), // MM/DD/YYYY or DD/MM/YYYY
        RegExp(r'(\d{2,4})[/\-](\d{1,2})[/\-](\d{1,2})'), // YYYY/MM/DD
      ];

      for (final pattern in datePatterns) {
        final dateMatch = pattern.firstMatch(lowercaseText);
        if (dateMatch != null && dateMatch.groupCount >= 3) {
          try {
            final part1 = int.parse(dateMatch.group(1)!);
            final part2 = int.parse(dateMatch.group(2)!);
            final part3 = int.parse(dateMatch.group(3)!);

            // Determine date format based on the values
            DateTime? parsedDate;

            if (part1 > 31) {
              // Likely YYYY/MM/DD
              parsedDate = DateTime(part1, part2, part3);
            } else if (part3 > 31) {
              // Likely MM/DD/YYYY or DD/MM/YYYY
              // Assume MM/DD/YYYY for US receipts
              parsedDate = DateTime(part3, part1, part2);
            }

            if (parsedDate != null) {
              result['date'] = parsedDate;
            }
          } catch (e) {
            _logger.w('Error parsing date: $e');
          }
        }
      }

      // Try to determine category based on keywords
      final categoryKeywords = {
        'grocery': 'Food',
        'supermarket': 'Food',
        'restaurant': 'Food',
        'cafe': 'Food',
        'coffee': 'Food',
        'uber': 'Transport',
        'lyft': 'Transport',
        'taxi': 'Transport',
        'gas': 'Transport',
        'cinema': 'Entertainment',
        'movie': 'Entertainment',
        'theater': 'Entertainment',
        'pharmacy': 'Health',
        'doctor': 'Health',
        'hospital': 'Health',
        'book': 'Education',
        'school': 'Education',
        'university': 'Education',
        'clothing': 'Shopping',
        'apparel': 'Shopping',
      };

      for (final entry in categoryKeywords.entries) {
        if (lowercaseText.contains(entry.key)) {
          result['category'] = entry.value;
          break;
        }
      }

      _logger.i('Parsed receipt data: $result');
      return result;
    } catch (e) {
      _logger.e('Error parsing receipt text: $e');
      return result;
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}
