import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color card;
  final Color mutedText;
  final Color border;
  final Color success;
  final Color warning;

  const AppColors({
    required this.card,
    required this.mutedText,
    required this.border,
    required this.success,
    required this.warning,
  });

  static const light = AppColors(
    card: Color(0xFFFFFFFF),
    mutedText: Color(0xFF6B6B6B),
    border: Color(0xFFD9D2CC),
    success: Color(0xFF2E7D32),
    warning: Color(0xFFB26A00),
  );

  static const dark = AppColors(
    card: Color(0xFF1E1E20),
    mutedText: Color(0xFFA8A3A0),
    border: Color(0xFF3A3A3D),
    success: Color(0xFF66BB6A),
    warning: Color(0xFFFFB74D),
  );

  @override
  AppColors copyWith({
    Color? card,
    Color? mutedText,
    Color? border,
    Color? success,
    Color? warning,
  }) => AppColors(
    card: card ?? this.card,
    mutedText: mutedText ?? this.mutedText,
    border: border ?? this.border,
    success: success ?? this.success,
    warning: warning ?? this.warning,
  );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      card: Color.lerp(card, other.card, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      border: Color.lerp(border, other.border, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

extension ThemeX on BuildContext {
  ColorScheme get cs => Theme.of(this).colorScheme;
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}

class AppTheme {
  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF8B2E3E),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF6F2532),
    onSecondary: Color(0xFFFFFFFF),
    error: Color(0xFFD32F2F),
    onError: Color(0xFFFFFFFF),
    surface: Color(0xFFEEE9E4),
    onSurface: Color(0xFF09090A),
    onSurfaceVariant: Color(0xFF5E5A57),
    outline: Color(0xFFB8AFA8),
    outlineVariant: Color(0xFFDDD5CF),
    surfaceContainerLow: Color(0xFFF5F1ED),
    surfaceContainer: Color(0xFFF0EAE5),
    surfaceContainerHighest: Color(0xFFEEE0E2),
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFC4566A),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFD9798A),
    onSecondary: Color(0xFF09090A),
    error: Color(0xFFFF5C5C),
    onError: Color(0xFF09090A),
    surface: Color(0xFF121212),
    onSurface: Color(0xFFEEE9E4),
    onSurfaceVariant: Color(0xFFB5AFAB),
    outline: Color(0xFF6B6664),
    outlineVariant: Color(0xFF3A3A3D),
    surfaceContainerLow: Color(0xFF1A1A1B),
    surfaceContainer: Color(0xFF1E1E20),
    surfaceContainerHighest: Color(0xFF2A2A2C),
  );

  static ThemeData get light => _build(_lightScheme, AppColors.light);
  static ThemeData get dark => _build(_darkScheme, AppColors.dark);

  static ThemeData _build(ColorScheme s, AppColors c) {
    final isDark = s.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: s,
      scaffoldBackgroundColor: s.surface,
      extensions: [c],
      dividerTheme: DividerThemeData(color: c.border, thickness: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: s.surface,
        foregroundColor: s.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: s.surfaceContainerHighest,
        hintStyle: TextStyle(color: c.mutedText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: s.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: s.primary,
          foregroundColor: s.onPrimary,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: s.primary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: s.surfaceContainer,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? s.surfaceContainerHighest : s.onSurface,
        contentTextStyle: TextStyle(color: isDark ? s.onSurface : s.surface),
      ),
    );
  }
}
