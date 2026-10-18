import 'package:flutter/material.dart';

import '../db.dart';
import '../models.dart';
import '../widgets.dart';

/// Cost-of-ownership dashboard. Amounts are grouped by currency because
/// vehicles can be registered in different countries.
class CostsScreen extends StatefulWidget {
  const CostsScreen({super.key});
  @override
  State<CostsScreen> createState() => _CostsScreenState();
}

class _Entry {
  final int vehicleId;
  final DateTime date;
  final String bucket;
  final double amount;
  final String paidBy;
  _Entry(this.vehicleId, this.date, this.bucket, this.amount, this.paidBy);
}

const _buckets = ['Service & repairs', 'Fuel / charging', 'Insurance', 'Registration', 'Tolls & parking', 'Fines', 'Loan / lease', 'Other'];

String _bucketOfExpense(String c) => switch (c) {
      ExpenseCategory.fuel => 'Fuel / charging',
      ExpenseCategory.insurance => 'Insurance',
      ExpenseCategory.registration => 'Registration',
      ExpenseCategory.tolls || ExpenseCategory.parking => 'Tolls & parking',
      ExpenseCategory.fines => 'Fines',
      ExpenseCategory.loan || ExpenseCategory.lease => 'Loan / lease',
      _ => 'Other',
    };

String _bucketOfDoc(String k) => switch (k) {
      DocKind.insurance => 'Insurance',
      DocKind.registration || DocKind.inspection => 'Registration',
      DocKind.serviceContract => 'Service & repairs',
      _ => 'Other',
    };

class _CostsScreenState extends State<CostsScreen> {
  bool _mineOnly = true;
  String _period = 'year'; // year | 12m | all
  late final Future<(List<Vehicle>, List<_Entry>)> _data = _load();

  Future<(List<Vehicle>, List<_Entry>)> _load() async {
    final db = AppDb.instance;
    final entries = <_Entry>[
      for (final s in await db.services())
        if (s.cost != null) _Entry(s.vehicleId, s.date, 'Service & repairs', s.cost!, s.paidBy ?? PaidBy.me),
      for (final d in await db.documents())
        if (d.cost != null) _Entry(d.vehicleId, d.issueDate ?? d.expiryDate ?? DateTime.now(), _bucketOfDoc(d.kind), d.cost!, d.paidBy ?? PaidBy.me),
      for (final e in await db.expenses()) _Entry(e.vehicleId, e.date, _bucketOfExpense(e.category), e.amount, e.paidBy),
    ];
    return (await db.vehicles(), entries);
  }

  bool _inPeriod(DateTime d) {
    final now = DateTime.now();
    return switch (_period) {
      'year' => d.year == now.year,
      '12m' => d.isAfter(DateTime(now.year - 1, now.month, now.day)),
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cost of ownership', style: TextStyle(fontWeight: FontWeight.w800))),
      body: FutureBuilder(
        future: _data,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final (vehicles, all) = snap.data!;
          final byId = {for (final v in vehicles) v.id!: v};
          final entries = all
              .where((e) => byId.containsKey(e.vehicleId) && _inPeriod(e.date) && (!_mineOnly || e.paidBy == PaidBy.me))
              .toList();
          final currencies = {for (final e in entries) byId[e.vehicleId]!.currency ?? ''}.toList()..sort();

          return ListView(padding: const EdgeInsets.all(16), children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'year', label: Text('This year')),
                ButtonSegment(value: '12m', label: Text('12 months')),
                ButtonSegment(value: 'all', label: Text('All time')),
              ],
              selected: {_period},
              onSelectionChanged: (s) => setState(() => _period = s.first),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Only what I paid'),
              subtitle: const Text('Turn off to include costs covered by a lease company, employer or insurer'),
              value: _mineOnly,
              onChanged: (x) => setState(() => _mineOnly = x),
            ),
            if (entries.isEmpty)
              const EmptyState(emoji: '📊', title: 'No costs in this period', message: 'Costs from services, documents and the Costs tab of each vehicle add up here.'),
            for (final cur in currencies) ..._currencyBlock(context, cur, entries.where((e) => byId[e.vehicleId]!.currency == cur).toList(), byId),
          ]);
        },
      ),
    );
  }

  List<Widget> _currencyBlock(BuildContext context, String cur, List<_Entry> es, Map<int, Vehicle> byId) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final total = es.fold<double>(0, (a, e) => a + e.amount);
    final byBucket = {for (final b in _buckets) b: es.where((e) => e.bucket == b).fold<double>(0, (a, e) => a + e.amount)}
      ..removeWhere((_, v) => v == 0);
    final maxB = byBucket.values.fold<double>(0, (a, b) => b > a ? b : a);
    final byVehicle = <int, double>{};
    for (final e in es) {
      byVehicle[e.vehicleId] = (byVehicle[e.vehicleId] ?? 0) + e.amount;
    }
    final vehiclesSorted = byVehicle.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return [
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Total', style: t.labelLarge),
            Text(fmtMoney(total, cur), style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            for (final b in byBucket.entries.toList()..sort((x, y) => y.value.compareTo(x.value)))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(b.key)),
                    Text(fmtMoney(b.value, cur), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maxB == 0 ? 0 : b.value / maxB,
                      minHeight: 8,
                      backgroundColor: cs.surfaceContainerHighest,
                    ),
                  ),
                ]),
              ),
          ]),
        ),
      ),
      if (vehiclesSorted.isNotEmpty) ...[
        const SectionTitle('By vehicle'),
        Card(
          child: Column(children: [
            for (final e in vehiclesSorted)
              ListTile(
                leading: VehicleAvatar(byId[e.key]!, size: 40),
                title: Text(byId[e.key]!.displayName),
                subtitle: Text(byId[e.key]!.isSold ? 'Sold' : Ownership.label(byId[e.key]!.ownership)),
                trailing: Text(fmtMoney(e.value, cur), style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
      ],
    ];
  }
}
