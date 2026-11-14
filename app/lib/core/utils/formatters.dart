import 'package:intl/intl.dart';

abstract final class Fmt {
  static final _number = NumberFormat.decimalPattern('tr_TR');

  static String km(int value) => '${_number.format(value)} km';
  static String number(int value) => _number.format(value);
  static String percent(double v) => '%${(v * 100).round()}';

  static String date(DateTime d) => DateFormat('d MMM y', 'tr_TR').format(d);
  static String dateTime(DateTime d) => DateFormat('d MMM y · HH:mm', 'tr_TR').format(d);

  static String relative(DateTime d, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(d);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inHours < 1) return '${diff.inMinutes} dk önce';
    if (diff.inDays < 1) return '${diff.inHours} saat önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return date(d);
  }
}
