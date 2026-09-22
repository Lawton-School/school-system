// Core grading engine for ZIMSEC and Cambridge International curricula

enum CurriculumType {
  zimsec,
  cambridge,
}

class GradeResult {
  final String grade; // e.g. "A*", "A", "B", "C", "D", "E", "U"
  final int points; // e.g. 1 for A (Zimsec), 9 for U
  final String description; // e.g. "Distinction", "Credit", "Pass"
  final double percentage;

  const GradeResult({
    required this.grade,
    required this.points,
    required this.description,
    required this.percentage,
  });
}

class CurriculumGradingEngine {
  /// Converts a percentage score to a ZIMSEC grade, points, and description
  /// Scale:
  /// A: 75% - 100% (1 point, Distinction)
  /// B: 65% - 74%  (2 points, Credit)
  /// C: 50% - 64%  (3 points, Pass)
  /// D: 45% - 49%  (4 points, Weak Pass)
  /// E: 40% - 44%  (5 points, Bare Pass)
  /// U: 0%  - 39%  (9 points, Ungraded/Fail)
  static GradeResult calculateZimsecGrade(double percentage) {
    final clamped = percentage.clamp(0.0, 100.0);
    if (clamped >= 75.0) {
      return GradeResult(
        grade: 'A',
        points: 1,
        description: 'Distinction',
        percentage: clamped,
      );
    } else if (clamped >= 65.0) {
      return GradeResult(
        grade: 'B',
        points: 2,
        description: 'Credit',
        percentage: clamped,
      );
    } else if (clamped >= 50.0) {
      return GradeResult(
        grade: 'C',
        points: 3,
        description: 'Pass',
        percentage: clamped,
      );
    } else if (clamped >= 45.0) {
      return GradeResult(
        grade: 'D',
        points: 4,
        description: 'Weak Pass',
        percentage: clamped,
      );
    } else if (clamped >= 40.0) {
      return GradeResult(
        grade: 'E',
        points: 5,
        description: 'Bare Pass',
        percentage: clamped,
      );
    } else {
      return GradeResult(
        grade: 'U',
        points: 9,
        description: 'Ungraded',
        percentage: clamped,
      );
    }
  }

  /// Converts a percentage score to a Cambridge IGCSE grade & description
  /// Scale:
  /// A*: 90% - 100% (Outstanding)
  /// A : 80% - 89%  (Excellent)
  /// B : 70% - 79%  (Very Good)
  /// C : 60% - 69%  (Good / Standard Pass)
  /// D : 50% - 59%  (Satisfactory)
  /// E : 40% - 49%  (Sufficient)
  /// F : 30% - 39%  (Low Pass)
  /// G : 20% - 29%  (Minimum Pass)
  /// U : 0%  - 19%  (Ungraded)
  static GradeResult calculateCambridgeGrade(double percentage) {
    final clamped = percentage.clamp(0.0, 100.0);
    if (clamped >= 90.0) {
      return GradeResult(
        grade: 'A*',
        points: 1,
        description: 'Outstanding',
        percentage: clamped,
      );
    } else if (clamped >= 80.0) {
      return GradeResult(
        grade: 'A',
        points: 2,
        description: 'Excellent',
        percentage: clamped,
      );
    } else if (clamped >= 70.0) {
      return GradeResult(
        grade: 'B',
        points: 3,
        description: 'Very Good',
        percentage: clamped,
      );
    } else if (clamped >= 60.0) {
      return GradeResult(
        grade: 'C',
        points: 4,
        description: 'Good',
        percentage: clamped,
      );
    } else if (clamped >= 50.0) {
      return GradeResult(
        grade: 'D',
        points: 5,
        description: 'Satisfactory',
        percentage: clamped,
      );
    } else if (clamped >= 40.0) {
      return GradeResult(
        grade: 'E',
        points: 6,
        description: 'Sufficient',
        percentage: clamped,
      );
    } else if (clamped >= 30.0) {
      return GradeResult(
        grade: 'F',
        points: 7,
        description: 'Low Pass',
        percentage: clamped,
      );
    } else if (clamped >= 20.0) {
      return GradeResult(
        grade: 'G',
        points: 8,
        description: 'Minimum Pass',
        percentage: clamped,
      );
    } else {
      return GradeResult(
        grade: 'U',
        points: 9,
        description: 'Ungraded',
        percentage: clamped,
      );
    }
  }

  /// Universal dispatcher by CurriculumType
  static GradeResult evaluate(double percentage, CurriculumType curriculum) {
    switch (curriculum) {
      case CurriculumType.zimsec:
        return calculateZimsecGrade(percentage);
      case CurriculumType.cambridge:
        return calculateCambridgeGrade(percentage);
    }
  }
}
