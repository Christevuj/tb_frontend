import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage health worker availability and message rate limiting
class WorkingHoursService {
  // Working hours configuration
  static const int workingHourStart = 8; // 8 AM
  static const int workingHourEnd = 17; // 5 PM (17:00 in 24h format)

  // Rate limiting configuration - applies ALL THE TIME (working hours and non-working hours)
  static const int maxMessagesBeforeBlock = 3;

  // SharedPreferences keys
  static String _getMessageCountKey(String chatId) => 'msg_count_$chatId';
  static String _getBlockStatusKey(String chatId) => 'block_status_$chatId';

  /// Check if current time is within working hours (Monday-Friday, 8 AM - 5 PM)
  static bool isWithinWorkingHours() {
    final now = DateTime.now();

    // Check if it's a weekday (Monday = 1, Sunday = 7)
    if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
      return false;
    }

    // Check if time is between 8 AM and 5 PM
    if (now.hour < workingHourStart || now.hour >= workingHourEnd) {
      return false;
    }

    return true;
  }

  /// Get a human-readable message about when health worker is available
  static String getAvailabilityMessage() {
    final now = DateTime.now();

    // Format current time
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour < 12 ? 'AM' : 'PM';
    final displayHour =
        now.hour == 0 ? 12 : (now.hour > 12 ? now.hour - 12 : now.hour);
    final currentTime = '$displayHour:$minute $period';

    if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
      final dayName = now.weekday == DateTime.saturday ? 'Saturday' : 'Sunday';
      return 'Thank you for your message!\n\n'
          '⏰ Current Time: $currentTime, $dayName\n\n'
          '⚠️ You are messaging outside working hours.\n\n'
          '📅 Working Days: Monday - Friday\n'
          '🕐 Working Hours: 8:00 AM - 5:00 PM\n\n'
          'Your message has been received. The healthcare worker will respond during working hours.';
    }

    if (now.hour < workingHourStart) {
      return 'Thank you for your message!\n\n'
          '⏰ Current Time: $currentTime\n\n'
          '⚠️ You are messaging outside working hours.\n\n'
          '🕐 Working Hours: 8:00 AM - 5:00 PM (Monday - Friday)\n\n'
          'It\'s currently before working hours. The healthcare worker will respond when they become available at 8:00 AM.';
    }

    if (now.hour >= workingHourEnd) {
      return 'Thank you for your message!\n\n'
          '⏰ Current Time: $currentTime\n\n'
          '⚠️ You are messaging outside working hours.\n\n'
          '🕐 Working Hours: 8:00 AM - 5:00 PM (Monday - Friday)\n\n'
          'Working hours have ended for today. The healthcare worker will respond when they become available tomorrow at 8:00 AM.';
    }

    return 'Thank you for your message!\n\n'
        '⏰ Current Time: $currentTime\n\n'
        '⚠️ You are messaging outside working hours.\n\n'
        '📅 Working Days: Monday - Friday\n'
        '🕐 Working Hours: 8:00 AM - 5:00 PM\n\n'
        'Your message has been received. The healthcare worker will respond during working hours.';
  }

  // ============================================================================
  // MESSAGE RATE LIMITING - Applies ALL THE TIME
  // ============================================================================

  /// Increment patient message count
  static Future<void> incrementPatientMessageCount(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt(_getMessageCountKey(chatId)) ?? 0;
    final newCount = currentCount + 1;

    await prefs.setInt(_getMessageCountKey(chatId), newCount);

    // If reached limit (3 messages), block until healthcare worker replies
    if (newCount >= maxMessagesBeforeBlock) {
      await _setBlockStatus(chatId, true);
    }
  }

  /// Check if patient is blocked from sending messages
  static Future<bool> isPatientBlocked(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_getBlockStatusKey(chatId)) ?? false;
  }

  /// Set block status
  static Future<void> _setBlockStatus(String chatId, bool isBlocked) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_getBlockStatusKey(chatId), isBlocked);
  }

  /// Reset patient message count (called when healthcare worker replies)
  static Future<void> resetPatientMessageCount(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getMessageCountKey(chatId));
    await prefs.remove(_getBlockStatusKey(chatId));
  }

  /// Get patient message count
  static Future<int> getPatientMessageCount(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_getMessageCountKey(chatId)) ?? 0;
  }

  /// Get remaining messages before block
  static Future<int> getRemainingMessages(String chatId) async {
    if (await isPatientBlocked(chatId)) {
      return 0;
    }

    final prefs = await SharedPreferences.getInstance();
    final messageCount = prefs.getInt(_getMessageCountKey(chatId)) ?? 0;
    return maxMessagesBeforeBlock - messageCount;
  }

  /// Get block message
  static String getBlockMessage() {
    return '⚠️ You have sent 3 messages without a response.\n\n'
        'Please wait for the healthcare worker to reply before sending more messages.\n\n'
        'This helps ensure all patients receive timely responses.';
  }

  /// Manually reset all tracking for a chat (useful for testing or admin actions)
  static Future<void> resetChat(String chatId) async {
    await resetPatientMessageCount(chatId);
  }
}
