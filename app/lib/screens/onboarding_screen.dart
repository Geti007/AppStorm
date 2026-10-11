import 'package:flutter/material.dart';

import '../widgets/art.dart';
import '../widgets/common.dart';

/// Three welcome pages, shown on first launch only (AC-50).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    (
      ArtKind.crew,
      'Split costs with your travel crew',
      'Add who paid, choose how to split, done.',
    ),
    (
      ArtKind.coins,
      'Any currency, one total',
      "Spend in yen, euros or pesos. Trippi converts everything to your trip's currency.",
    ),
    (
      ArtKind.settled,
      'Settle up in fewer payments',
      'Trippi works out who pays whom with the fewest transfers.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() => AppScope.read(context).completeOnboarding();

  void _next() {
    if (_page == _pages.length - 1) {
      _finish();
    } else {
      final reduce = MediaQuery.of(context).disableAnimations;
      _controller.animateToPage(
        _page + 1,
        duration: Duration(milliseconds: reduce ? 1 : 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final last = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton(
                  key: const Key('onboarding_skip'),
                  onPressed: _finish,
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (p) => setState(() => _page = p),
                itemBuilder: (context, i) {
                  final (art, title, body) = _pages[i];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        ExcludeSemantics(child: Art(art, size: 200)),
                        const SizedBox(height: 40),
                        Text(
                          title,
                          style: t.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          body,
                          style: t.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Semantics(
              label: 'Page ${_page + 1} of ${_pages.length}',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page ? scheme.primary : scheme.outline,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('onboarding_next'),
                  onPressed: _next,
                  child: Text(last ? 'Get started' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
