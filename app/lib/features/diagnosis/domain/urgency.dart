/// Repair urgency levels returned by the diagnostic pipeline (P0 §4).
enum Urgency {
  u0('U0', 'Bilgi', 'Acil bir durum görünmüyor. Bilgi amaçlıdır.'),
  u1('U1', 'Sonraki bakımda', 'Bir sonraki planlı bakımda kontrol ettirin.'),
  u2('U2', 'Birkaç gün içinde', 'Birkaç gün içinde bir ustaya gösterin.'),
  u3('U3', 'Sürüşü durdurun', 'Güvenli bir yerde durun ve aracı kullanmayın.');

  const Urgency(this.code, this.title, this.advice);

  final String code;
  final String title;
  final String advice;

  static Urgency fromCode(String code) => Urgency.values.firstWhere((u) => u.code == code, orElse: () => Urgency.u0);

  Urgency max(Urgency other) => index >= other.index ? this : other;
}
