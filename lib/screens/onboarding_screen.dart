import 'package:flutter/material.dart';
import 'package:kisekae/screens/getting_started.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.onThemeChanged});

  final ValueChanged<bool>? onThemeChanged;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToNext() {
    if (_currentPage < 2) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const GettingStartedScreen()),
      );
    }
  }

  void _skip() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GettingStartedScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        textTheme: base.textTheme
            .apply(fontFamily: 'sans-serif')
            .copyWith(
              headlineLarge: base.textTheme.headlineLarge?.copyWith(
                fontFamily: 'PlayfairDisplay',
                fontFamilyFallback: const ['serif'],
                fontSize: 32,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
              titleLarge: base.textTheme.titleLarge?.copyWith(
                fontFamily: 'sans-serif',
                fontSize: 20,
                height: 1.25,
                fontWeight: FontWeight.w400,
              ),
              titleMedium: base.textTheme.titleMedium?.copyWith(
                fontFamily: 'sans-serif',
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              labelLarge: base.textTheme.labelLarge?.copyWith(
                fontFamily: 'sans-serif',
                fontSize: 12,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w400,
              ),
            ),
      ),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          final textTheme = theme.textTheme;
          final isDark = theme.brightness == Brightness.dark;

          return Scaffold(
            appBar: AppBar(
              surfaceTintColor: Colors.transparent,
              leading: _currentPage > 0
                  ? IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.onSurface, width: 2),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: scheme.onSurface,
                        ),
                      ),
                      onPressed: () {
                        _controller.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      padding: EdgeInsets.zero,
                    )
                  : null,
              actions: [
                if (_currentPage == 0)
                  _ThemeToggle(
                    isDark: isDark,
                    onChanged: widget.onThemeChanged,
                  ),
                if (_currentPage == 0) const SizedBox(width: 16),
                TextButton(
                  onPressed: _skip,
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurface,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text('skip', style: textTheme.titleMedium),
                ),
                const SizedBox(width: 12),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: PageView(
                      controller: _controller,
                      onPageChanged: (index) {
                        setState(() => _currentPage = index);
                      },
                      children: [
                        _Page1(scheme: scheme, textTheme: textTheme),
                        _Page2(scheme: scheme, textTheme: textTheme),
                        _Page3(scheme: scheme, textTheme: textTheme),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (index) {
                            final isActive = index == _currentPage;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isActive
                                    ? scheme.secondary
                                    : scheme.primary.withValues(alpha: 0.25),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton(
                            onPressed: _goToNext,
                            style: FilledButton.styleFrom(
                              backgroundColor: scheme.primary,
                              foregroundColor: scheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'CONTINUE',
                              style: textTheme.labelLarge?.copyWith(
                                color: scheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Page1 extends StatelessWidget {
  const _Page1({required this.scheme, required this.textTheme});

  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            'Your style,\nnow in AR',
            style: textTheme.headlineLarge?.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: 20),
          Text(
            'Try on outfits ,see the fit,\nfeel the confidence -\nbefore you buy.',
            style: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: 20),
          Flexible(
            child: SizedBox(
              height: size.height * 0.4,
              child: Center(
                child: Image.asset(
                  'assets/images/onboarding1.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Page2 extends StatelessWidget {
  const _Page2({required this.scheme, required this.textTheme});

  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            'Find your\nnext look',
            style: textTheme.headlineLarge?.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: 20),
          Text(
            'Mix match and explore pieces\nthat bring your personal\nstyle together.',
            style: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: 20),
          Flexible(
            child: SizedBox(
              height: size.height * 0.4,
              child: Align(
                alignment: Alignment.topCenter,
                child: AspectRatio(
                  aspectRatio: 326 / 289,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 48,
                        child: _ImageTile(
                          child: Image.asset(
                            'assets/images/collage1.png',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                      const Expanded(flex: 4, child: SizedBox()),
                      Expanded(
                        flex: 48,
                        child: Column(
                          children: [
                            Expanded(
                              flex: 41,
                              child: SizedBox.expand(
                                child: _ImageTile(
                                  child: Image.asset(
                                    'assets/images/collage2.png',
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                              ),
                            ),
                            const Expanded(flex: 4, child: SizedBox()),
                            Expanded(
                              flex: 55,
                              child: SizedBox.expand(
                                child: _ImageTile(
                                  child: Image.asset(
                                    'assets/images/collage3.png',
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Page3 extends StatelessWidget {
  const _Page3({required this.scheme, required this.textTheme});

  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 15),
          Text(
            'Curated,\nfor you',
            style: textTheme.headlineLarge?.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: 20),
          Text(
            'Discover styles that match\nyour vibe, preference\nand mood.',
            style: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: 20),
          Flexible(
            child: SizedBox(
              height: size.height * 0.4,
              child: Align(
                alignment: Alignment.topCenter,
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/onboarding3.png',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        color: scheme.surfaceContainerHighest,
        child:
            child ??
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 22, height: 22),
                  const SizedBox(height: 8),
                ],
              ),
            ),
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({required this.isDark, this.onChanged});

  final bool isDark;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const double width = 64;
    const double height = 30;
    const double thumb = 24;

    return GestureDetector(
      onTap: () => onChanged?.call(!isDark),
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(height),
          border: Border.all(color: scheme.onSurface, width: 1.2),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: thumb,
                  child: Icon(
                    Icons.wb_sunny_rounded,
                    size: 14,
                    color: scheme.onSurface,
                  ),
                ),
                SizedBox(
                  width: thumb,
                  child: Icon(
                    Icons.nightlight_round,
                    size: 14,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: thumb,
                height: thumb,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary,
                ),
                child: Icon(
                  isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                  size: 14,
                  color: scheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
