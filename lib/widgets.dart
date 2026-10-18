import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'services.dart';

final _dateFmt = DateFormat('d MMM yyyy');
final _numFmt = NumberFormat.decimalPattern();
final _moneyFmt = NumberFormat('#,##0.##');

String fmtDate(DateTime? d) => d == null ? '—' : _dateFmt.format(d);
String fmtKm(int? km) => km == null ? '—' : '${_numFmt.format(km)} km';
String fmtMoney(double? v, String? currency) =>
    v == null ? '—' : '${currency ?? ''} ${_moneyFmt.format(v)}'.trim();

String dueText(int days) {
  if (days < 0) return '${-days} days overdue';
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  if (days < 60) return 'In $days days';
  return 'In ${(days / 30).round()} months';
}

Color dueColor(BuildContext context, int days) {
  final cs = Theme.of(context).colorScheme;
  if (days < 0) return cs.error;
  if (days <= 30) return Colors.orange.shade800;
  return cs.primary;
}

/// Vehicle picture: the owner's photo if set, otherwise the chosen emoji.
class VehicleAvatar extends StatelessWidget {
  final Vehicle vehicle;
  final double size;
  const VehicleAvatar(this.vehicle, {super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final photo = vehicle.photoPath;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: Container(
        width: size,
        height: size,
        color: cs.primaryContainer,
        alignment: Alignment.center,
        child: photo != null && File(photo).existsSync()
            ? Image.file(File(photo), width: size, height: size, fit: BoxFit.cover)
            : Text(vehicle.avatar, style: TextStyle(fontSize: size * 0.55)),
      ),
    );
  }
}

class DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool clearable;
  const DateField({super.key, required this.label, required this.value, required this.onChanged, this.clearable = true});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(1950),
          lastDate: DateTime(now.year + 30),
        );
        if (d != null) onChanged(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: value != null && clearable
              ? IconButton(icon: const Icon(Icons.clear), onPressed: () => onChanged(null))
              : const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(value == null ? 'Not set' : fmtDate(value)),
      ),
    );
  }
}

/// Text field bound to a controller, with sensible keyboard types.
class Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool number, decimal, required;
  final int maxLines;
  final TextCapitalization caps;
  const Field(this.controller, this.label,
      {super.key,
      this.hint,
      this.number = false,
      this.decimal = false,
      this.required = false,
      this.maxLines = 1,
      this.caps = TextCapitalization.sentences});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: caps,
      keyboardType: number || decimal
          ? TextInputType.numberWithOptions(decimal: decimal)
          : (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
      decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder()),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
    );
  }
}

class Choice<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  const Choice({super.key, required this.label, required this.value, required this.options, required this.labelOf, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: options.contains(value) ? value : options.first,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: [for (final o in options) DropdownMenuItem(value: o, child: Text(labelOf(o)))],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

/// Vertical list of form rows with consistent spacing.
class FormColumn extends StatelessWidget {
  final List<Widget> children;
  const FormColumn(this.children, {super.key});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final c in children) Padding(padding: const EdgeInsets.only(bottom: 14), child: c)],
      );
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      );
}

class EmptyState extends StatelessWidget {
  final String emoji, title, message;
  const EmptyState({super.key, required this.emoji, required this.title, required this.message});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          ]),
        ),
      );
}

Future<bool> confirm(BuildContext context, String title, String message, {String action = 'Delete'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(action)),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

/// Camera / gallery chooser. Returns the stored image path.
Future<String?> pickImage(BuildContext context) async {
  final camera = await showModalBottomSheet<bool>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take a photo'), onTap: () => Navigator.pop(c, true)),
        ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from gallery'), onTap: () => Navigator.pop(c, false)),
      ]),
    ),
  );
  if (camera == null) return null;
  return ImageStore.pick(camera: camera);
}

/// Thumbnail of an attached scan; tap to view full screen.
class AttachedImage extends StatelessWidget {
  final String? path;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  const AttachedImage({super.key, required this.path, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    if (path == null || !File(path!).existsSync()) {
      return OutlinedButton.icon(onPressed: onAdd, icon: const Icon(Icons.attach_file), label: const Text('Attach photo of the document'));
    }
    return Row(children: [
      GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ImageViewer(path!))),
        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(path!), width: 72, height: 72, fit: BoxFit.cover)),
      ),
      const SizedBox(width: 12),
      const Expanded(child: Text('Document photo attached')),
      IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline)),
    ]);
  }
}

class ImageViewer extends StatelessWidget {
  final String path;
  const ImageViewer(this.path, {super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: InteractiveViewer(maxScale: 6, child: Center(child: Image.file(File(path)))),
      );
}

/// Shown while ML Kit reads a photo.
Future<T> withProgress<T>(BuildContext context, String message, Future<T> Function() work) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(content: Row(children: [const CircularProgressIndicator(), const SizedBox(width: 20), Expanded(child: Text(message))])),
    ),
  );
  try {
    return await work();
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}

double? parseNum(String s) {
  final t = s.replaceAll(',', '').trim();
  return t.isEmpty ? null : double.tryParse(t);
}

int? parseIntField(String s) {
  final t = s.replaceAll(RegExp(r'[,\s]'), '').trim();
  return t.isEmpty ? null : int.tryParse(t);
}

String numText(num? v) {
  if (v == null) return '';
  if (v is double && v == v.roundToDouble()) return v.toInt().toString();
  return v.toString();
}
