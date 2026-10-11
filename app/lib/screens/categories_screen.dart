import 'package:flutter/material.dart';

import '../data/categories.dart';
import '../data/models.dart';
import '../widgets/common.dart';

/// Custom categories (Premium, AC-39).
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    final custom = state.customCategories;
    final canEdit = state.isPremium;
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              key: const Key('new_category'),
              onPressed: () => _edit(context, null),
              icon: const Icon(Icons.add),
              label: const Text('New category'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          const SectionHeader('Built-in'),
          for (final c in builtInCategories)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: CategoryBadge(category: c),
              title: Text(c.name),
            ),
          const SectionHeader('Your categories'),
          if (custom.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Create categories like "Ski pass" or "Tips".',
                key: const Key('categories_empty'),
                style: t.bodyLarge,
              ),
            ),
          for (final c in custom)
            ListTile(
              key: Key('custom_${c.name}'),
              contentPadding: const EdgeInsets.only(left: 20, right: 8),
              leading: CategoryBadge(category: customCategoryInfo(c)),
              title: Text(c.name),
              trailing: canEdit
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: Key('edit_${c.name}'),
                          tooltip: 'Edit ${c.name}',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _edit(context, c),
                        ),
                        IconButton(
                          key: Key('delete_${c.name}'),
                          tooltip: 'Delete ${c.name}',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(context, c),
                        ),
                      ],
                    )
                  : null,
            ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, CustomCategory c) async {
    final state = AppScope.read(context);
    final uses = state.categoryUseCount(c.id);
    if (uses > 0) {
      await inform(
        context,
        'Category in use',
        '${uses == 1 ? '1 expense uses' : '$uses expenses use'} this category. Move them to another category first.',
      );
      return;
    }
    final ok = await confirm(
      context,
      title: 'Delete ${c.name}?',
      confirmLabel: 'Delete',
    );
    if (ok) await state.deleteCategory(c.id);
  }

  Future<void> _edit(BuildContext context, CustomCategory? c) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _CategoryEditor(category: c),
      );
}

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({this.category});

  final CustomCategory? category;

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  late final _name = TextEditingController(text: widget.category?.name ?? '')
    ..addListener(() => setState(() => _touched = true));
  late String _icon = widget.category?.iconKey ?? 'local_activity';
  late int _color = widget.category?.colorIndex ?? 7;
  bool _touched = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? get _error {
    final name = _name.text.trim();
    if (name.isEmpty) return _touched ? 'Enter a name' : null;
    if (AppScope.read(context)
        .categoryNameTaken(name, exceptId: widget.category?.id)) {
      return 'A category with this name already exists';
    }
    return null;
  }

  bool get _valid => _name.text.trim().isNotEmpty && _error == null;

  Future<void> _save() async {
    final state = AppScope.read(context);
    await state.saveCategory(
      CustomCategory(
        id: widget.category?.id ?? newId(),
        name: _name.text.trim(),
        iconKey: _icon,
        colorIndex: _color,
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final b = Theme.of(context).brightness;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.category == null ? 'New category' : 'Edit category',
              style: t.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('category_name'),
              controller: _name,
              maxLength: 24,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: 'Name', errorText: _error),
            ),
            const SizedBox(height: 8),
            Text('Icon', style: t.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final e in categoryIcons.entries)
                  IconButton(
                    key: Key('icon_${e.key}'),
                    tooltip: e.key.replaceAll('_', ' '),
                    isSelected: _icon == e.key,
                    style: IconButton.styleFrom(
                      backgroundColor: _icon == e.key
                          ? scheme.primaryContainer
                          : null,
                    ),
                    icon: Icon(e.value),
                    onPressed: () => setState(() => _icon = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Colour', style: t.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < categoryColors.length; i++)
                  Semantics(
                    label: categoryColorNames[i],
                    selected: _color == i,
                    button: true,
                    excludeSemantics: true,
                    child: InkWell(
                      key: Key('color_$i'),
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _color = i),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: b == Brightness.dark
                              ? categoryColors[i].$2
                              : categoryColors[i].$1,
                          border: Border.all(
                            color: _color == i
                                ? scheme.onSurface
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('save_category'),
              onPressed: _valid ? _save : null,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
