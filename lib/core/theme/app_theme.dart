import 'package:flutter/material.dart';

class AppTheme {
  static const String fontFamily = 'NiuniuUiFont';
  static const Color background = Color(0xFFF4F6F8);
  static const Color backgroundMid = Color(0xFFE9EEF5);
  static const Color backgroundAccent = Color(0xFFF9FBFE);
  static const Color shell = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF6F8FB);
  static const Color surfaceStrong = Color(0xFFE4EAF2);
  static const Color glass = Color(0xF7FFFFFF);
  static const Color glassSoft = Color(0xF0F8FAFD);
  static const Color text = Color(0xFF17212B);
  static const Color mutedText = Color(0xFF667085);
  static const Color primary = Color(0xFF2D83F8);
  static const Color secondary = Color(0xFFFF9800);
  static const Color success = Color(0xFF13A05F);
  static const Color danger = Color(0xFFD7403D);
  static const Color rise = Color(0xFFE02828);
  static const Color fall = Color(0xFF0A8F3D);
  static const Color primarySoft = Color(0xFFEAF3FF);
  static const Color secondarySoft = Color(0xFFFFF4E0);
  static const Color successSoft = Color(0xFFEAF7EF);
  static const Color dangerSoft = Color(0xFFFFEEEE);
  static const Color neutralSoft = Color(0xFFF2F5F8);
  static const Color primaryOutline = Color(0x332D83F8);
  static const Color secondaryOutline = Color(0x33FF9800);
  static const Color successOutline = Color(0x3313A05F);
  static const Color dangerOutline = Color(0x33D7403D);
  static const Color primaryTint = Color(0x262D83F8);
  static const Color secondaryTint = Color(0x26FF9800);
  static const Color successTint = Color(0x2613A05F);
  static const Color dangerTint = Color(0x26D7403D);
  static const Color outline = Color(0x1A17212B);
  static const Color outlineStrong = Color(0x3317212B);

  static const LinearGradient backdropGradient = LinearGradient(
    colors: <Color>[
      Color(0xFFF9FBFE),
      Color(0xFFF3F6FA),
      Color(0xFFEAF0F7),
      Color(0xFFFFFFFF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const List<String> _cjkFallback = <String>[
    'Noto Sans SC',
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'PingFang SC',
    'Arial',
    'sans-serif',
  ];

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      secondary: secondary,
      surface: surface,
      onSurface: text,
      outline: outlineStrong,
      outlineVariant: outline,
      surfaceTint: Colors.transparent,
      error: danger,
    );
    final textTheme = const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: text,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: text,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: text,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: text,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: text,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: TextStyle(
        fontSize: 13,
        height: 1.45,
        color: mutedText,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.4,
        color: mutedText,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: text,
      ),
      labelMedium: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: mutedText,
      ),
    ).apply(
      fontFamily: fontFamily,
      fontFamilyFallback: _cjkFallback,
      bodyColor: text,
      displayColor: text,
    );

    return ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      brightness: Brightness.light,
      fontFamily: fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: Colors.transparent,
      dividerColor: outline,
      visualDensity: VisualDensity.compact,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: glass,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: outline),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface.withValues(alpha: 0.98),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSoft,
        hintStyle: const TextStyle(
          color: mutedText,
          fontSize: 13,
          fontFamily: fontFamily,
          fontFamilyFallback: _cjkFallback,
        ),
        labelStyle: const TextStyle(
          color: mutedText,
          fontSize: 13,
          fontFamily: fontFamily,
          fontFamilyFallback: _cjkFallback,
        ),
        helperStyle: const TextStyle(
          color: mutedText,
          fontSize: 12,
          fontFamily: fontFamily,
          fontFamilyFallback: _cjkFallback,
        ),
        errorStyle: const TextStyle(
          color: danger,
          fontSize: 12,
          fontFamily: fontFamily,
          fontFamilyFallback: _cjkFallback,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: _inputBorder(outline),
        enabledBorder: _inputBorder(outline),
        focusedBorder: _inputBorder(primary.withValues(alpha: 0.70)),
        errorBorder: _inputBorder(danger.withValues(alpha: 0.60)),
        focusedErrorBorder: _inputBorder(danger.withValues(alpha: 0.80)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: primary.withValues(alpha: 0.24)),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFamily: fontFamily,
            fontFamilyFallback: _cjkFallback,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          side: const BorderSide(color: outlineStrong),
          backgroundColor: surface.withValues(alpha: 0.86),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFamily: fontFamily,
            fontFamilyFallback: _cjkFallback,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: text,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFamily: fontFamily,
            fontFamilyFallback: _cjkFallback,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceSoft,
        selectedColor: primary.withValues(alpha: 0.14),
        side: const BorderSide(color: outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        labelStyle: const TextStyle(
          fontSize: 12,
          color: text,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
          fontFamilyFallback: _cjkFallback,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: outline,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: surfaceStrong,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(
          primary.withValues(alpha: 0.28),
        ),
        trackColor: WidgetStateProperty.all(
          surfaceStrong.withValues(alpha: 0.42),
        ),
        radius: const Radius.circular(999),
        thickness: WidgetStateProperty.all(8),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface.withValues(alpha: 0.98),
        contentTextStyle: const TextStyle(
          color: text,
          fontSize: 13,
          fontFamily: fontFamily,
          fontFamilyFallback: _cjkFallback,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: outline),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(
          primary.withValues(alpha: 0.06),
        ),
        dividerThickness: 1,
        decoration: BoxDecoration(
          border: Border.all(color: outline),
          borderRadius: BorderRadius.circular(8),
        ),
        dataRowMinHeight: 42,
        dataRowMaxHeight: 52,
        dataTextStyle: const TextStyle(
          fontSize: 13,
          color: text,
          height: 1.4,
          fontFamily: fontFamily,
          fontFamilyFallback: _cjkFallback,
        ),
        headingTextStyle: const TextStyle(
          fontSize: 12,
          color: mutedText,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          fontFamily: fontFamily,
          fontFamilyFallback: _cjkFallback,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        labelColor: text,
        unselectedLabelColor: mutedText,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontFamily: fontFamily,
          fontFamilyFallback: _cjkFallback,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
          fontFamilyFallback: _cjkFallback,
        ),
        indicator: BoxDecoration(
          color: primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: outlineStrong),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface.withValues(alpha: 0.96),
        indicatorColor: primary.withValues(alpha: 0.10),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
            color: states.contains(WidgetState.selected) ? text : mutedText,
            fontFamily: fontFamily,
            fontFamilyFallback: _cjkFallback,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? primary : mutedText,
            size: 22,
          ),
        ),
      ),
    );
  }

  static BoxDecoration panelDecoration({
    double radius = 8,
    Color? color,
    Color? borderColor,
    Gradient? gradient,
    bool elevated = true,
  }) {
    return BoxDecoration(
      color: gradient == null ? (color ?? glass) : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? outline),
      boxShadow: elevated
          ? const <BoxShadow>[
              BoxShadow(
                color: Color(0x1017212B),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ]
          : null,
    );
  }

  static BoxDecoration chipDecoration({
    double radius = 6,
    Color? color,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: color ?? surfaceSoft,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? outline),
    );
  }

  static OutlineInputBorder _inputBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color),
    );
  }
}
