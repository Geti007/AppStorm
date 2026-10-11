import 'package:flutter/material.dart';

import '../data/legal.dart';
import '../widgets/common.dart';
import 'premium_screen.dart' show appleEulaUrl;

enum TextPageKind { privacy, terms }

Future<void> openTextPage(BuildContext context, TextPageKind kind) =>
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => TextPage(kind: kind)));

/// The privacy policy or terms of use (AC-34b).
class TextPage extends StatelessWidget {
  const TextPage({super.key, required this.kind});

  final TextPageKind kind;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final privacy = kind == TextPageKind.privacy;
    final sections = privacy ? privacySections : termsSections;
    final isIOS = AppScope.of(context).services.isIOS;
    return Scaffold(
      appBar: AppBar(title: Text(privacy ? 'Privacy policy' : 'Terms of use')),
      body: ListView(
        key: Key(privacy ? 'privacy_page' : 'terms_page'),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (privacy)
            Text(
              privacyUpdated,
              style: t.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          for (final (heading, body) in sections) ...[
            const SizedBox(height: 20),
            Semantics(header: true, child: Text(heading, style: t.titleMedium)),
            const SizedBox(height: 6),
            Text(body, style: t.bodyLarge),
          ],
          if (!privacy && isIOS) ...[
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('terms_eula'),
                onPressed: () =>
                    AppScope.read(context).services
                        .openUrl(Uri.parse(appleEulaUrl)),
                child: const Text('Apple Standard End User License Agreement'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
