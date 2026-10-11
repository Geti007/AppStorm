import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/currencies.dart';
import '../data/models.dart';
import '../data/money.dart';
import '../state/app_state.dart';

String _balanceWords(int v, String cur, String Function(int, String) fmt) {
  if (v.abs() <= 1) return 'settled';
  return v > 0 ? 'gets back ${fmt(v, cur)}' : 'owes ${fmt(-v, cur)}';
}

/// The plain-text summary shared with "Share summary" (AC-31).
String tripSummaryText(AppState state, Trip trip) {
  final cur = trip.baseCurrency;
  final expenses = state.expensesOf(trip.id);
  final balances = state.balancesOf(trip);
  final total = state.totalOf(trip);
  final count = expenses.length == 1
      ? '1 expense'
      : '${expenses.length} expenses';
  final b = StringBuffer()
    ..writeln('Trippi · ${trip.name}')
    ..writeln('Total: ${formatMoney(total, cur)} ($count)')
    ..writeln()
    ..writeln('Balances');
  for (final p in trip.participants) {
    b.writeln(
      '${p.name}: ${_balanceWords(balances[p.id] ?? 0, cur, formatMoney)}',
    );
  }
  b
    ..writeln()
    ..writeln('To settle up');
  final transfers = isSettled(balances)
      ? const <Transfer>[]
      : simplifyDebts(balances);
  if (transfers.isEmpty) {
    b.writeln('Everyone is settled up.');
  }
  for (final t in transfers) {
    b.writeln(
      '${trip.nameOf(t.fromId)} pays ${trip.nameOf(t.toId)} ${formatMoney(t.amountMinor, cur)}',
    );
  }
  return b.toString().trimRight();
}

String exportFileName(Trip trip, String extension) {
  final safe = trip.name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return 'trippi-${safe.isEmpty ? 'trip' : safe}.$extension';
}

String _splitLabel(SplitMethod m) => switch (m) {
  SplitMethod.equal => 'Equally',
  SplitMethod.percent => 'By %',
  SplitMethod.custom => 'By amount',
};

/// A PDF with the summary, balances, payments and every expense (AC-32).
Future<Uint8List> tripPdf(AppState state, Trip trip) async {
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf'),
  );
  final cur = trip.baseCurrency;
  final expenses = state.expensesOf(trip.id);
  final payments = state.paymentsOf(trip.id);
  final balances = state.balancesOf(trip);
  final transfers = isSettled(balances)
      ? const <Transfer>[]
      : simplifyDebts(balances);
  final dates = DateFormat('d MMM y');
  const teal = PdfColor.fromInt(0xFF0E6E74);

  pw.Widget heading(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 18, bottom: 6),
    child: pw.Text(
      text,
      style: pw.TextStyle(font: bold, fontSize: 14, color: teal),
    ),
  );

  pw.Widget table(
    List<String> head,
    List<List<String>> rows, {
    Set<int> right = const {},
  }) => pw.TableHelper.fromTextArray(
    headers: head,
    data: rows,
    headerStyle: pw.TextStyle(font: bold, fontSize: 10),
    cellStyle: pw.TextStyle(font: regular, fontSize: 10),
    headerDecoration: const pw.BoxDecoration(
      color: PdfColor.fromInt(0xFFF1EEE7),
    ),
    border: const pw.TableBorder(
      horizontalInside: pw.BorderSide(
        color: PdfColor.fromInt(0xFFD9D4CA),
        width: 0.5,
      ),
    ),
    cellAlignments: {for (final i in right) i: pw.Alignment.centerRight},
  );

  final doc = pw.Document(title: trip.name, author: 'Trippi');
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      build: (context) => [
        pw.Text(trip.name, style: pw.TextStyle(font: bold, fontSize: 24)),
        pw.SizedBox(height: 4),
        pw.Text(
          'Total ${formatMoneyCode(state.totalOf(trip), cur)} · '
          '${expenses.length == 1 ? '1 expense' : '${expenses.length} expenses'} · '
          '${trip.participants.length} people',
          style: const pw.TextStyle(fontSize: 11),
        ),
        heading('Balances'),
        table(
          ['Person', 'Balance'],
          [
            for (final p in trip.participants)
              [
                p.name,
                _balanceWords(balances[p.id] ?? 0, cur, formatMoneyCode),
              ],
          ],
        ),
        heading('To settle up'),
        if (transfers.isEmpty) pw.Text('Everyone is settled up.'),
        if (transfers.isNotEmpty)
          table(
            ['From', 'To', 'Amount'],
            [
              for (final t in transfers)
                [
                  trip.nameOf(t.fromId),
                  trip.nameOf(t.toId),
                  formatMoneyCode(t.amountMinor, cur),
                ],
            ],
            right: {2},
          ),
        heading('Payments'),
        if (payments.isEmpty) pw.Text('No payments recorded.'),
        if (payments.isNotEmpty)
          table(
            ['Date', 'From', 'To', 'Amount'],
            [
              for (final p in payments)
                [
                  dates.format(p.date),
                  trip.nameOf(p.fromId),
                  trip.nameOf(p.toId),
                  formatMoneyCode(p.amountMinor, cur),
                ],
            ],
            right: {3},
          ),
        heading('Expenses'),
        table(
          ['Date', 'Title', 'Category', 'Paid by', 'Amount', 'In $cur'],
          [
            for (final e in expenses)
              [
                dates.format(e.date),
                e.title,
                state.category(e.categoryId).name,
                trip.nameOf(e.paidBy),
                formatMoneyCode(e.amountMinor, e.currency),
                formatMoneyCode(baseAmountOf(e, cur), cur),
              ],
          ],
          right: {4, 5},
        ),
        pw.SizedBox(height: 24),
        pw.Text(
          'Made with Trippi',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ],
    ),
  );
  return doc.save();
}

