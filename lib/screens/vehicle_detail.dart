import 'package:flutter/material.dart';

import '../db.dart';
import '../models.dart';
import '../services.dart';
import '../widgets.dart';
import 'contact_form.dart';
import 'document_form.dart';
import 'expense_form.dart';
import 'service_form.dart';
import 'vehicle_form.dart';

class VehicleDetailScreen extends StatefulWidget {
  final int vehicleId;
  const VehicleDetailScreen({super.key, required this.vehicleId});
  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _Data {
  final Vehicle vehicle;
  final List<ServiceRecord> services;
  final List<VehicleDocument> documents;
  final List<Expense> expenses;
  final List<VehicleContact> contacts;
  final List<Reminder> reminders;
  final int? odometer;
  _Data(this.vehicle, this.services, this.documents, this.expenses, this.contacts, this.reminders, this.odometer);
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 5, vsync: this)..addListener(() => setState(() {}));
  late Future<_Data?> _data = _load();

  Future<_Data?> _load() async {
    final db = AppDb.instance;
    final id = widget.vehicleId;
    final v = await db.vehicle(id);
    if (v == null) return null;
    final rem = (await db.reminders(includeSold: true)).where((r) => r.vehicleId == id).toList();
    return _Data(v, await db.services(vehicleId: id), await db.documents(vehicleId: id), await db.expenses(vehicleId: id),
        await db.contacts(vehicleId: id), rem, await db.latestOdometer(id));
  }

  void _reload() {
    setState(() => _data = _load());
    Notifier.rescheduleAll();
  }

  Future<void> _go(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _reload();
  }

  Future<void> _markSold(Vehicle v) async {
    if (v.isSold) {
      v
        ..status = 'active'
        ..soldDate = null
        ..soldPrice = null;
      await AppDb.instance.saveVehicle(v);
      _reload();
      return;
    }
    DateTime date = DateTime.now();
    final price = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Mark as sold'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('The vehicle moves to "Sold / past" with its full history kept.'),
            const SizedBox(height: 16),
            DateField(label: 'Sold on', value: date, clearable: false, onChanged: (d) => set(() => date = d ?? date)),
            const SizedBox(height: 12),
            Field(price, 'Sale price (${v.currency})', decimal: true),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Mark sold')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    v
      ..status = 'sold'
      ..soldDate = date
      ..soldPrice = parseNum(price.text);
    await AppDb.instance.saveVehicle(v);
    _reload();
  }

  Future<void> _delete(Vehicle v) async {
    final ok = await confirm(context, 'Delete ${v.displayName} permanently?',
        'All services, documents, costs and contacts for this vehicle will be erased. This cannot be undone. To keep the history, mark it as sold instead.',
        action: 'Delete forever');
    if (!ok) return;
    await AppDb.instance.deleteVehicle(v.id!);
    await Notifier.rescheduleAll();
    if (mounted) Navigator.pop(context);
  }

  Widget? _fab(Vehicle v) {
    final id = v.id!;
    final (label, icon, page) = switch (_tabs.index) {
      1 => ('Add service', Icons.build_outlined, ServiceFormScreen(vehicle: v) as Widget),
      2 => ('Add document', Icons.description_outlined, DocumentFormScreen(vehicleId: id)),
      3 => ('Add cost', Icons.receipt_long_outlined, ExpenseFormScreen(vehicle: v)),
      4 => ('Add contact', Icons.person_add_alt, ContactFormScreen(vehicleId: id)),
      _ => ('Add service', Icons.build_outlined, ServiceFormScreen(vehicle: v)),
    };
    return FloatingActionButton.extended(onPressed: () => _go(page), icon: Icon(icon), label: Text(label));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _data,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final d = snap.data;
        if (d == null) return const Scaffold(body: Center(child: Text('Vehicle not found')));
        final v = d.vehicle;
        return Scaffold(
          appBar: AppBar(
            title: Text(v.displayName),
            actions: [
              IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _go(VehicleFormScreen(vehicle: v))),
              PopupMenuButton<String>(
                onSelected: (s) {
                  if (s == 'sold') _markSold(v);
                  if (s == 'delete') _delete(v);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'sold', child: Text(v.isSold ? 'Move back to active' : 'Mark as sold')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete permanently')),
                ],
              ),
            ],
            bottom: TabBar(controller: _tabs, isScrollable: true, tabAlignment: TabAlignment.start, tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Services'),
              Tab(text: 'Documents'),
              Tab(text: 'Costs'),
              Tab(text: 'Contacts'),
            ]),
          ),
          floatingActionButton: _fab(v),
          body: TabBarView(controller: _tabs, children: [
            _Overview(d: d),
            _ServicesTab(d: d, open: _go),
            _DocumentsTab(d: d, open: _go),
            _ExpensesTab(d: d, open: _go),
            _ContactsTab(d: d, open: _go, reload: _reload),
          ]),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 140, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ]),
      );
}

