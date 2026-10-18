import 'package:flutter/material.dart';
import '../../core/env/app_config.dart';
import 'app_banner.dart';

/// Wraps pages with responsive maximum width constraints (optimal for phones
/// and tablets) and displays status banners (Demo Mode / Cohort).
class ResponsiveScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final double maxWidth;
  final bool showBanners;

  const ResponsiveScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.maxWidth = 720.0,
    this.showBanners = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: SafeArea(
        child: Column(
          children: [
            if (showBanners && AppConfig.isDemoMode) const DemoModeBanner(),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: body,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
