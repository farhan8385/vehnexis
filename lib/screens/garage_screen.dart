import 'package:flutter/material.dart';

import '../db.dart';
import '../models.dart';
import '../widgets.dart';
import 'vehicle_detail.dart';
import 'vehicle_form.dart';

class GarageScreen extends StatefulWidget {
  final VoidCallback onChanged;
  const GarageScreen({super.key, required this.onChanged});
  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
  late Future<(List<Vehicle>, List<Reminder>)> _data = _load();

  Future<(List<Vehicle>, List<Reminder>)> _load() async =>
      (await AppDb.instance.vehicles(), await AppDb.instance.reminders());

  void _reload() {
    setState(() => _data = _load());
    widget.onChanged();
  }

  Future<void> _open(Vehicle v) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicleId: v.id!)));
    _reload();
  }

  Future<void> _add() async {
    final saved = await Navigator.push<Vehicle>(context, MaterialPageRoute(builder: (_) => const VehicleFormScreen()));
    if (saved != null) {
      _reload();
      await _open(saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Garage', style: TextStyle(fontWeight: FontWeight.w800)),
          bottom: const TabBar(tabs: [Tab(text: 'Active'), Tab(text: 'Sold / past')]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: const Text('Add vehicle'),
        ),
        body: FutureBuilder(
          future: _data,
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final (vehicles, reminders) = snap.data!;
            Widget list(bool sold) {
              final vs = vehicles.where((v) => v.isSold == sold).toList();
              if (vs.isEmpty) {
                return sold
                    ? const EmptyState(emoji: '🗂️', title: 'No past vehicles', message: 'When you sell a vehicle, mark it as sold and its full history stays here.')
                    : const EmptyState(emoji: '🚗', title: 'Your garage is empty', message: 'Add your first car or bike. Snap the registration card and Garagio fills in the details.');
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                itemCount: vs.length,
                itemBuilder: (_, i) {
                  final v = vs[i];
                  final next = reminders.where((r) => r.vehicleId == v.id).firstOrNull;
                  return _VehicleCard(vehicle: v, next: next, onTap: () => _open(v));
                },
              );
            }

            return TabBarView(children: [list(false), list(true)]);
          },
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final Reminder? next;
  final VoidCallback onTap;
  const _VehicleCard({required this.vehicle, required this.next, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            VehicleAvatar(vehicle, size: 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(vehicle.displayName, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(vehicle.subtitle, style: t.bodySmall),
                if (vehicle.isSold)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Sold ${fmtDate(vehicle.soldDate)}', style: t.labelMedium),
                  )
                else if (next != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(children: [
                      Icon(Icons.schedule, size: 14, color: dueColor(context, next!.daysLeft)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text('${next!.title} · ${dueText(next!.daysLeft)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.labelMedium?.copyWith(color: dueColor(context, next!.daysLeft))),
                      ),
                    ]),
                  ),
              ]),
            ),
            const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }
}
