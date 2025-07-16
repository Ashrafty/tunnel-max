import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'navigation/main_navigation.dart';
import '../providers/preferences_provider.dart';
import '../models/user_preferences.dart';

class TunnelMaxApp extends ConsumerWidget {
  const TunnelMaxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesAsync = ref.watch(userPreferencesProvider);
    
    return preferencesAsync.when(
      data: (preferences) => MaterialApp(
        title: 'TunnelMax VPN',
        theme: AppTheme.lightTheme(preferences.themeColor),
        darkTheme: AppTheme.darkTheme(preferences.themeColor),
        themeMode: preferences.themeMode.toThemeMode,
        home: const MainNavigation(),
        debugShowCheckedModeBanner: false,
      ),
      loading: () => MaterialApp(
        title: 'TunnelMax VPN',
        theme: AppTheme.defaultLightTheme,
        darkTheme: AppTheme.defaultDarkTheme,
        themeMode: ThemeMode.system,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
        debugShowCheckedModeBanner: false,
      ),
      error: (error, stackTrace) => MaterialApp(
        title: 'TunnelMax VPN',
        theme: AppTheme.defaultLightTheme,
        darkTheme: AppTheme.defaultDarkTheme,
        themeMode: ThemeMode.system,
        home: const MainNavigation(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}