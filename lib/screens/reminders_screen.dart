import 'package:flutter/material.dart';

import '../db.dart';
import '../models.dart';
import '../widgets.dart';
import 'vehicle_detail.dart';

class RemindersScreen extends StatefulWidget {
  final VoidCallback onChanged;
  const RemindersScreen({super.key, required this.onChanged});
  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  late Future<List<Reminder>> _data = AppDb.instance.reminders();

  IconData _icon(String kind) => switch (kind) {
        'document' => Icons.description_outlined,
        'service' => Icons.build_outlined,
        'warranty' => Icons.verified_outlined,
        _ => Icons.event_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders', style: TextStyle(fontWeight: FontWeight.w800))),
      body: FutureBuilder(
        future: _data,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final all = snap.data!;
          if (all.isEmpty) {
            return const EmptyState(
                emoji: '🔔',
                title: 'Nothing to remind you about',
                message: 'Add documents with expiry dates, a next-service date, or parts with warranty, and they appear here.');
          }
          final overdue = all.where((r) => r.daysLeft < 0).toList();
          final soon = all.where((r) => r.daysLeft >= 0 && r.daysLeft <= 60).toList();
          final later = all.where((r) => r.daysLeft > 60).toList();
          Widget group(String title, List<Reminder> items) => items.isEmpty
              ? const SizedBox.shrink()
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SectionTitle(title),
                  Card(
                    child: Column(children: [
                      for (final r in items)
                        ListTile(
                          leading: Icon(_icon(r.kind), color: dueColor(context, r.daysLeft)),
                          title: Text(r.title),
                          subtitle: Text('${r.vehicleName} · ${fmtDate(r.due)}'),
                          trailing: Text(dueText(r.daysLeft),
                              style: TextStyle(color: dueColor(context, r.daysLeft), fontWeight: FontWeight.w600)),
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicleId: r.vehicleId)));
                            setState(() => _data = AppDb.instance.reminders());
                            widget.onChanged();
                          },
                        ),
                    ]),
                  ),
                ]);
          return ListView(padding: const EdgeInsets.all(12), children: [
            group('Overdue', overdue),
            group('Next 60 days', soon),
            group('Later', later),
          ]);
        },
      ),
    );
  }
}
