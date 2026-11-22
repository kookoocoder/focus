import 'dart:math';

class Subject {
  String name;
  bool isLab;
  int attended;
  int total;

  Subject({
    required this.name,
    this.isLab = false,
    this.attended = 0,
    this.total = 0,
  });

  double get percent => total == 0 ? 100 : attended * 100 / total;

  /// Minimum percentage required for this subject (labs are exempt).
  double get required => isLab ? 0 : 75;

  /// Lectures that can still be skipped while staying >= [required]%.
  /// Assumes every other future lecture is attended.
  int get safeSkips {
    if (isLab) return 0;
    final k = (attended / 0.75 - total).floor();
    return max(0, k);
  }

  /// Consecutive lectures to attend to climb back to [required]%.
  int get mustAttend {
    if (isLab || percent >= required) return 0;
    return ((0.75 * total - attended) / 0.25).ceil();
  }

  Map<String, dynamic> toJson() =>
      {'name': name, 'isLab': isLab, 'attended': attended, 'total': total};

  factory Subject.fromJson(Map<String, dynamic> j) => Subject(
        name: j['name'],
        isLab: j['isLab'] ?? false,
        attended: j['attended'] ?? 0,
        total: j['total'] ?? 0,
      );
}

/// Overall attendance across all subjects must stay above 50%.
double overallPercent(List<Subject> s) {
  final a = s.fold<int>(0, (x, e) => x + e.attended);
  final t = s.fold<int>(0, (x, e) => x + e.total);
  return t == 0 ? 100 : a * 100 / t;
}
