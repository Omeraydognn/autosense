import 'package:autosense/app.dart';
import 'package:autosense/core/storage/local_store.dart';
import 'package:autosense/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  Future<void> pumpApp(WidgetTester tester, {AuthRepository? auth}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          if (auth != null) authRepositoryProvider.overrideWithValue(auth),
        ],
        child: const AutoSenseApp(useGoogleFonts: false),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('first launch shows onboarding; consents start unticked', (tester) async {
    await pumpApp(tester);
    expect(find.text('Atla'), findsOneWidget);

    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();

    expect(find.text('Verileriniz sizin kontrolünüzde'), findsOneWidget);
    for (final title in ['Teşhis için veri işleme', 'Modelin iyileştirilmesi', 'Bildirimler']) {
      await tester.scrollUntilVisible(find.text(title), 120, scrollable: find.byType(Scrollable).last);
      final box = find.descendant(
        of: find.ancestor(of: find.text(title), matching: find.byType(Row)).last,
        matching: find.byType(Checkbox),
      );
      expect(tester.widget<Checkbox>(box).value, isFalse, reason: '$title must start unticked');
    }
  });

  testWidgets('accepting consent lands on the empty garage', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Teşhis için veri işleme'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Teşhis için veri işleme'));
    await tester.pump();
    await tester.tap(find.text('Kabul et ve başla'));
    await tester.pumpAndSettle();

    expect(find.text('Garajım'), findsOneWidget);
    expect(find.text('Aracınızı ekleyin'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('with cloud auth and no session, consent leads to the sign-in screen', (tester) async {
    await pumpApp(tester, auth: _SignedOutAuth());
    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kabul et ve başla'));
    await tester.pumpAndSettle();

    expect(find.text('Tekrar hoş geldiniz'), findsOneWidget);
    expect(find.text('Misafir olarak devam et'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}

class _SignedOutAuth implements AuthRepository {
  @override
  AppUser? get currentUser => null;
  @override
  Stream<AppUser?> authStateChanges() => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
