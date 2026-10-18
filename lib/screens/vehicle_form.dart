import 'package:flutter/material.dart';

import '../db.dart';
import '../models.dart';
import '../scan_parser.dart';
import '../services.dart';
import '../widgets.dart';

const currencies = [
  'AED', 'SAR', 'QAR', 'OMR', 'KWD', 'BHD', 'INR', 'PKR', 'LKR', 'BDT', 'NPR',
  'PHP', 'IDR', 'MYR', 'SGD', 'THB', 'VND', 'CNY', 'HKD', 'TWD', 'JPY', 'KRW',
  'AUD', 'NZD', 'EUR', 'GBP', 'CHF', 'SEK', 'NOK', 'DKK', 'PLN', 'CZK', 'TRY',
  'USD', 'CAD', 'MXN', 'BRL', 'ZAR', 'EGP', 'NGN', 'KES',
];

class VehicleFormScreen extends StatefulWidget {
  final Vehicle? vehicle;
  const VehicleFormScreen({super.key, this.vehicle});
  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  final _form = GlobalKey<FormState>();
  late final Vehicle v = widget.vehicle ?? Vehicle();
  late final _name = TextEditingController(text: v.name);
  late final _make = TextEditingController(text: v.make);
  late final _model = TextEditingController(text: v.model);
  late final _year = TextEditingController(text: v.year?.toString() ?? '');
  late final _plate = TextEditingController(text: v.plate);
  late final _vin = TextEditingController(text: v.vin);
  late final _color = TextEditingController(text: v.color);
  late final _country = TextEditingController(text: v.country);
  late final _location = TextEditingController(text: v.location);
  late final _lessor = TextEditingController(text: v.lessor);
  late final _price = TextEditingController(text: numText(v.purchasePrice));
  late final _odo = TextEditingController(text: v.purchaseOdometer?.toString() ?? '');
  late final _notes = TextEditingController(text: v.notes);

  // Filled when the user scans a registration card.
  String? _scanImage;
  DateTime? _scannedExpiry;
  bool _addRegistrationDoc = true;

  bool get _isNew => widget.vehicle == null;

  Future<void> _scan() async {
    final path = await pickImage(context);
    if (path == null || !mounted) return;
    final ParsedScan r;
    try {
      r = await withProgress(context, 'Reading the card…', () => Scanner.scanFile(path));
    } catch (e) {
      toast(context, 'Could not read the image: $e');
      return;
    }
    setState(() {
      _scanImage = path;
      if (r.make != null && _make.text.isEmpty) _make.text = r.make!;
      if (r.model != null && _model.text.isEmpty) _model.text = r.model!;
      if (r.year != null && _year.text.isEmpty) _year.text = '${r.year}';
      if (r.plate != null && _plate.text.isEmpty) _plate.text = r.plate!;
      if (r.vin != null && _vin.text.isEmpty) _vin.text = r.vin!;
      _scannedExpiry = r.expiry;
    });
    final found = [
      if (r.make != null) 'make',
      if (r.model != null) 'model',
      if (r.year != null) 'year',
      if (r.plate != null) 'plate',
      if (r.vin != null) 'VIN',
      if (r.expiry != null) 'expiry date',
    ];
    toast(context, found.isEmpty ? 'Nothing recognised. Please type the details.' : 'Filled: ${found.join(', ')}. Please check them.');
  }

  Future<void> _pickPhoto() async {
    final path = await pickImage(context);
    if (path != null) setState(() => v.photoPath = path);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    String? t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    v
      ..name = _name.text.trim()
      ..make = t(_make)
      ..model = t(_model)
      ..year = parseIntField(_year.text)
      ..plate = t(_plate)?.toUpperCase()
      ..vin = t(_vin)?.toUpperCase()
      ..color = t(_color)
      ..country = t(_country)
      ..location = t(_location)
      ..lessor = v.ownership == Ownership.leased ? t(_lessor) : null
      ..purchasePrice = parseNum(_price.text)
      ..purchaseOdometer = parseIntField(_odo.text)
      ..notes = t(_notes);
    await AppDb.instance.saveVehicle(v);
    if (_scanImage != null && _addRegistrationDoc) {
      await AppDb.instance.saveDocument(VehicleDocument(
        vehicleId: v.id!,
        kind: DocKind.registration,
        number: v.plate,
        expiryDate: _scannedExpiry,
        imagePath: _scanImage,
      ));
    }
    if (mounted) Navigator.pop(context, v);
  }

