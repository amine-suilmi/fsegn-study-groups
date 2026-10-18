/// Domain model for an attendance history entry.
///
/// Documents the student's past sessions, confirmation status,
/// self-reported attendance result, and reliability score impact.
class AttendanceRecordModel {
  final String groupId;
  final String subject;
  final String topic;
  final DateTime sessionDate;
  final bool wasConfirmed;
  final String attendanceStatus; // 'attended' | 'absent' | 'unconfirmed'
  final int scoreImpact; // +5, -15, or 0
  final DateTime? recordedAt;

  const AttendanceRecordModel({
    required this.groupId,
    required this.subject,
    required this.topic,
    required this.sessionDate,
    required this.wasConfirmed,
    required this.attendanceStatus,
    required this.scoreImpact,
    this.recordedAt,
  });

  bool get didAttend => attendanceStatus == 'attended';
  bool get wasAbsent => attendanceStatus == 'absent';
}
