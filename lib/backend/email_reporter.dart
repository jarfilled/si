import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'metrics_manager.dart';

class EmailReporter {
  static Future<void> sendDailyReport(String userEmail) async {
    final metrics = MetricsManager().getDailyReport();
    final buffer = StringBuffer()
      ..writeln("سلام 👋")
      ..writeln("گزارش وضعیت بدن شما امروز:")
      ..writeln("");

    metrics.forEach((key, duration) {
      buffer.writeln(
          "- ${_translateKey(key)}: ${duration.inMinutes} دقیقه در وضعیت نادرست");
    });

    final message = Message()
      ..from = Address('cthehealthcareapp@gmail.com', 'C')
      ..recipients.add(userEmail)
      ..subject = 'گزارش سلامت روزانه شما'
      ..text = buffer.toString();

    final smtpServer =
        gmail('cthehealthcareapp@gmail.com', 'awqt yrce crlv bamo');

    try {
      await send(message, smtpServer);
      print("✅ Email sent to $userEmail");
      MetricsManager().reset();
    } catch (e) {
      print("❌ Failed to send report: $e");
    }
  }

  static String _translateKey(String key) {
    switch (key) {
      case 'tooClose':
        return 'نزدیکی بیش از حد به گوشی';
      case 'hunch':
        return 'قوز کردن';
      case 'neck':
        return 'زاویه‌ی نامناسب گردن';
      case 'wrist':
        return 'فشار روی مچ';
      case 'lowLight':
        return 'نور محیط کم';
      default:
        return key;
    }
  }
}
