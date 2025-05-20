class StringExtractor {
  final String content;
  StringExtractor(this.content);

  List<String> extract() {
    var regex = RegExp(r"""(["\'])(?:(?=(\\?))\2.)*?\1""");
    return regex
        .allMatches(content)
        .map((m) => m.group(0)!.substring(1, m.group(0)!.length - 1))
        .toList();
  }
}
