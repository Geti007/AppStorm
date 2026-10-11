import 'package:flutter/material.dart';

import '../data/categories.dart';
import '../data/models.dart';
import '../state/app_state.dart';

/// Gives every screen access to the app state.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

/// "1 expense" / "3 expenses".
String plural(int n, String one, String many) => n == 1 ? '1 $one' : '$n $many';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.art,
    required this.title,
    required this.body,
    this.action,
  });

  final Widget art;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: SizedBox(height: 140, child: art)),
            const SizedBox(height: 24),
            Text(title, style: t.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              body,
              style: t.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: t.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your data is safe on this phone. Please try again.',
              style: t.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('retry'),
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A round avatar with the person's initials.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.size = 36});

  final String name;
  final double size;

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final first = parts.first.characters.first;
    if (parts.length == 1) return first.toUpperCase();
    return (first + parts.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final hash = name.codeUnits.fold(0, (a, c) => (a * 31 + c) & 0x7fffffff);
    final color = categoryColors[hash % 7];
    final bg = b == Brightness.dark ? color.$2 : color.$1;
    final fg = b == Brightness.dark ? const Color(0xFF0D171C) : Colors.white;
    return Semantics(
      label: name,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Text(
          initials(name),
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.38,
          ),
        ),
      ),
    );
  }
}

/// The category icon on a tinted circle.
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({super.key, required this.category, this.size = 40});

  final CategoryInfo category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = category.color(Theme.of(context).brightness);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(
        category.icon,
        color: c,
        size: size * 0.5,
        semanticLabel: category.name,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(text, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Grey placeholder cards with a shimmer, shown while data loads.
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key});

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Semantics(
      label: 'Loading',
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final o = 0.5 + 0.5 * (1 - (2 * _c.value - 1).abs());
          return ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  height: 140,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: base.withValues(alpha: o),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Shows a snackbar, replacing any visible one.
void showMessage(BuildContext context, String text, {SnackBarAction? action}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      content: Text(text),
      action: action,
      duration: action != null
          ? const Duration(seconds: 4)
          : const Duration(seconds: 3),
      persist: false,
    ),
  );
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? body,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(
          key: const Key('dialog_cancel'),
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('dialog_confirm'),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<void> inform(BuildContext context, String title, [String? body]) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: body == null ? null : Text(body),
        actions: [
          TextButton(
            key: const Key('dialog_ok'),
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );

/// Asks to delete an expense, deletes it, and offers Undo for 4 seconds
/// (AC-15). Returns true when it was deleted.
Future<bool> deleteExpenseWithUndo(BuildContext context, Expense e) async {
  final ok = await confirm(
    context,
    title: 'Delete this expense?',
    confirmLabel: 'Delete',
  );
  if (!ok || !context.mounted) return false;
  final state = AppScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    await state.deleteExpense(e);
  } on Object {
    messenger.showSnackBar(
      const SnackBar(
        content: Text("Couldn't delete the expense. Please try again."),
      ),
    );
    return false;
  }
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: const Text('Expense deleted'),
      duration: const Duration(seconds: 4),
      persist: false,
      action: SnackBarAction(
        key: const Key('undo_delete'),
        label: 'Undo',
        onPressed: () => state.saveExpense(e).catchError((Object _) {}),
      ),
    ),
  );
  return true;
}

/// Keeps the app at a readable width on tablets: wider windows show the app
/// in a centred column of [maxWidth] with a plain margin either side.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({super.key, required this.child});

  static const double maxWidth = 720;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width < maxWidth ? media.size.width : maxWidth;
    // The same widgets at every width, so rotating the device keeps the
    // navigation stack and the state of open screens.
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Center(
        child: SizedBox(
          width: width,
          child: MediaQuery(
            data: media.copyWith(size: Size(width, media.size.height)),
            child: ClipRect(child: child),
          ),
        ),
      ),
    );
  }
}
