import 'package:flutter/material.dart';

import '../db.dart';
import '../models.dart';
import '../services.dart';
import '../widgets.dart';

class ContactFormScreen extends StatefulWidget {
  final int vehicleId;
  final VehicleContact? contact;
  const ContactFormScreen({super.key, required this.vehicleId, this.contact});
  @override
  State<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends State<ContactFormScreen> {
  final _form = GlobalKey<FormState>();
  late final VehicleContact c = widget.contact ?? VehicleContact(vehicleId: widget.vehicleId);
  late final _name = TextEditingController(text: c.name);
  late final _phone = TextEditingController(text: c.phone);
  late final _company = TextEditingController(text: c.company);
  late final _notes = TextEditingController(text: c.notes);

  Future<void> _pickFromPhone() async {
    try {
      final r = await Dialer.pickFromPhone();
      if (r == null) return;
      setState(() {
        _name.text = r.$1;
        if (r.$2 != null) _phone.text = r.$2!;
      });
    } catch (e) {
      toast(context, 'Could not open contacts: $e');
    }
  }

  void _apply() {
    String? t(TextEditingController x) => x.text.trim().isEmpty ? null : x.text.trim();
    c
      ..name = _name.text.trim()
      ..phone = t(_phone)
      ..company = t(_company)
      ..notes = t(_notes);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    _apply();
    await AppDb.instance.saveContact(c);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _saveToPhone() async {
    _apply();
    try {
      await Dialer.saveToPhone(c);
    } catch (e) {
      toast(context, 'Could not open contacts: $e');
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Remove this contact?', 'It is removed from this vehicle only, not from your phone.', action: 'Remove')) return;
    await AppDb.instance.deleteContact(c.id!);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone = _phone.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contact == null ? 'Add contact' : c.name),
        actions: [
          if (widget.contact != null) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline)),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          OutlinedButton.icon(onPressed: _pickFromPhone, icon: const Icon(Icons.contacts_outlined), label: const Text('Pick from phone contacts')),
          const SizedBox(height: 16),
          FormColumn([
            Choice<String>(label: 'Role', value: c.role, options: ContactRole.all, labelOf: ContactRole.label, onChanged: (x) => setState(() => c.role = x)),
            Field(_name, 'Name', required: true, caps: TextCapitalization.words),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Phone (with country code)', hintText: '+971 50 123 4567', border: OutlineInputBorder()),
            ),
            Field(_company, 'Company / dealer / garage', caps: TextCapitalization.words),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Preferred'),
              subtitle: const Text('Shown first and used to pre-fill new services'),
              value: c.preferred,
              onChanged: (x) => setState(() => c.preferred = x),
            ),
            Field(_notes, 'Notes', maxLines: 2),
          ]),
          if (hasPhone)
            Row(children: [
              Expanded(child: FilledButton.tonalIcon(onPressed: () => Dialer.call(_phone.text), icon: const Icon(Icons.call), label: const Text('Call'))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton.tonalIcon(onPressed: () => Dialer.whatsapp(_phone.text), icon: const Icon(Icons.chat_outlined), label: const Text('WhatsApp'))),
            ]),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: _saveToPhone, icon: const Icon(Icons.person_add_alt), label: const Text('Also save to phone contacts')),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Padding(padding: EdgeInsets.all(12), child: Text('Save contact'))),
        ]),
      ),
    );
  }
}
