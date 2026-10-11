import 'package:flutter/material.dart';

import '../data/models.dart';
import '../services/exporter.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'premium_screen.dart';

Future<void> showExportSheet(BuildContext context, Trip trip) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ExportSheet(trip: trip),
    );

enum _Kind { text, pdf, excel }

/// Share a text summary (free) or export PDF and Excel (AC-31 to AC-33).
class ExportSheet extends StatefulWidget {
  const ExportSheet({super.key, required this.trip});

  final Trip trip;

  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  _Kind? _busy;

  Future<void> _run(_Kind kind) async {
    final state = AppScope.read(context);
    if (kind != _Kind.text && !state.hasPassFeatures) {
      await openPremium(context, PaywallSource.export);
      return;
    }
    setState(() => _busy = kind);
    final files = state.services.files;
    final trip = widget.trip;
    try {
      switch (kind) {
        case _Kind.text:
          await files.shareText(
            tripSummaryText(state, trip),
            subject: trip.name,
          );
        case _Kind.pdf:
          final bytes = await tripPdf(state, trip);
          await files.shareFile(
            bytes,
            exportFileName(trip, 'pdf'),
            'application/pdf',
          );
        case _Kind.excel:
          final bytes = tripXlsx(state, trip);
          await files.shareFile(
            bytes,
            exportFileName(trip, 'xlsx'),
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          );
      }
      if (mounted) Navigator.pop(context);
    } on Object {
      if (mounted) {
        setState(() => _busy = null);
        showMessage(context, "Couldn't create the file. Please try again.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    final locked = !state.hasPassFeatures;
    Widget row(
      _Kind kind,
      IconData icon,
      String title,
      String subtitle,
      bool premium,
    ) {
      final busy = _busy == kind;
      final badge = premium && locked
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Premium', style: t.labelSmall),
            )
          : null;
      return ListTile(
        key: Key('export_${kind.name}'),
        enabled: _busy == null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Icon(icon),
        // The badge sits on the title line so it wraps with large text.
        title: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [Text(title), ?badge],
        ),
        subtitle: Text(busy ? 'Preparing…' : subtitle),
        trailing: busy
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
        onTap: () => _run(kind),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Share or export', style: t.titleLarge),
            ),
            row(
              _Kind.text,
              Icons.chat_bubble_outline,
              'Share summary',
              'Plain text for any chat app',
              false,
            ),
            row(
              _Kind.pdf,
              Icons.picture_as_pdf_outlined,
              'Export PDF',
              'Summary, balances and all expenses',
              true,
            ),
            row(
              _Kind.excel,
              Icons.table_chart_outlined,
              'Export Excel',
              'Expenses, balances and payments sheets',
              true,
            ),
          ],
        ),
      ),
    );
  }
}
