import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/attendance_record_model.dart';
import '../../../data/repositories/attendance_repository.dart';
import '../../core/ui_helpers.dart';

class AttendanceHistorySheet extends StatefulWidget {
  const AttendanceHistorySheet({super.key});

  @override
  State<AttendanceHistorySheet> createState() => _AttendanceHistorySheetState();
}

class _AttendanceHistorySheetState extends State<AttendanceHistorySheet> {
  List<AttendanceRecordModel> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final list = await AttendanceRepository.instance.fetchAttendanceHistory();
      if (mounted) {
        setState(() {
          _history = list;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Historique d’assiduité',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryNavy,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Honor system disclaimer (Directive #4)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.tealLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.info_outline, size: 16, color: AppTheme.tealAccent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AttendanceRepository.disclaimerText,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textDark,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _history.isEmpty
                ? UiHelpers.buildEmptyState(
                    icon: Icons.history_toggle_off,
                    title: 'Aucune séance clôturée',
                    description:
                        'Vos présences aux groupes d’étude terminés apparaîtront ici avec l’impact sur votre score de fiabilité.',
                  )
                : ListView.builder(
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final item = _history[index];
                      final didAttend = item.didAttend;
                      final delta = item.scoreImpact;
                      final deltaStr = delta > 0
                          ? '+$delta pts'
                          : (delta < 0 ? '$delta pts' : '0 pt');

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: didAttend
                                ? AppTheme.alertSuccess.withAlpha(30)
                                : AppTheme.alertError.withAlpha(30),
                            child: Icon(
                              didAttend ? Icons.check : Icons.close,
                              color: didAttend
                                  ? AppTheme.alertSuccess
                                  : AppTheme.alertError,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            item.topic,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textDark,
                            ),
                          ),
                          subtitle: Text(
                            '${item.subject} • ${UiHelpers.formatDate(item.sessionDate)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: delta > 0
                                  ? AppTheme.alertSuccess.withAlpha(20)
                                  : (delta < 0
                                        ? AppTheme.alertError.withAlpha(20)
                                        : Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              deltaStr,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: delta > 0
                                    ? AppTheme.alertSuccess
                                    : (delta < 0
                                          ? AppTheme.alertError
                                          : AppTheme.textMuted),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
