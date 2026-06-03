import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gps_tracker/providers/theme_provider.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return IconButton(
          icon: Icon(themeProvider.themeIcon),
          onPressed: () {
            themeProvider.toggleTheme();
          },
          tooltip: themeProvider.themeName,
        );
      },
    );
  }
}
