import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../data/consent_repository.dart';
import '../domain/consent.dart';

/// S1 — Onboarding & Consent.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  // KVKK: all boxes start unticked.
  bool _diagnosis = false;
  bool _improvement = false;
  bool _notifications = false;

  static const _pageCount = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pageCount - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    } else {
      ref
          .read(consentProvider.notifier)
          .save(
            Consent(
              version: Consent.currentVersion,
              acceptedAt: DateTime.now(),
              diagnosis: _diagnosis,
              modelImprovement: _improvement,
              notifications: _notifications,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  const _Logo(),
                  const Spacer(),
                  if (_page < _pageCount - 1)
                    TextButton(
                      onPressed: () => _controller.animateToPage(
                        _pageCount - 1,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                      ),
                      child: const Text('Atla'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  const _IntroPage(
                    icon: Icons.graphic_eq_rounded,
                    eyebrow: 'Ses · Fotoğraf · Kılavuz',
                    title: 'Ustaya gitmeden önce\nne olduğunu anlayın',
                    body:
                        'Motor sesini kaydedin, gösterge panelinin fotoğrafını çekin. AutoSense olası nedenleri, '
                        'aciliyet seviyesini ve kullanım kılavuzunuzdaki ilgili bölümü tek raporda gösterir.',
                    features: [
                      (Icons.mic_rounded, 'Motor sesi analizi', '10 saniyelik kayıt, cihaz üzerinde sınıflandırma'),
                      (Icons.dashboard_customize_rounded, 'Uyarı lambası okuma', '20 yaygın ISO 2575 sembolü'),
                      (Icons.menu_book_rounded, 'Kaynaklı açıklama', 'Her iddia kılavuzdan bir pasajla desteklenir'),
                    ],
                  ),
                  const _IntroPage(
                    icon: Icons.handshake_rounded,
                    eyebrow: 'Ne yapar, ne yapmaz',
                    title: 'Bir ön-teşhis asistanı,\nustanın yerine geçmez',
                    body:
                        'Sonuçlar bilgilendirme amaçlıdır. Amaç, ustayla daha bilinçli konuşmanızı ve '
                        'aracın güvenle kullanılıp kullanılamayacağını anlamanızı sağlamaktır.',
                    features: [
                      (
                        Icons.check_circle_rounded,
                        'Yapar',
                        'Olası nedenleri sıralar, aciliyet önerir, soru listesi hazırlar',
                      ),
                      (Icons.cancel_rounded, 'Yapmaz', 'Kesin teşhis koymaz, fiyat vermez, tamir önermez'),
                      (
                        Icons.shield_rounded,
                        'Güvenlik kuralı',
                        'Kırmızı uyarı lambası her zaman "Sürüşü durdurun" (U3)',
                      ),
                    ],
                  ),
                  _ConsentPage(
                    diagnosis: _diagnosis,
                    improvement: _improvement,
                    notifications: _notifications,
                    onDiagnosis: (v) => setState(() => _diagnosis = v),
                    onImprovement: (v) => setState(() => _improvement = v),
                    onNotifications: (v) => setState(() => _notifications = v),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  _Dots(count: _pageCount, index: _page),
                  const Gap(Space.lg),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _next,
                        iconAlignment: IconAlignment.end,
                        icon: Icon(_page == _pageCount - 1 ? Icons.check_rounded : Icons.arrow_forward_rounded),
                        label: Text(
                          _page == _pageCount - 1 ? 'Kabul et ve başla' : 'Devam',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Always laid out so the button above never jumps.
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _page == _pageCount - 1 && !_diagnosis ? 1 : 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Teşhis onayı vermeden de uygulamayı kullanabilirsiniz; ancak teşhis özelliği kapalı kalır.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.brand, AppColors.accent]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 20),
        ),
        const Gap(10),
        Text('AutoSense', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.features,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
  final List<(IconData, String, String)> features;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      children: [
        _HeroArt(icon: icon),
        const Gap(Space.xxl),
        Text(
          eyebrow.toUpperCase(),
          style: t.labelSmall?.copyWith(color: scheme.primary, letterSpacing: 1.2, fontWeight: FontWeight.w800),
        ),
        const Gap(Space.sm),
        Text(title, style: t.headlineMedium),
        const Gap(Space.md),
        Text(body, style: t.bodyLarge?.copyWith(color: scheme.onSurfaceVariant, height: 1.5)),
        const Gap(Space.xl),
        for (final (fi, ft, fs) in features)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: Row(
              children: [
                IconTile(icon: fi, color: scheme.primary, size: 40),
                const Gap(Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ft, style: t.titleSmall),
                      Text(fs, style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HeroArt extends StatelessWidget {
  const _HeroArt({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.xl),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B2A6B), AppColors.brand, AppColors.accent],
        ),
      ),
      child: Stack(
        children: [
          Positioned(right: -30, top: -30, child: _ring(160)),
          Positioned(left: -40, bottom: -50, child: _ring(140)),
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
              ),
              child: Icon(icon, color: Colors.white, size: 44),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ring(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 18),
    ),
  );
}

class _ConsentPage extends StatelessWidget {
  const _ConsentPage({
    required this.diagnosis,
    required this.improvement,
    required this.notifications,
    required this.onDiagnosis,
    required this.onImprovement,
    required this.onNotifications,
  });

  final bool diagnosis;
  final bool improvement;
  final bool notifications;
  final ValueChanged<bool> onDiagnosis;
  final ValueChanged<bool> onImprovement;
  final ValueChanged<bool> onNotifications;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      children: [
        Text(
          'KVKK & GİZLİLİK',
          style: t.labelSmall?.copyWith(color: scheme.primary, letterSpacing: 1.2, fontWeight: FontWeight.w800),
        ),
        const Gap(Space.sm),
        Text('Verileriniz sizin kontrolünüzde', style: t.headlineMedium),
        const Gap(Space.md),
        Text(
          'Her izni ayrı ayrı verebilir ve dilediğiniz zaman Ayarlar\'dan geri çekebilirsiniz.',
          style: t.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const Gap(Space.lg),
        const InfoBanner(
          icon: Icons.privacy_tip_outlined,
          title: 'Cihaz üzerinde anonimleştirme',
          message:
              'Fotoğraflardaki yüz ve plakalar bulanıklaştırılır, konum (EXIF/GPS) silinir, kayıtlardaki konuşmalar '
              'bastırılır. Şasi no, plaka ve konum hiçbir zaman toplanmaz. Ham medya 30 gün sonra silinir.',
        ),
        const Gap(Space.lg),
        _ConsentTile(
          value: diagnosis,
          onChanged: onDiagnosis,
          title: 'Teşhis için veri işleme',
          subtitle:
              'Ses kaydı, fotoğraf ve araç profilinin teşhis amacıyla işlenmesi. Bulut işleme yurt dışında '
              'gerçekleşebilir (KVKK md. 9).',
          tag: 'Teşhis için gerekli',
        ),
        const Gap(Space.sm),
        _ConsentTile(
          value: improvement,
          onChanged: onImprovement,
          title: 'Modelin iyileştirilmesi',
          subtitle: 'Anonimleştirilmiş kayıtlarımın ses modelini geliştirmek için kullanılması.',
          tag: 'İsteğe bağlı',
        ),
        const Gap(Space.sm),
        _ConsentTile(
          value: notifications,
          onChanged: onNotifications,
          title: 'Bildirimler',
          subtitle: 'Bakım hatırlatmaları ve "raporunuz hazır" bildirimleri.',
          tag: 'İsteğe bağlı',
        ),
        const Gap(Space.md),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => showKvkkNotice(context),
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text('Aydınlatma metnini oku'),
          ),
        ),
      ],
    );
  }
}

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    required this.value,
    required this.onChanged,
    required this.title,
    required this.subtitle,
    required this.tag,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;
  final String subtitle;
  final String tag;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: () => onChanged(!value),
      padding: const EdgeInsets.all(Space.md),
      borderColor: value ? scheme.primary : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
          const Gap(Space.xs),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(title, style: t.titleSmall)),
                      const Gap(Space.sm),
                      Pill(tag, color: scheme.onSurfaceVariant),
                    ],
                  ),
                  const Gap(4),
                  Text(subtitle, style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(right: 6),
            width: i == index ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index ? scheme.primary : scheme.outline,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
      ],
    );
  }
}

