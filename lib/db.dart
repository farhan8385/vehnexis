import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// Local SQLite store. Everything stays on the phone in this test build.
class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();
  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, 'garagio.db'),
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE vehicles(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT, name TEXT, make TEXT, model TEXT, plate TEXT, vin TEXT,
            color TEXT, country TEXT, location TEXT, lessor TEXT, currency TEXT,
            photo_path TEXT, notes TEXT, avatar TEXT, year INTEGER, ownership TEXT,
            purchase_date TEXT, lease_end TEXT, sold_date TEXT,
            purchase_price REAL, sold_price REAL, purchase_odometer INTEGER,
            status TEXT)''');
        await db.execute('''
          CREATE TABLE documents(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            vehicle_id INTEGER NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
            kind TEXT, title TEXT, number TEXT, provider TEXT, paid_by TEXT,
            image_path TEXT, notes TEXT, issue_date TEXT, expiry_date TEXT,
            cost REAL, remind_days INTEGER)''');
        await db.execute('''
          CREATE TABLE services(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            vehicle_id INTEGER NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
            date TEXT, odometer INTEGER, next_due_km INTEGER, kind TEXT,
            garage TEXT, description TEXT, paid_by TEXT, image_path TEXT,
            notes TEXT, oil_change INTEGER, cost REAL, next_due_date TEXT)''');
        await db.execute('''
          CREATE TABLE parts(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            service_id INTEGER REFERENCES services(id) ON DELETE CASCADE,
            vehicle_id INTEGER NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
            name TEXT, cost REAL, warranty_months INTEGER, warranty_until TEXT,
            warranty_asked INTEGER)''');
        await db.execute('''
          CREATE TABLE expenses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            vehicle_id INTEGER NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
            date TEXT, category TEXT, amount REAL, paid_by TEXT,
            odometer INTEGER, litres REAL, notes TEXT)''');
        await db.execute('''
          CREATE TABLE contacts(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            vehicle_id INTEGER NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
            role TEXT, name TEXT, phone TEXT, company TEXT, notes TEXT,
            preferred INTEGER)''');
      },
    );
  }

  Future<int> _save(String table, Map<String, Object?> map) async {
    final d = await db;
    final id = map['id'];
    if (id == null) {
      final m = Map.of(map)..remove('id');
      return d.insert(table, m);
    }
    await d.update(table, map, where: 'id = ?', whereArgs: [id]);
    return id as int;
  }

  Future<void> _delete(String table, int id) async =>
      (await db).delete(table, where: 'id = ?', whereArgs: [id]);

  // ---------- Vehicles ----------
  Future<List<Vehicle>> vehicles({String? status}) async {
    final rows = await (await db).query('vehicles',
        where: status == null ? null : 'status = ?',
        whereArgs: status == null ? null : [status],
        orderBy: 'id DESC');
    return rows.map(Vehicle.fromMap).toList();
  }

  Future<Vehicle?> vehicle(int id) async {
    final rows = await (await db).query('vehicles', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Vehicle.fromMap(rows.first);
  }

  Future<int> saveVehicle(Vehicle v) async => v.id = await _save('vehicles', v.toMap());
  Future<void> deleteVehicle(int id) => _delete('vehicles', id);

  // ---------- Documents ----------
  Future<List<VehicleDocument>> documents({int? vehicleId}) async {
    final rows = await (await db).query('documents',
        where: vehicleId == null ? null : 'vehicle_id = ?',
        whereArgs: vehicleId == null ? null : [vehicleId],
        orderBy: 'expiry_date IS NULL, expiry_date ASC');
    return rows.map(VehicleDocument.fromMap).toList();
  }

  Future<int> saveDocument(VehicleDocument d) async => d.id = await _save('documents', d.toMap());
  Future<void> deleteDocument(int id) => _delete('documents', id);

  // ---------- Services & parts ----------
  Future<List<ServiceRecord>> services({int? vehicleId}) async {
    final d = await db;
    final rows = await d.query('services',
        where: vehicleId == null ? null : 'vehicle_id = ?',
        whereArgs: vehicleId == null ? null : [vehicleId],
        orderBy: 'date DESC, id DESC');
    final list = rows.map(ServiceRecord.fromMap).toList();
    final partRows = await d.query('parts',
        where: vehicleId == null ? null : 'vehicle_id = ?',
        whereArgs: vehicleId == null ? null : [vehicleId]);
    final parts = partRows.map(Part.fromMap).toList();
    for (final s in list) {
      s.parts = parts.where((p) => p.serviceId == s.id).toList();
    }
    return list;
  }

  Future<int> saveService(ServiceRecord s) async {
    final d = await db;
    s.id = await _save('services', s.toMap());
    await d.delete('parts', where: 'service_id = ?', whereArgs: [s.id]);
    for (final part in s.parts) {
      part.serviceId = s.id;
      part.vehicleId = s.vehicleId;
      part.id = null;
      part.id = await d.insert('parts', part.toMap()..remove('id'));
    }
    return s.id!;
  }

  Future<void> deleteService(int id) => _delete('services', id);

  Future<List<Part>> partsUnderWarranty({int? vehicleId}) async {
    final rows = await (await db).query('parts',
        where: 'warranty_until IS NOT NULL${vehicleId == null ? '' : ' AND vehicle_id = ?'}',
        whereArgs: vehicleId == null ? null : [vehicleId],
        orderBy: 'warranty_until ASC');
    return rows.map(Part.fromMap).toList();
  }

  // ---------- Expenses ----------
  Future<List<Expense>> expenses({int? vehicleId}) async {
    final rows = await (await db).query('expenses',
        where: vehicleId == null ? null : 'vehicle_id = ?',
        whereArgs: vehicleId == null ? null : [vehicleId],
        orderBy: 'date DESC, id DESC');
    return rows.map(Expense.fromMap).toList();
  }

  Future<int> saveExpense(Expense e) async => e.id = await _save('expenses', e.toMap());
  Future<void> deleteExpense(int id) => _delete('expenses', id);

  // ---------- Contacts ----------
  Future<List<VehicleContact>> contacts({int? vehicleId}) async {
    final rows = await (await db).query('contacts',
        where: vehicleId == null ? null : 'vehicle_id = ?',
        whereArgs: vehicleId == null ? null : [vehicleId],
        orderBy: 'preferred DESC, role ASC, name ASC');
    return rows.map(VehicleContact.fromMap).toList();
  }

  Future<int> saveContact(VehicleContact c) async => c.id = await _save('contacts', c.toMap());
  Future<void> deleteContact(int id) => _delete('contacts', id);

  /// Highest odometer reading recorded for a vehicle (services, expenses, purchase).
  Future<int?> latestOdometer(int vehicleId) async {
    final d = await db;
    final r = await d.rawQuery('''
      SELECT MAX(v) AS m FROM (
        SELECT MAX(odometer) AS v FROM services WHERE vehicle_id = ?
        UNION ALL SELECT MAX(odometer) FROM expenses WHERE vehicle_id = ?
        UNION ALL SELECT purchase_odometer FROM vehicles WHERE id = ?)''',
        [vehicleId, vehicleId, vehicleId]);
    return toInt(r.first['m']);
  }

  /// All upcoming / overdue dated items across vehicles.
  Future<List<Reminder>> reminders({bool includeSold = false}) async {
    final vs = await vehicles(status: includeSold ? null : 'active');
    final byId = {for (final v in vs) v.id!: v};
    final out = <Reminder>[];
    for (final d in await documents()) {
      final v = byId[d.vehicleId];
      if (v != null && d.expiryDate != null) {
        out.add(Reminder(v.id!, v.displayName, '${d.displayTitle} expires', d.expiryDate!, 'document'));
      }
    }
    final svcs = await services();
    // Only the latest service per vehicle defines the next due date.
    final seen = <int>{};
    for (final s in svcs) {
      final v = byId[s.vehicleId];
      if (v == null || seen.contains(s.vehicleId)) continue;
      seen.add(s.vehicleId);
      if (s.nextDueDate != null) {
        out.add(Reminder(v.id!, v.displayName,
            'Service due${s.nextDueKm != null ? ' (or at ${s.nextDueKm} km)' : ''}', s.nextDueDate!, 'service'));
      }
    }
    for (final p in await partsUnderWarranty()) {
      final v = byId[p.vehicleId];
      if (v != null && p.warrantyUntil != null) {
        out.add(Reminder(v.id!, v.displayName, 'Warranty ends: ${p.name}', p.warrantyUntil!, 'warranty'));
      }
    }
    for (final v in vs) {
      if (v.leaseEnd != null && !v.isSold) {
        out.add(Reminder(v.id!, v.displayName, 'Lease ends', v.leaseEnd!, 'lease'));
      }
    }
    out.sort((a, b) => a.due.compareTo(b.due));
    return out;
  }
}
