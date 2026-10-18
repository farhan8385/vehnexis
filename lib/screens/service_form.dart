import 'package:flutter/material.dart';

import '../db.dart';
import '../models.dart';
import '../scan_parser.dart';
import '../services.dart';
import '../widgets.dart';

class ServiceFormScreen extends StatefulWidget {
  final Vehicle vehicle;
  final ServiceRecord? record;
  const ServiceFormScreen({super.key, required this.vehicle, this.record});
  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _PartRow {
  final name = TextEditingController();
  final cost = TextEditingController();
  int? warrantyMonths;
  bool asked;
  _PartRow({String n = '', double? c, this.warrantyMonths, this.asked = false}) {
    name.text = n;
    cost.text = numText(c);
  }
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  final _form = GlobalKey<FormState>();
  late final ServiceRecord s = widget.record ??
      ServiceRecord(
        vehicleId: widget.vehicle.id!,
        date: DateTime.now(),
        paidBy: Ownership.defaultServicePayer(widget.vehicle.ownership),
      );
  late final _odo = TextEditingController(text: s.odometer?.toString() ?? '');
  late final _garage = TextEditingController(text: s.garage);
  late final _desc = TextEditingController(text: s.description);
  late final _cost = TextEditingController(text: numText(s.cost));
  late final _nextKm = TextEditingController(text: s.nextDueKm?.toString() ?? '');
  late final _notes = TextEditingController(text: s.notes);
  late final List<_PartRow> _parts = [
    for (final p in s.parts) _PartRow(n: p.name, c: p.cost, warrantyMonths: p.warrantyMonths, asked: p.warrantyAsked),
  ];
  String get _cur => widget.vehicle.currency ?? '';

  @override
  void initState() {
    super.initState();
    if (widget.record == null) _prefillGarage();
  }

  Future<void> _prefillGarage() async {
    final contacts = await AppDb.instance.contacts(vehicleId: widget.vehicle.id);
    final g = contacts.where((c) => c.role == ContactRole.garage || c.role == ContactRole.serviceAdvisor).toList()
      ..sort((a, b) => (b.preferred ? 1 : 0) - (a.preferred ? 1 : 0));
    if (g.isNotEmpty && _garage.text.isEmpty && mounted) {
      setState(() => _garage.text = g.first.company ?? g.first.name);
    }
  }

  Future<void> _scan() async {
    final path = await pickImage(context);
    if (path == null || !mounted) return;
    final ParsedScan r;
    try {
      r = await withProgress(context, 'Reading the invoice…', () => Scanner.scanFile(path));
    } catch (e) {
      toast(context, 'Could not read the image: $e');
      return;
    }
    setState(() {
      s.imagePath = path;
      if (r.invoiceDate != null) s.date = r.invoiceDate!;
      if (r.odometer != null && _odo.text.isEmpty) _odo.text = '${r.odometer}';
      if (r.total != null && _cost.text.isEmpty) _cost.text = numText(r.total);
      if (r.garage != null && _garage.text.isEmpty) _garage.text = r.garage!;
      if (r.oilChange) s.oilChange = true;
      final existing = _parts.map((p) => p.name.text.toLowerCase()).toSet();
      for (final name in r.parts) {
        if (!existing.contains(name.toLowerCase())) _parts.add(_PartRow(n: name));
      }
      if (_desc.text.isEmpty && r.parts.isNotEmpty) _desc.text = r.parts.take(4).join(', ');
    });
    toast(
        context,
        r.isEmpty
            ? 'Nothing recognised. The photo is attached; please type the details.'
            : 'Read the invoice${r.parts.isNotEmpty ? ' and found ${r.parts.length} part(s)' : ''}. Please check and remove anything wrong.');
  }

  void _suggestNext() {
    setState(() {
      s.nextDueDate = DateTime(s.date.year, s.date.month + 6, s.date.day);
      final odo = parseIntField(_odo.text);
      if (odo != null) _nextKm.text = '${odo + 10000}';
    });
  }

  /// Asks, for every new part, whether it is under warranty and for how long.
  Future<bool> _askWarranty() async {
    final pending = _parts.where((p) => !p.asked && p.name.text.trim().isNotEmpty).toList();
    if (pending.isEmpty) return true;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.8),
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
              Text('Are these parts under warranty?', style: Theme.of(c).textTheme.titleLarge),
              const SizedBox(height: 4),
              const Text('Pick how long each warranty lasts. Garagio reminds you before it ends.'),
              const SizedBox(height: 12),
              for (final p in pending) ...[
                Text(p.name.text, style: const TextStyle(fontWeight: FontWeight.w600)),
                Wrap(spacing: 6, children: [
                  for (final m in const [0, 3, 6, 12, 24, 36])
                    ChoiceChip(
                      label: Text(m == 0 ? 'No' : (m < 12 ? '$m months' : '${m ~/ 12} year${m > 12 ? 's' : ''}')),
                      selected: (p.warrantyMonths ?? 0) == m,
                      onSelected: (_) => set(() => p.warrantyMonths = m == 0 ? null : m),
                    ),
                ]),
                const SizedBox(height: 10),
              ],
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Done')),
            ]),
          ),
        ),
      ),
    );
    if (ok != true) return false;
    for (final p in pending) {
      p.asked = true;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (!await _askWarranty()) return;
    String? t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    s
      ..odometer = parseIntField(_odo.text)
      ..garage = t(_garage)
      ..description = t(_desc)
      ..cost = parseNum(_cost.text)
      ..nextDueKm = parseIntField(_nextKm.text)
      ..notes = t(_notes)
      ..parts = [
        for (final p in _parts)
          if (p.name.text.trim().isNotEmpty)
            Part(
              vehicleId: s.vehicleId,
              name: p.name.text.trim(),
              cost: parseNum(p.cost.text),
              warrantyMonths: p.warrantyMonths,
              warrantyUntil: p.warrantyMonths == null
                  ? null
                  : DateTime(s.date.year, s.date.month + p.warrantyMonths!, s.date.day),
              warrantyAsked: p.asked,
            ),
      ];
    await AppDb.instance.saveService(s);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Delete this service record?', 'Its parts and warranty reminders are removed too.')) return;
    await AppDb.instance.deleteService(s.id!);
    await ImageStore.delete(s.imagePath);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final leased = widget.vehicle.ownership == Ownership.leased;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.record == null ? 'Add service' : 'Service record'),
        actions: [
          if (widget.record != null) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline)),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: ListTile(
              leading: const Icon(Icons.document_scanner_outlined, size: 32),
              title: const Text('Scan garage invoice'),
              subtitle: const Text('Reads date, km, total and replaced parts'),
              onTap: _scan,
            ),
          ),
          const SizedBox(height: 16),
          FormColumn([
            Choice<String>(label: 'Type of work', value: s.kind, options: ServiceKind.all, labelOf: ServiceKind.label, onChanged: (x) => setState(() => s.kind = x)),
            Row(children: [
              Expanded(child: DateField(label: 'Date', value: s.date, clearable: false, onChanged: (d) => setState(() => s.date = d ?? s.date))),
              const SizedBox(width: 10),
              Expanded(child: Field(_odo, 'Odometer (km)', number: true)),
            ]),
            Field(_garage, 'Garage / dealer', caps: TextCapitalization.words),
            Field(_desc, 'Work done', maxLines: 2),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Oil change done'),
              value: s.oilChange,
              onChanged: (x) => setState(() => s.oilChange = x),
            ),
            Row(children: [
              Expanded(child: Field(_cost, 'Total cost ($_cur)', decimal: true)),
              const SizedBox(width: 10),
              Expanded(
                child: Choice<String>(
                  label: 'Paid by',
                  value: s.paidBy ?? PaidBy.me,
                  options: PaidBy.all,
                  labelOf: PaidBy.label,
                  onChanged: (x) => setState(() => s.paidBy = x),
                ),
              ),
            ]),
            if (leased && s.paidBy == PaidBy.lessor)
              Text('Leased vehicle: this cost is shown in history but not counted in your own spending.',
                  style: Theme.of(context).textTheme.bodySmall),
          ]),
          Row(children: [
            const Expanded(child: SectionTitle('Parts replaced')),
            TextButton.icon(onPressed: () => setState(() => _parts.add(_PartRow())), icon: const Icon(Icons.add), label: const Text('Add part')),
          ]),
          if (_parts.isEmpty) const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('No parts listed.')),
          for (final p in _parts)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Expanded(flex: 3, child: Field(p.name, 'Part', caps: TextCapitalization.words)),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: Field(p.cost, 'Cost', decimal: true)),
                IconButton(
                  tooltip: p.warrantyMonths == null ? 'No warranty' : '${p.warrantyMonths} months warranty',
                  icon: Icon(p.warrantyMonths == null ? Icons.shield_outlined : Icons.verified, color: p.warrantyMonths == null ? null : Colors.green),
                  onPressed: () => setState(() => p.asked = false),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _parts.remove(p))),
              ]),
            ),
          Row(children: [
            const Expanded(child: SectionTitle('Next service')),
            TextButton(onPressed: _suggestNext, child: const Text('+6 months / +10,000 km')),
          ]),
          FormColumn([
            Row(children: [
              Expanded(child: DateField(label: 'Due date', value: s.nextDueDate, onChanged: (d) => setState(() => s.nextDueDate = d))),
              const SizedBox(width: 10),
              Expanded(child: Field(_nextKm, 'Due at (km)', number: true)),
            ]),
            AttachedImage(
              path: s.imagePath,
              onAdd: () async {
                final pth = await pickImage(context);
                if (pth != null) setState(() => s.imagePath = pth);
              },
              onRemove: () => setState(() => s.imagePath = null),
            ),
            Field(_notes, 'Notes', maxLines: 3),
          ]),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Padding(padding: EdgeInsets.all(12), child: Text('Save service'))),
        ]),
      ),
    );
  }
}
