import 'package:flutter/material.dart';

import '../db.dart';
import '../models.dart';
import '../widgets.dart';

class ExpenseFormScreen extends StatefulWidget {
  final Vehicle vehicle;
  final Expense? expense;
  const ExpenseFormScreen({super.key, required this.vehicle, this.expense});
  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _form = GlobalKey<FormState>();
  late final Expense e = widget.expense ?? Expense(vehicleId: widget.vehicle.id!, date: DateTime.now());
  late final _amount = TextEditingController(text: widget.expense == null ? '' : numText(e.amount));
  late final _odo = TextEditingController(text: e.odometer?.toString() ?? '');
  late final _litres = TextEditingController(text: numText(e.litres));
  late final _notes = TextEditingController(text: e.notes);

  void _setCategory(String c) {
    setState(() {
      e.category = c;
      // Lease payments are by the user; fuel on a company car usually is not.
      if (c == ExpenseCategory.fuel && widget.vehicle.ownership == Ownership.company) e.paidBy = PaidBy.company;
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    e
      ..amount = parseNum(_amount.text) ?? 0
      ..odometer = parseIntField(_odo.text)
      ..litres = e.category == ExpenseCategory.fuel ? parseNum(_litres.text) : null
      ..notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
    await AppDb.instance.saveExpense(e);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Delete this cost?', 'This cannot be undone.')) return;
    await AppDb.instance.deleteExpense(e.id!);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expense == null ? 'Add cost' : 'Cost'),
        actions: [
          if (widget.expense != null) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline)),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final c in ExpenseCategory.all)
              ChoiceChip(label: Text(ExpenseCategory.label(c)), selected: e.category == c, onSelected: (_) => _setCategory(c)),
          ]),
          const SizedBox(height: 16),
          FormColumn([
            Field(_amount, 'Amount (${widget.vehicle.currency})', decimal: true, required: true),
            DateField(label: 'Date', value: e.date, clearable: false, onChanged: (d) => setState(() => e.date = d ?? e.date)),
            Choice<String>(label: 'Paid by', value: e.paidBy, options: PaidBy.all, labelOf: PaidBy.label, onChanged: (x) => setState(() => e.paidBy = x)),
            Row(children: [
              Expanded(child: Field(_odo, 'Odometer (km)', number: true)),
              if (e.category == ExpenseCategory.fuel) ...[
                const SizedBox(width: 10),
                Expanded(child: Field(_litres, 'Litres / kWh', decimal: true)),
              ],
            ]),
            Field(_notes, 'Notes', maxLines: 2),
          ]),
          FilledButton(onPressed: _save, child: const Padding(padding: EdgeInsets.all(12), child: Text('Save cost'))),
        ]),
      ),
    );
  }
}
