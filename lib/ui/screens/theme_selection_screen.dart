import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../../models/user_preferences.dart';
import '../../providers/preferences_provider.dart';

class ThemeSelectionScreen extends ConsumerWidget {
  const ThemeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesAsync = ref.watch(userPreferencesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme & Colors'),
      ),
      body: preferencesAsync.when(
        data: (preferences) => _buildThemeContent(context, ref, preferences),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Failed to load theme settings: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(userPreferencesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeContent(
    BuildContext context,
    WidgetRef ref,
    UserPreferences preferences,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Theme Mode Section
        _buildSectionHeader('Theme Mode'),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: AppThemeMode.values.map((mode) {
              return RadioListTile<AppThemeMode>(
                title: Text(mode.displayName),
                subtitle: Text(_getThemeModeDescription(mode)),
                value: mode,
                groupValue: preferences.themeMode,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(userPreferencesProvider.notifier).updateThemeMode(value);
                  }
                },
                secondary: Icon(_getThemeModeIcon(mode)),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 32),

        // Theme Color Section
        _buildSectionHeader('Theme Color'),
        const SizedBox(height: 12),
        _buildColorGrid(context, ref, preferences),

        const SizedBox(height: 32),

        // Preview Section
        _buildSectionHeader('Preview'),
        const SizedBox(height: 12),
        _buildPreviewCard(context, preferences),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildColorGrid(
    BuildContext context,
    WidgetRef ref,
    UserPreferences preferences,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose your preferred color scheme:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
              ),
              itemCount: AppThemeColor.values.length,
              itemBuilder: (context, index) {
                final color = AppThemeColor.values[index];
                final isSelected = preferences.themeColor == color;
                
                return GestureDetector(
                  onTap: () {
                    ref.read(userPreferencesProvider.notifier).updateThemeColor(color);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected 
                          ? color.primaryColor 
                          : Colors.grey.withOpacity(0.3),
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.primaryColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: color.primaryColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          color.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? color.primaryColor : null,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context, UserPreferences preferences) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final previewTheme = isDark 
      ? AppTheme.darkTheme(preferences.themeColor)
      : AppTheme.lightTheme(preferences.themeColor);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Preview',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Theme(
              data: previewTheme,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: previewTheme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // App Bar Preview
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: previewTheme.appBarTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          'TunnelMax VPN',
                          style: previewTheme.appBarTheme.titleTextStyle,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Button Preview
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: null,
                        style: previewTheme.elevatedButtonTheme.style,
                        child: const Text('Connect'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Switch Preview
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Auto Connect',
                          style: previewTheme.textTheme.bodyMedium,
                        ),
                        Switch(
                          value: true,
                          onChanged: null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Progress Indicator Preview
                    LinearProgressIndicator(
                      value: 0.7,
                      backgroundColor: Colors.grey.withOpacity(0.3),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getThemeModeDescription(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return 'Always use light theme';
      case AppThemeMode.dark:
        return 'Always use dark theme';
      case AppThemeMode.system:
        return 'Follow system setting';
    }
  }

  IconData _getThemeModeIcon(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
      case AppThemeMode.system:
        return Icons.settings_system_daydream;
    }
  }
}