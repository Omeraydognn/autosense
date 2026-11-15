import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/capture/presentation/capture_screen.dart';
import '../../features/diagnosis/data/diagnosis_service.dart';
import '../../features/diagnosis/presentation/checklist_screen.dart';
import '../../features/diagnosis/presentation/diagnosing_screen.dart';
import '../../features/diagnosis/presentation/history_screen.dart';
import '../../features/diagnosis/presentation/report_screen.dart';
import '../../features/onboarding/data/consent_repository.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/vehicle/presentation/garage_screen.dart';
import '../../features/vehicle/presentation/vehicle_form_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  // Re-evaluate redirects when consent or auth changes, without rebuilding the router.
  final refresh = ValueNotifier<int>(0);
  ref
    // Only the gate conditions matter; reacting to every user change (e.g. an
    // email being linked) would rebuild open pages mid-flow.
    ..listen(consentProvider.select((c) => c != null), (_, _) => refresh.value++)
    ..listen(authStateProvider.select((u) => u != null), (_, _) => refresh.value++)
    ..onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/garage',
    refreshListenable: refresh,
    redirect: (context, state) {
      final consented = ref.read(consentProvider) != null;
      final signedIn = ref.read(authStateProvider) != null;
      final loc = state.matchedLocation;

      // 1) KVKK consent first, 2) then an account (guest or email).
      if (!consented) return loc == '/onboarding' ? null : '/onboarding';
      if (!signedIn) return loc == '/sign-in' ? null : '/sign-in';
      if (loc == '/onboarding' || loc == '/sign-in') return '/garage';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
      GoRoute(
        path: '/account/link',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const SignInScreen(linkMode: true),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/garage', builder: (_, _) => const GarageScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/diagnose', builder: (_, _) => const CaptureScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/history', builder: (_, _) => const HistoryScreen())],
          ),
        ],
      ),
      GoRoute(path: '/vehicle/new', parentNavigatorKey: _rootKey, builder: (_, _) => const VehicleFormScreen()),
      GoRoute(
        path: '/vehicle/:id/edit',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => VehicleFormScreen(vehicleId: s.pathParameters['id']),
      ),
      GoRoute(
        path: '/diagnosing',
        parentNavigatorKey: _rootKey,
        redirect: (_, s) => s.extra is CaptureRequest ? null : '/diagnose',
        builder: (_, s) => DiagnosingScreen(request: s.extra! as CaptureRequest),
      ),
      GoRoute(
        path: '/report/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => ReportScreen(reportId: s.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'checklist',
            parentNavigatorKey: _rootKey,
            builder: (_, s) => ChecklistScreen(reportId: s.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(path: '/settings', parentNavigatorKey: _rootKey, builder: (_, _) => const SettingsScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
