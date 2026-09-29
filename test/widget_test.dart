import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:alberto50/main.dart';
import 'package:alberto50/core/providers/auth_provider.dart';
import 'package:alberto50/core/providers/membership_provider.dart';
import 'package:alberto50/core/providers/posts_provider.dart';
import 'package:alberto50/core/api/api_client.dart';
import 'package:alberto50/core/api/auth_api.dart';
import 'package:alberto50/core/api/membership_api.dart';
import 'package:alberto50/core/api/posts_api.dart';
import 'package:alberto50/core/services/auth_service.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final client = ApiClient();
    final authService = AuthService();
    final authApi = AuthApi(client);
    final membershipApi = MembershipApi(client);
    final postsApi = PostsApi(client);

    final authProvider = AuthProvider(
      authService: authService,
      apiClient: client,
      authApi: authApi,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider(create: (_) => MembershipProvider(membershipApi)),
          ChangeNotifierProvider(create: (_) => PostsProvider(postsApi)),
        ],
        child: const Alberto50App(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
