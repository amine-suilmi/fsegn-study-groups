import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';

class UiHelpers {
  static final DateFormat _dateFormat = DateFormat('EEE d MMM y', 'fr_FR');
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _fallbackDateFormat = DateFormat('EEE, MMM d, y');

  static String formatDate(DateTime dt) {
    try {
      return _dateFormat.format(dt);
    } catch (_) {
      return _fallbackDateFormat.format(dt);
    }
  }

  static String formatTime(DateTime dt) {
    return _timeFormat.format(dt);
  }

  static String formatTimeRange(DateTime start, DateTime end) {
    return '${formatTime(start)} - ${formatTime(end)}';
  }

  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: isError ? AppTheme.alertError : AppTheme.primaryNavy,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static Widget buildBadge({
    required String text,
    required Color color,
    Color? textColor,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(120), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: textColor ?? color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor ?? color,
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildCapacityBar({
    required int memberCount,
    required int capacity,
  }) {
    final double ratio = capacity > 0
        ? (memberCount / capacity).clamp(0.0, 1.0)
        : 0.0;
    Color barColor = AppTheme.alertSuccess;
    if (ratio >= 1.0) {
      barColor = AppTheme.alertError;
    } else if (ratio >= 0.75) {
      barColor = AppTheme.alertWarning;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$memberCount / $capacity places occupées',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            Text(
              ratio >= 1.0 ? 'Complet' : '${capacity - memberCount} dispo',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: AppTheme.borderSubtle,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  static Widget buildEmptyState({
    required IconData icon,
    required String title,
    required String description,
    String? buttonText,
    VoidCallback? onButtonPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.tealLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: AppTheme.tealAccent),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textMuted,
                height: 1.4,
              ),
            ),
            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onButtonPressed,
                icon: const Icon(Icons.add, size: 18),
                label: Text(buttonText),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
