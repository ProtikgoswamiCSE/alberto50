import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/api/api_client.dart';
import 'core/api/auth_api.dart';
import 'core/api/membership_api.dart';
import 'core/api/posts_api.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/membership_provider.dart';
import 'core/providers/posts_provider.dart';
import 'core/services/auth_service.dart';
import 'core/services/platform_service.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/home/home_screen.dart';
import 'features/home/tv_home_screen.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/tv_remote_binder.dart';
import 'shared/widgets/tv_remote_shortcuts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Detect TV before building the widget tree
  await PlatformService.init();

  // Lock orientation: TV = landscape, phone = portrait+landscape
  if (PlatformService.isTV) {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  // Wiring up the dependency graph
  final apiClient = ApiClient();
  final authService = AuthService();
  final authApi = AuthApi(apiClient);
  final membershipApi = MembershipApi(apiClient);
  final postsApi = PostsApi(apiClient);

  final authProvider = AuthProvider(
    authService: authService,
    apiClient: apiClient,
    authApi: authApi,
  );

  // Try restoring a previous session before showing UI
  await authProvider.tryAutoLogin();


  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => MembershipProvider(membershipApi)),
        ChangeNotifierProvider(create: (_) => PostsProvider(postsApi)),
      ],
      child: const Alberto50App(),
    ),
  );
}

class Alberto50App extends StatelessWidget {
  const Alberto50App({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PlatformService.tvMode,
      builder: (context, _, __) {
        return MaterialApp(
      title: 'Alberto50',
      navigatorKey: tvNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
          // Xiaomi / Mi TV air-mouse often reports an unknown pointer.
          PointerDeviceKind.unknown,
        },
      ),
      builder: (context, child) {
        return TvRemoteBinder(
          child: TvRemoteShortcuts(child: child ?? const SizedBox.shrink()),
        );
      },
      // Start on login or home depending on auth state
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          switch (auth.status) {
            case AuthStatus.unknown:
              return const _SplashScreen();
            case AuthStatus.authenticated:
              return PlatformService.isTV
                  ? const TvHomeScreen()
                  : const HomeScreen();
            case AuthStatus.unauthenticated:
              return const LoginScreen();
          }
        },
      ),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/home': (_) => PlatformService.isTV
            ? const TvHomeScreen()
            : const HomeScreen(),
      },
    );
      },
    );
  }
}

/// Splash shown while auto-login is checked.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Hero background
          Image.asset(
            AppTheme.heroBg,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          // Dark overlay
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppTheme.heroGradient,
            ),
          ),
          // Centered content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Blood-red glow pulse
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.8),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'HORROR',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 52,
                      color: AppTheme.textPrimary,
                      letterSpacing: 8,
                      shadows: [
                        Shadow(
                          color: AppTheme.accent.withValues(alpha: 0.6),
                          blurRadius: 20,
                        ),
                      ],
                    ),
              ),
              Text(
                'AFTER DARK',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 32,
                      color: AppTheme.accent,
                      letterSpacing: 10,
                      shadows: [
                        Shadow(
                          color: AppTheme.accent.withValues(alpha: 0.8),
                          blurRadius: 16,
                        ),
                      ],
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '— NETWORK —',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.gold,
                      letterSpacing: 6,
                      fontSize: 13,
                    ),
              ),
              const SizedBox(height: 64),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: AppTheme.accent,
                  strokeWidth: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
