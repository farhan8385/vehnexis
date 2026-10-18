import 'package:flutter/material.dart';

import '../db.dart';
import '../models.dart';
import '../scan_parser.dart';
import '../services.dart';
import '../widgets.dart';

class DocumentFormScreen extends StatefulWidget {
  final int vehicleId;
  final VehicleDocument? document;
  const DocumentFormScreen({super.key, required this.vehicleId, this.document});
  @override
  State<DocumentFormScreen> createState() => _DocumentFormScreenState();
}

class _DocumentFormScreenState extends State<DocumentFormScreen> {
  final _form = GlobalKey<FormState>();
  late final VehicleDocument d = widget.document ?? VehicleDocument(vehicleId: widget.vehicleId);
  late final _title = TextEditingController(text: d.title);
  late final _number = TextEditingController(text: d.number);
  late final _provider = TextEditingController(text: d.provider);
  late final _cost = TextEditingController(text: numText(d.cost));
  late final _notes = TextEditingController(text: d.notes);
  String _currency = '';

  @override
  void initState() {
    super.initState();
    AppDb.instance.vehicle(widget.vehicleId).then((v) {
      if (mounted && v != null) setState(() => _currency = v.currency ?? '');
    });
  }

  Future<void> _scan() async {
    final path = await pickImage(context);
    if (path == null || !mounted) return;
    final ParsedScan r;
    try {
      r = await withProgress(context, 'Reading the document…', () => Scanner.scanFile(path));
    } catch (e) {
      toast(context, 'Could not read the image: $e');
      return;
    }
    setState(() {
      d.imagePath = path;
      if (r.expiry != null) d.expiryDate = r.expiry;
      if (r.issue != null) d.issueDate = r.issue;
      if (r.documentNumber != null && _number.text.isEmpty) _number.text = r.documentNumber!;
      if (r.total != null && _cost.text.isEmpty && d.kind == DocKind.insurance) _cost.text = numText(r.total);
    });
    toast(context, r.expiry == null ? 'No expiry date found. Please pick it.' : 'Expiry read as ${fmtDate(r.expiry)}. Please check it.');
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    String? t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    d
      ..title = t(_title)
      ..number = t(_number)
      ..provider = t(_provider)
      ..cost = parseNum(_cost.text)
      ..notes = t(_notes);
    await AppDb.instance.saveDocument(d);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Delete this document?', 'Its reminders are removed too.')) return;
    await AppDb.instance.deleteDocument(d.id!);
    await ImageStore.delete(d.imagePath);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document == null ? 'Add document' : d.displayTitle),
        actions: [
          if (widget.document != null) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline)),
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
              title: const Text('Scan the document'),
              subtitle: const Text('Reads the expiry date and number'),
              onTap: _scan,
            ),
          ),
          const SizedBox(height: 16),
          FormColumn([
            Choice<String>(label: 'Document type', value: d.kind, options: DocKind.all, labelOf: DocKind.label, onChanged: (x) => setState(() => d.kind = x)),
            if (d.kind == DocKind.other) Field(_title, 'Title', required: true),
            Field(_number, 'Number (policy / certificate)', caps: TextCapitalization.characters),
            Field(_provider, d.kind == DocKind.insurance ? 'Insurance company' : 'Issued by', caps: TextCapitalization.words),
            Row(children: [
              Expanded(child: DateField(label: 'Issued / start', value: d.issueDate, onChanged: (x) => setState(() => d.issueDate = x))),
              const SizedBox(width: 10),
              Expanded(child: DateField(label: 'Expires', value: d.expiryDate, onChanged: (x) => setState(() => d.expiryDate = x))),
            ]),
            Choice<int>(
              label: 'Remind me',
              value: d.remindDays,
              options: const [7, 14, 30, 60, 90],
              labelOf: (n) => '$n days before expiry',
              onChanged: (x) => setState(() => d.remindDays = x),
            ),
            Row(children: [
              Expanded(child: Field(_cost, 'Cost ($_currency)', decimal: true)),
              const SizedBox(width: 10),
              Expanded(
                child: Choice<String>(
                  label: 'Paid by',
                  value: d.paidBy ?? PaidBy.me,
                  options: PaidBy.all,
                  labelOf: PaidBy.label,
                  onChanged: (x) => setState(() => d.paidBy = x),
                ),
              ),
            ]),
            AttachedImage(
              path: d.imagePath,
              onAdd: () async {
                final p = await pickImage(context);
                if (p != null) setState(() => d.imagePath = p);
              },
              onRemove: () => setState(() => d.imagePath = null),
            ),
            Field(_notes, 'Notes', maxLines: 3),
          ]),
          FilledButton(onPressed: _save, child: const Padding(padding: EdgeInsets.all(12), child: Text('Save document'))),
        ]),
      ),
    );
  }
}
