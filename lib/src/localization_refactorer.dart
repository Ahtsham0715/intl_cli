class LocalizationRefactorer {
  static String refactor(String content, String original, String key) {
    // Replace double and single quoted instances.
    return content
        .replaceAll('"$original"', 'tr("$key")')
        .replaceAll("'$original'", "tr('$key')");
  }
}