/// An Excel file with sheets Expenses, Balances and Payments (AC-33).
Uint8List tripXlsx(AppState state, Trip trip) {
  final cur = trip.baseCurrency;
  final units = currencyFor(cur).minorUnits;
  double value(int minor, int u) => minor / pow10(u);
  final book = xl.Excel.createExcel();
  final defaultSheet = book.getDefaultSheet();
  xl.TextCellValue s(String v) => xl.TextCellValue(v);
  xl.DoubleCellValue n(double v) => xl.DoubleCellValue(v);
  final dates = DateFormat('yyyy-MM-dd');

  final expenses = book['Expenses'];
  expenses.appendRow([
    s('Date'),
    s('Title'),
    s('Category'),
    s('Paid by'),
    s('Amount'),
    s('Currency'),
    s('Rate'),
    s('Amount ($cur)'),
    s('Split'),
    s('Split between'),
    s('Note'),
  ]);
  for (final e in state.expensesOf(trip.id)) {
    expenses.appendRow([
      s(dates.format(e.date)),
      s(e.title),
      s(state.category(e.categoryId).name),
      s(trip.nameOf(e.paidBy)),
      n(value(e.amountMinor, currencyFor(e.currency).minorUnits)),
      s(e.currency),
      n(e.rate),
      n(value(baseAmountOf(e, cur), units)),
      s(_splitLabel(e.method)),
      s(e.splitAmong.map(trip.nameOf).join(', ')),
      s(e.note),
    ]);
  }

  final balances = book['Balances'];
  balances.appendRow([s('Person'), s('Balance ($cur)')]);
  final b = state.balancesOf(trip);
  for (final p in trip.participants) {
    balances.appendRow([s(p.name), n(value(b[p.id] ?? 0, units))]);
  }

  final payments = book['Payments'];
  payments.appendRow([s('Date'), s('From'), s('To'), s('Amount ($cur)')]);
  for (final p in state.paymentsOf(trip.id)) {
    payments.appendRow([
      s(dates.format(p.date)),
      s(trip.nameOf(p.fromId)),
      s(trip.nameOf(p.toId)),
      n(value(p.amountMinor, units)),
    ]);
  }

  book.setDefaultSheet('Expenses');
  if (defaultSheet != null && defaultSheet != 'Expenses') {
    book.delete(defaultSheet);
  }
  return Uint8List.fromList(book.encode()!);
}
