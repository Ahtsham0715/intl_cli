import 'dart:convert';
import 'dart:io';

class ArbGenerator {
  static void generate(Map<String, String> arbData, String filePath) {
    var arbContent = JsonEncoder.withIndent('  ').convert(arbData);
    File(filePath).writeAsStringSync(arbContent);
  }
}