class _Overview extends StatelessWidget {
  final _Data d;
  const _Overview({required this.d});

  @override
  Widget build(BuildContext context) {
    final v = d.vehicle;
    final t = Theme.of(context).textTheme;
    final myCost = d.services.where((s) => s.paidBy == PaidBy.me).fold<double>(0, (a, s) => a + (s.cost ?? 0)) +
        d.documents.where((x) => x.paidBy == PaidBy.me).fold<double>(0, (a, x) => a + (x.cost ?? 0)) +
        d.expenses.where((e) => e.paidBy == PaidBy.me).fold<double>(0, (a, e) => a + e.amount);
    final lastService = d.services.firstOrNull;
    final lastOil = d.services.where((s) => s.oilChange).firstOrNull;
    final warranties = [
      for (final s in d.services)
        for (final p in s.parts)
          if (p.warrantyUntil != null && p.warrantyUntil!.isAfter(DateTime.now())) p
    ];
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [
      Row(children: [
        VehicleAvatar(v, size: 88),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v.displayName, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            Text(v.subtitle, style: t.bodyMedium),
            const SizedBox(height: 6),
            Text(d.odometer == null ? 'Odometer not recorded yet' : 'Odometer ${fmtKm(d.odometer)}', style: t.labelLarge),
          ]),
        ),
      ]),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _Stat(label: 'Last service', value: fmtDate(lastService?.date))),
        const SizedBox(width: 8),
        Expanded(child: _Stat(label: 'Last oil change', value: fmtDate(lastOil?.date))),
        const SizedBox(width: 8),
        Expanded(child: _Stat(label: 'My total cost', value: fmtMoney(myCost, v.currency))),
      ]),
      if (d.reminders.isNotEmpty) ...[
        const SectionTitle('Coming up'),
        Card(
          child: Column(children: [
            for (final r in d.reminders.take(6))
              ListTile(
                dense: true,
                leading: Icon(Icons.schedule, color: dueColor(context, r.daysLeft)),
                title: Text(r.title),
                subtitle: Text(fmtDate(r.due)),
                trailing: Text(dueText(r.daysLeft), style: TextStyle(color: dueColor(context, r.daysLeft), fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
      ],
      if (warranties.isNotEmpty) ...[
        const SectionTitle('Parts under warranty'),
        Card(
          child: Column(children: [
            for (final p in warranties)
              ListTile(dense: true, leading: const Icon(Icons.verified_outlined), title: Text(p.name), trailing: Text('until ${fmtDate(p.warrantyUntil)}')),
          ]),
        ),
      ],
      const SectionTitle('Details'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            _InfoRow('Type', VehicleType.label(v.type)),
            _InfoRow('Make / model', [v.make, v.model].whereType<String>().join(' ').ifEmpty('—')),
            _InfoRow('Year', v.year?.toString() ?? '—'),
            _InfoRow('Plate', v.plate ?? '—'),
            _InfoRow('VIN', v.vin ?? '—'),
            _InfoRow('Colour', v.color ?? '—'),
            _InfoRow('Registered in', v.country ?? '—'),
            _InfoRow('Currently at', v.location ?? '—'),
            _InfoRow('Ownership', Ownership.label(v.ownership)),
            if (v.lessor != null) _InfoRow('Lease company', v.lessor!),
            if (v.leaseEnd != null) _InfoRow('Lease ends', fmtDate(v.leaseEnd)),
            _InfoRow(v.ownership == Ownership.leased ? 'Lease start' : 'Purchased', fmtDate(v.purchaseDate)),
            if (v.purchasePrice != null) _InfoRow('Purchase price', fmtMoney(v.purchasePrice, v.currency)),
            if (v.isSold) _InfoRow('Sold', '${fmtDate(v.soldDate)}  ${fmtMoney(v.soldPrice, v.currency)}'),
            if (v.notes != null) _InfoRow('Notes', v.notes!),
          ]),
        ),
      ),
    ]);
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

class _PaidChip extends StatelessWidget {
  final String paidBy;
  const _PaidChip(this.paidBy);
  @override
  Widget build(BuildContext context) {
    if (paidBy == PaidBy.me) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.tertiaryContainer, borderRadius: BorderRadius.circular(6)),
      child: Text('Paid by ${PaidBy.label(paidBy).toLowerCase()}', style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

typedef _Open = Future<void> Function(Widget page);

class _ServicesTab extends StatelessWidget {
  final _Data d;
  final _Open open;
  const _ServicesTab({required this.d, required this.open});

  @override
  Widget build(BuildContext context) {
    if (d.services.isEmpty) {
      return const EmptyState(emoji: '🔧', title: 'No services yet', message: 'Add a service and snap the garage invoice. Garagio reads the date, km, cost and parts.');
    }
    final cur = d.vehicle.currency;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
      itemCount: d.services.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final s = d.services[i];
        return ListTile(
          onTap: () => open(ServiceFormScreen(vehicle: d.vehicle, record: s)),
          leading: CircleAvatar(child: Icon(s.oilChange ? Icons.oil_barrel_outlined : Icons.build_outlined)),
          title: Text('${ServiceKind.label(s.kind)} · ${fmtDate(s.date)}'),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text([
              if (s.odometer != null) fmtKm(s.odometer),
              if (s.garage != null) s.garage!,
              if (s.parts.isNotEmpty) '${s.parts.length} part${s.parts.length == 1 ? '' : 's'}',
              if (s.oilChange) 'Oil changed',
            ].join(' · ')),
            if (s.description != null) Text(s.description!, maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fmtMoney(s.cost, cur), style: const TextStyle(fontWeight: FontWeight.w600)),
            _PaidChip(s.paidBy ?? PaidBy.me),
          ]),
          isThreeLine: s.description != null,
        );
      },
    );
  }
}

