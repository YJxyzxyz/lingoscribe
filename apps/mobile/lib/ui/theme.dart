import '../l10n/l10n.dart';
import 'package:flutter/material.dart';

const forest = Color(0xff245b49);
const paper = Color(0xfff7f8f4);
const ink = Color(0xff172b25);
const muted = Color(0xff64746d);
const outline = Color(0xffdde5df);
const softForest = Color(0xffedf4ee);

ThemeData appTheme({String? fontFamily}) {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: forest,
        brightness: Brightness.light,
        surface: paper,
      ).copyWith(
        primary: forest,
        onPrimary: Colors.white,
        primaryContainer: Color(0xffdceade),
        onPrimaryContainer: ink,
        secondary: forest,
        onSecondary: Colors.white,
        secondaryContainer: softForest,
        onSecondaryContainer: forest,
        onSurface: ink,
        onSurfaceVariant: muted,
      );
  return ThemeData(
    fontFamily: fontFamily,
    useMaterial3: true,
    colorScheme: scheme,
    visualDensity: VisualDensity.standard,
    scaffoldBackgroundColor: paper,
    appBarTheme: AppBarTheme(
      backgroundColor: paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: ink,
      centerTitle: false,
    ),
    textTheme: TextTheme(
      displaySmall: TextStyle(
        fontSize: 36,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: ink,
        letterSpacing: -1,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.55, color: ink),
      bodyMedium: TextStyle(fontSize: 14, height: 1.55, color: ink),
      bodySmall: TextStyle(fontSize: 12, height: 1.5, color: muted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: forest, width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: forest,
        foregroundColor: Colors.white,
        minimumSize: Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: Size(0, 50),
        foregroundColor: forest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: Color(0xffc9d9cf)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: paper,
      indicatorColor: Color(0xffdceade),
      elevation: 0,
      height: 68,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: forest,
      linearTrackColor: outline,
      borderRadius: BorderRadius.circular(8),
      linearMinHeight: 5,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: ink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerColor: Color(0xffdce4dc),
  );
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 44});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: l10n(context).brandSemantics,
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _BrandPainter()),
    ),
  );
}

class _BrandPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size.width * .27)),
      Paint()..color = forest,
    );
    final paint = Paint()
      ..color = Color(0xffedf5d9)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * .065;
    const heights = [.2, .38, .55, .38, .2];
    for (var i = 0; i < heights.length; i++) {
      final x = size.width * (.25 + i * .125);
      canvas.drawLine(
        Offset(x, size.height * (.5 - heights[i] / 2)),
        Offset(x, size.height * (.5 + heights[i] / 2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.selected = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool selected;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: selected ? softForest : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: selected ? forest : outline),
    ),
    child: child,
  );
}

class PrivacyBadge extends StatelessWidget {
  const PrivacyBadge({super.key});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.shield_outlined, size: 15, color: forest),
      SizedBox(width: 5),
      Flexible(
        child: Text(
          l10n(context).onYourDeviceOnly,
          style: TextStyle(fontSize: 12, color: forest),
        ),
      ),
    ],
  );
}

void showError(BuildContext context, Object error) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(friendlyError(context, error)),
        behavior: SnackBarBehavior.floating,
      ),
    );