/// KVKK Art. 10 information notice (summary; full legal text TBD by the team).
Future<void> showKvkkNotice(BuildContext context) {
  final t = Theme.of(context).textTheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          Text('Aydınlatma Metni (özet)', style: t.titleLarge),
          const Gap(Space.lg),
          for (final (h, b) in _kvkkSections) ...[
            Text(h, style: t.titleSmall),
            const Gap(4),
            Text(b, style: t.bodyMedium),
            const Gap(Space.lg),
          ],
        ],
      ),
    ),
  );
}

const _kvkkSections = [
  ('Veri sorumlusu', 'AutoSense, Takım 44 tarafından akademik ve ticari olmayan bir proje olarak geliştirilmektedir.'),
  (
    'İşlenen veriler',
    'Araç profili (marka, model, yıl, motor, kilometre, bakım geçmişi), motor ses kayıtları ve '
        'gösterge paneli fotoğrafları. Şasi numarası, plaka ve konum toplanmaz.',
  ),
  (
    'Amaç ve hukuki sebep',
    'Ön-teşhis raporu oluşturmak (açık rıza), isteğe bağlı olarak modeli iyileştirmek (ayrı açık rıza) '
        've bakım hatırlatmaları göndermek (ayrı açık rıza).',
  ),
  (
    'Yurt dışına aktarım',
    'Yapay zekâ işlemleri bulut sağlayıcısının yurt dışındaki sunucularında gerçekleşebilir (md. 9).',
  ),
  ('Saklama süresi', 'Ham ses ve fotoğraflar 30 gün sonra otomatik silinir. Raporlar siz silene kadar saklanır.'),
  (
    'Haklarınız (md. 11)',
    'Verilerinizi dışa aktarabilir, silebilir ve onaylarınızı dilediğiniz zaman Ayarlar ekranından '
        'geri çekebilirsiniz.',
  ),
];