class _DocumentsTab extends StatelessWidget {
  final _Data d;
  final _Open open;
  const _DocumentsTab({required this.d, required this.open});

  @override
  Widget build(BuildContext context) {
    if (d.documents.isEmpty) {
      return const EmptyState(emoji: '📄', title: 'No documents', message: 'Add registration, insurance and inspection papers to get reminders before they expire.');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
      itemCount: d.documents.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final doc = d.documents[i];
        final days = doc.expiryDate == null ? null : Reminder(0, '', '', doc.expiryDate!, '').daysLeft;
        return ListTile(
          onTap: () => open(DocumentFormScreen(vehicleId: d.vehicle.id!, document: doc)),
          leading: const CircleAvatar(child: Icon(Icons.description_outlined)),
          title: Text(doc.displayTitle),
          subtitle: Text([
            if (doc.number != null) doc.number!,
            if (doc.provider != null) doc.provider!,
            'Expires ${fmtDate(doc.expiryDate)}',
          ].join(' · ')),
          trailing: days == null
              ? null
              : Text(dueText(days), style: TextStyle(color: dueColor(context, days), fontWeight: FontWeight.w600)),
        );
      },
    );
  }
}

class _ExpensesTab extends StatelessWidget {
  final _Data d;
  final _Open open;
  const _ExpensesTab({required this.d, required this.open});

  @override
  Widget build(BuildContext context) {
    if (d.expenses.isEmpty) {
      return const EmptyState(emoji: '⛽', title: 'No costs logged', message: 'Log fuel, tolls, parking, fines and other running costs. Service costs are added from the Services tab.');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
      itemCount: d.expenses.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final e = d.expenses[i];
        return ListTile(
          onTap: () => open(ExpenseFormScreen(vehicle: d.vehicle, expense: e)),
          leading: CircleAvatar(child: Icon(e.category == ExpenseCategory.fuel ? Icons.local_gas_station_outlined : Icons.receipt_outlined)),
          title: Text(ExpenseCategory.label(e.category)),
          subtitle: Text([fmtDate(e.date), if (e.odometer != null) fmtKm(e.odometer), if (e.litres != null) '${numText(e.litres)} L'].join(' · ')),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fmtMoney(e.amount, d.vehicle.currency), style: const TextStyle(fontWeight: FontWeight.w600)),
            _PaidChip(e.paidBy),
          ]),
        );
      },
    );
  }
}

class _ContactsTab extends StatelessWidget {
  final _Data d;
  final _Open open;
  final VoidCallback reload;
  const _ContactsTab({required this.d, required this.open, required this.reload});

  @override
  Widget build(BuildContext context) {
    if (d.contacts.isEmpty) {
      return const EmptyState(
          emoji: '📇',
          title: 'No contacts',
          message: 'Save your service advisor, garage, pick & drop driver and others here for one-tap calling.');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
      itemCount: d.contacts.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final c = d.contacts[i];
        final hasPhone = c.phone != null && c.phone!.isNotEmpty;
        return ListTile(
          onTap: () => open(ContactFormScreen(vehicleId: d.vehicle.id!, contact: c)),
          leading: CircleAvatar(child: Text(c.name.isEmpty ? '?' : c.name.characters.first.toUpperCase())),
          title: Row(children: [
            Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis)),
            if (c.preferred) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.star, size: 16, color: Colors.amber)),
          ]),
          subtitle: Text([ContactRole.label(c.role), if (c.company != null) c.company!].join(' · ')),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (hasPhone) IconButton(tooltip: 'Call', icon: const Icon(Icons.call), onPressed: () => Dialer.call(c.phone!)),
            if (hasPhone) IconButton(tooltip: 'WhatsApp', icon: const Icon(Icons.chat_outlined), onPressed: () => Dialer.whatsapp(c.phone!)),
          ]),
        );
      },
    );
  }
}
