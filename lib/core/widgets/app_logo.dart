import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  /// Creates an app logo widget that ensures the logo fits within its container
  ///
  /// The [size] parameter controls the size of the container.
  /// The [padding] parameter adds internal padding to ensure the logo doesn't touch the edges.
  /// The [backgroundColor] parameter sets the background color of the containing circle.
  final double size;
  final double padding;
  final Color? backgroundColor;

  const AppLogo({
    super.key,
    this.size = 50.0,
    this.padding = 8.0,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final logoImage = isDarkMode 
        ? 'assets/images/einsteini_black.png' 
        : 'assets/images/einsteini_white.png';
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Image.asset(
          logoImage,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
} 