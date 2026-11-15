import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../core/firebase/remote_store.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../auth/data/auth_repository.dart';
import '../../onboarding/data/consent_repository.dart';
import '../../onboarding/presentation/onboarding_screen.dart';
import '../../vehicle/data/vehicle_repository.dart';
import '../../diagnosis/data/report_repository.dart';
import '../data/theme_mode_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consent = ref.watch(consentProvider);
    final themeMode = ref.watch(themeModeProvider);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          const _AccountSection(),
          const SectionHeader('Görünüm'),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded), label: Text('Sistem')),
              ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('Açık')),
              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('Koyu')),
            ],
            selected: {themeMode},
            onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
          ),
          SectionHeader(
            'İzinler',
            subtitle: consent == null ? null : 'Sürüm ${consent.version} · ${Fmt.dateTime(consent.acceptedAt)}',
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: Space.xs),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Teşhis için veri işleme'),
                  subtitle: const Text('Kapatırsanız teşhis özelliği devre dışı kalır'),
                  value: consent?.diagnosis ?? false,
                  onChanged: (v) => ref.read(consentProvider.notifier).update(diagnosis: v),
                ),
                const Divider(indent: 16, endIndent: 16),
                SwitchListTile(
                  title: const Text('Modelin iyileştirilmesi'),
                  subtitle: const Text('Anonim kayıtların model eğitiminde kullanımı'),
                  value: consent?.modelImprovement ?? false,
                  onChanged: (v) => ref.read(consentProvider.notifier).update(modelImprovement: v),
                ),
                const Divider(indent: 16, endIndent: 16),
                SwitchListTile(
                  title: const Text('Bildirimler'),
                  subtitle: const Text('Bakım hatırlatmaları ve rapor bildirimleri'),
                  value: consent?.notifications ?? false,
                  onChanged: (v) => ref.read(consentProvider.notifier).update(notifications: v),
                ),
              ],
            ),
          ),
          const SectionHeader('Verilerim', subtitle: 'KVKK md. 11 kapsamındaki haklarınız'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: Space.xs),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Verilerimi dışa aktar'),
                  subtitle: const Text('Tüm veriler JSON olarak panoya kopyalanır'),
                  onTap: () async {
                    final json = const JsonEncoder.withIndent('  ').convert(ref.read(localStoreProvider).exportAll());
                    await Clipboard.setData(ClipboardData(text: json));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Verileriniz panoya kopyalandı')));
                    }
                  },
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Aydınlatma metni'),
                  onTap: () => showKvkkNotice(context),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.delete_forever_rounded, color: scheme.error),
                  title: Text('Tüm verilerimi sil', style: TextStyle(color: scheme.error)),
                  subtitle: const Text('Araçlar, raporlar ve onaylar silinir'),
                  onTap: () => _confirmDelete(context, ref),
                ),
              ],
            ),
          ),
          const SectionHeader('Hakkında'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AutoSense 0.1.0', style: t.titleSmall),
                const Gap(4),
                Text(
                  'Takım 44 · Mobil Uygulama Geliştirme. AutoSense bir ön-teşhis asistanıdır; ustanın yerini almaz.',
                  style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tüm veriler silinsin mi?'),
        content: const Text('Bu işlem geri alınamaz. Uygulama başlangıç ekranına döner.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kalıcı olarak sil'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      // Cloud first: Firestore documents, then the auth account itself.
      // TODO(backend): an onDelete auth trigger also wipes Storage media.
      await ref.read(remoteStoreProvider)?.deleteAll().timeout(const Duration(seconds: 20));
      await ref.read(authRepositoryProvider).deleteAccount();
    } on AuthFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Veriler silindi; hesap silinemedi: ${e.message}')));
      await ref.read(authRepositoryProvider).signOut();
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Silme için internet bağlantısı gerekiyor. Tekrar deneyin.')),
      );
      return;
    }
    await ref.read(localStoreProvider).clearAll();
    ref
      ..invalidate(vehiclesProvider)
      ..invalidate(activeVehicleIdProvider)
      ..invalidate(reportsProvider)
      ..invalidate(consentProvider);
  }
}

class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    if (user == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Hesap'),
        if (user.isLocal)
          const InfoBanner(
            icon: Icons.cloud_off_rounded,
            title: 'Yerel mod',
            message: 'Firebase henüz yapılandırılmadı; veriler yalnızca bu cihazda saklanıyor.',
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: Space.xs),
            child: Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: scheme.primary.withValues(alpha: 0.14),
                    child: Icon(
                      user.isAnonymous ? Icons.person_outline_rounded : Icons.person_rounded,
                      color: scheme.primary,
                    ),
                  ),
                  title: Text(user.label, style: t.titleSmall),
                  subtitle: Text(
                    user.isAnonymous
                        ? 'Misafir hesap · cihaz değişince veriler kaybolabilir'
                        : 'Veriler bulutta senkronize',
                  ),
                ),
                if (user.isAnonymous) ...[
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.link_rounded),
                    title: const Text('E-posta ile kalıcı hesaba dönüştür'),
                    onTap: () => context.push('/account/link'),
                  ),
                ],
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Çıkış yap'),
                  onTap: () => _signOut(context, ref, anonymous: user.isAnonymous),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref, {required bool anonymous}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış yapılsın mı?'),
        content: Text(
          anonymous
              ? 'Misafir hesaptan çıkarsanız bu hesaba tekrar giriş yapamazsınız. Önce e-posta ile bağlamanız önerilir.'
              : 'Verileriniz hesabınızda kalır; tekrar giriş yaptığınızda geri gelir.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Çıkış yap')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(authRepositoryProvider).signOut();
    await ref.read(localStoreProvider).clearUserData();
    ref
      ..invalidate(vehiclesProvider)
      ..invalidate(activeVehicleIdProvider)
      ..invalidate(reportsProvider);
  }
}
