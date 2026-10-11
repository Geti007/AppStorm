import 'package:flutter/material.dart';

import '../data/currencies.dart';
import 'common.dart';

/// A searchable sheet of all currencies; returns the chosen code.
Future<String?> pickCurrency(BuildContext context) async {
  final code = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _CurrencySheet(),
  );
  if (code != null && context.mounted) {
    await AppScope.read(context).useCurrency(code);
  }
  return code;
}

class _CurrencySheet extends StatefulWidget {
  const _CurrencySheet();

  @override
  State<_CurrencySheet> createState() => _CurrencySheetState();
}

class _CurrencySheetState extends State<_CurrencySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final recent = AppScope.of(context).recentCurrencies;
    final results = searchCurrencies(_query);
    final t = Theme.of(context).textTheme;
    final rows = <Widget>[];
    if (_query.isEmpty && recent.isNotEmpty) {
      rows.add(const SectionHeader('Recent'));
      rows.addAll(recent.map((c) => _row(currencyFor(c))));
      rows.add(const SectionHeader('All currencies'));
    }
    rows.addAll(results.map(_row));
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: TextField(
              key: const Key('currency_search'),
              autofocus: false,
              decoration: const InputDecoration(
                hintText: 'Search currencies',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No currency matches "$_query"',
                      style: t.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView(children: rows),
          ),
        ],
      ),
    );
  }

  Widget _row(Currency c) {
    final t = Theme.of(context).textTheme;
    return ListTile(
      key: Key('currency_${c.code}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(c.code, style: t.titleMedium),
      subtitle: Text(c.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (c.hasAutoRate)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Auto rate', style: t.labelSmall),
            ),
          const SizedBox(width: 12),
          Text(c.symbol, style: t.titleMedium),
        ],
      ),
      onTap: () => Navigator.pop(context, c.code),
    );
  }
}