  Future<void> _chooseAvatar() async {
    final e = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final a in vehicleAvatars)
              InkWell(
                onTap: () => Navigator.pop(c, a),
                child: Padding(padding: const EdgeInsets.all(6), child: Text(a, style: const TextStyle(fontSize: 34))),
              ),
          ]),
        ),
      ),
    );
    if (e != null) setState(() => v.avatar = e);
  }

  @override
  Widget build(BuildContext context) {
    final leased = v.ownership == Ownership.leased;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Add vehicle' : 'Edit vehicle'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (_isNew)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.document_scanner_outlined, size: 32),
                title: const Text('Scan registration card'),
                subtitle: Text(_scanImage == null
                    ? 'Take a photo and the details fill in automatically'
                    : 'Scanned. Expiry: ${fmtDate(_scannedExpiry)}'),
                onTap: _scan,
              ),
            ),
          if (_scanImage != null)
            CheckboxListTile(
              value: _addRegistrationDoc,
              onChanged: (x) => setState(() => _addRegistrationDoc = x ?? true),
              title: const Text('Save the card as a document with expiry reminder'),
              contentPadding: EdgeInsets.zero,
            ),
          const SizedBox(height: 12),
          Row(children: [
            GestureDetector(onTap: _chooseAvatar, child: VehicleAvatar(v, size: 72)),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(spacing: 8, children: [
                OutlinedButton.icon(onPressed: _chooseAvatar, icon: const Icon(Icons.emoji_emotions_outlined), label: const Text('Icon')),
                OutlinedButton.icon(onPressed: _pickPhoto, icon: const Icon(Icons.photo_camera_outlined), label: const Text('Photo')),
                if (v.photoPath != null)
                  TextButton(onPressed: () => setState(() => v.photoPath = null), child: const Text('Remove photo')),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          FormColumn([
            Choice<String>(
              label: 'Type',
              value: v.type,
              options: VehicleType.all,
              labelOf: VehicleType.label,
              onChanged: (x) => setState(() {
                if (v.avatar == VehicleType.defaultAvatar(v.type)) v.avatar = VehicleType.defaultAvatar(x);
                v.type = x;
              }),
            ),
            Field(_name, 'Nickname (optional)', hint: 'e.g. Family SUV, Work bike'),
            Row(children: [
              Expanded(child: Field(_make, 'Make', caps: TextCapitalization.words)),
              const SizedBox(width: 10),
              Expanded(child: Field(_model, 'Model', caps: TextCapitalization.words)),
            ]),
            Row(children: [
              Expanded(child: Field(_year, 'Year', number: true)),
              const SizedBox(width: 10),
              Expanded(child: Field(_color, 'Colour', caps: TextCapitalization.words)),
            ]),
            Field(_plate, 'Plate number', caps: TextCapitalization.characters),
            Field(_vin, 'VIN / chassis number', caps: TextCapitalization.characters),
            Row(children: [
              Expanded(child: Field(_country, 'Registered in (country)', caps: TextCapitalization.words)),
              const SizedBox(width: 10),
              Expanded(
                child: Choice<String>(
                  label: 'Currency',
                  value: v.currency ?? 'AED',
                  options: currencies,
                  labelOf: (c) => c,
                  onChanged: (c) => setState(() => v.currency = c),
                ),
              ),
            ]),
            Field(_location, 'Where is it now?', hint: 'e.g. Dubai, home parking'),
          ]),
          const SectionTitle('Ownership'),
          FormColumn([
            Choice<String>(
              label: 'Ownership',
              value: v.ownership,
              options: Ownership.all,
              labelOf: Ownership.label,
              onChanged: (x) => setState(() => v.ownership = x),
            ),
            if (leased) Field(_lessor, 'Lease company', caps: TextCapitalization.words),
            if (leased) DateField(label: 'Lease ends', value: v.leaseEnd, onChanged: (d) => setState(() => v.leaseEnd = d)),
            DateField(
              label: leased ? 'Lease start' : 'Purchase date',
              value: v.purchaseDate,
              onChanged: (d) => setState(() => v.purchaseDate = d),
            ),
            Row(children: [
              if (!leased) Expanded(child: Field(_price, 'Purchase price', decimal: true)),
              if (!leased) const SizedBox(width: 10),
              Expanded(child: Field(_odo, 'Odometer at start (km)', number: true)),
            ]),
            Field(_notes, 'Notes', maxLines: 3),
          ]),
          const SizedBox(height: 40),
          FilledButton(onPressed: _save, child: const Padding(padding: EdgeInsets.all(12), child: Text('Save vehicle'))),
        ]),
      ),
    );
  }
}
