class ParsedVersion implements Comparable<ParsedVersion> {
  const ParsedVersion(this.parts, this.prerelease);

  factory ParsedVersion.parse(String value) {
    final normalized = value.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final withoutBuild = normalized.split('+').first;
    final prereleaseIndex = withoutBuild.indexOf('-');
    final numericPart = prereleaseIndex < 0
        ? withoutBuild
        : withoutBuild.substring(0, prereleaseIndex);
    final prerelease = prereleaseIndex < 0
        ? null
        : withoutBuild.substring(prereleaseIndex + 1);
    final numeric = numericPart.split('.');
    if (numeric.isEmpty || numeric.any((part) => int.tryParse(part) == null)) {
      throw FormatException('Invalid version: $value');
    }
    return ParsedVersion(
      numeric.map(int.parse).toList(growable: false),
      prerelease,
    );
  }

  final List<int> parts;
  final String? prerelease;

  @override
  int compareTo(ParsedVersion other) {
    final count = parts.length > other.parts.length
        ? parts.length
        : other.parts.length;
    for (var index = 0; index < count; index += 1) {
      final left = index < parts.length ? parts[index] : 0;
      final right = index < other.parts.length ? other.parts[index] : 0;
      if (left != right) return left.compareTo(right);
    }
    if (prerelease == null && other.prerelease != null) return 1;
    if (prerelease != null && other.prerelease == null) return -1;
    return (prerelease ?? '').compareTo(other.prerelease ?? '');
  }
}

int compareVersions(String left, String right) =>
    ParsedVersion.parse(left).compareTo(ParsedVersion.parse(right));
