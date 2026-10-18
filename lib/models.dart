// Data models for Vehnexis. Dates are stored as ISO-8601 strings (yyyy-MM-dd).

DateTime? parseDate(Object? v) =>
    (v == null || v == '') ? null : DateTime.tryParse(v.toString());

String? fmtIso(DateTime? d) => d == null
    ? null
    : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

double? toDouble(Object? v) =>
    v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));

int? toInt(Object? v) =>
    v == null ? null : (v is num ? v.toInt() : int.tryParse(v.toString()));

/// Who paid for an item. Only [me] counts towards "my cost".
class PaidBy {
  static const me = 'me';
  static const lessor = 'lessor';
  static const company = 'company';
  static const insurer = 'insurer';
  static const all = [me, lessor, company, insurer];
  static String label(String v) => const {
        me: 'Me',
        lessor: 'Lease company',
        company: 'Employer / company',
        insurer: 'Insurance',
      }[v] ??
      v;
}

class VehicleType {
  static const car = 'car';
  static const bike = 'bike';
  static const suv = 'suv';
  static const truck = 'truck';
  static const van = 'van';
  static const scooter = 'scooter';
  static const boat = 'boat';
  static const other = 'other';
  static const all = [car, suv, bike, scooter, van, truck, boat, other];
  static String label(String v) => const {
        car: 'Car',
        suv: 'SUV / 4x4',
        bike: 'Motorbike',
        scooter: 'Scooter',
        van: 'Van',
        truck: 'Truck',
        boat: 'Boat / Jet ski',
        other: 'Other',
      }[v] ??
      v;
  static String defaultAvatar(String v) => const {
        car: '🚗',
        suv: '🚙',
        bike: '🏍️',
        scooter: '🛵',
        van: '🚐',
        truck: '🚚',
        boat: '🚤',
        other: '🚘',
      }[v] ??
      '🚗';
}

const vehicleAvatars = [
  '🚗', '🚙', '🏎️', '🚕', '🚓', '🚐', '🚚', '🛻', '🏍️', '🛵', '🚲', '🚤', '🚜', '🚌', '😎', '🤩'
];

class Ownership {
  static const owned = 'owned';
  static const leased = 'leased';
  static const company = 'company';
  static const financed = 'financed';
  static const all = [owned, financed, leased, company];
  static String label(String v) => const {
        owned: 'Owned',
        financed: 'Owned (on loan)',
        leased: 'Leased',
        company: 'Company vehicle',
      }[v] ??
      v;

  /// Who normally pays for servicing under this ownership type.
  static String defaultServicePayer(String v) =>
      v == leased ? PaidBy.lessor : (v == company ? PaidBy.company : PaidBy.me);
}

class Vehicle {
  int? id;
  String type;
  String name;
  String? make, model, plate, vin, color, country, location, lessor, currency, photoPath, notes;
  String avatar;
  int? year;
  String ownership;
  DateTime? purchaseDate, leaseEnd, soldDate;
  double? purchasePrice, soldPrice;
  int? purchaseOdometer;
  String status; // active | sold

  Vehicle({
    this.id,
    this.type = VehicleType.car,
    this.name = '',
    this.make,
    this.model,
    this.plate,
    this.vin,
    this.color,
    this.country,
    this.location,
    this.lessor,
    this.currency = 'AED',
    this.photoPath,
    this.notes,
    String? avatar,
    this.year,
    this.ownership = Ownership.owned,
    this.purchaseDate,
    this.leaseEnd,
    this.soldDate,
    this.purchasePrice,
    this.soldPrice,
    this.purchaseOdometer,
    this.status = 'active',
  }) : avatar = avatar ?? VehicleType.defaultAvatar(type);

  bool get isSold => status == 'sold';

  String get displayName {
    if (name.trim().isNotEmpty) return name.trim();
    final parts = [make, model].where((e) => e != null && e.trim().isNotEmpty);
    return parts.isEmpty ? VehicleType.label(type) : parts.join(' ');
  }

  String get subtitle => [
        if (year != null) '$year',
        if (plate != null && plate!.isNotEmpty) plate!,
        Ownership.label(ownership),
      ].join(' · ');

  Map<String, Object?> toMap() => {
        'id': id,
        'type': type,
        'name': name,
        'make': make,
        'model': model,
        'plate': plate,
        'vin': vin,
        'color': color,
        'country': country,
        'location': location,
        'lessor': lessor,
        'currency': currency,
        'photo_path': photoPath,
        'notes': notes,
        'avatar': avatar,
        'year': year,
        'ownership': ownership,
        'purchase_date': fmtIso(purchaseDate),
        'lease_end': fmtIso(leaseEnd),
        'sold_date': fmtIso(soldDate),
        'purchase_price': purchasePrice,
        'sold_price': soldPrice,
        'purchase_odometer': purchaseOdometer,
        'status': status,
      };

  static Vehicle fromMap(Map<String, Object?> m) => Vehicle(
        id: toInt(m['id']),
        type: (m['type'] as String?) ?? VehicleType.car,
        name: (m['name'] as String?) ?? '',
        make: m['make'] as String?,
        model: m['model'] as String?,
        plate: m['plate'] as String?,
        vin: m['vin'] as String?,
        color: m['color'] as String?,
        country: m['country'] as String?,
        location: m['location'] as String?,
        lessor: m['lessor'] as String?,
        currency: (m['currency'] as String?) ?? 'AED',
        photoPath: m['photo_path'] as String?,
        notes: m['notes'] as String?,
        avatar: m['avatar'] as String?,
        year: toInt(m['year']),
        ownership: (m['ownership'] as String?) ?? Ownership.owned,
        purchaseDate: parseDate(m['purchase_date']),
        leaseEnd: parseDate(m['lease_end']),
        soldDate: parseDate(m['sold_date']),
        purchasePrice: toDouble(m['purchase_price']),
        soldPrice: toDouble(m['sold_price']),
        purchaseOdometer: toInt(m['purchase_odometer']),
        status: (m['status'] as String?) ?? 'active',
      );
}

class DocKind {
  static const registration = 'registration';
  static const insurance = 'insurance';
  static const inspection = 'inspection';
  static const warranty = 'warranty';
  static const license = 'license';
  static const permit = 'permit';
  static const serviceContract = 'service_contract';
  static const other = 'other';
  static const all = [registration, insurance, inspection, warranty, serviceContract, permit, license, other];
  static String label(String v) => const {
        registration: 'Registration',
        insurance: 'Insurance',
        inspection: 'Inspection / emission test',
        warranty: 'Vehicle warranty',
        serviceContract: 'Service contract',
        permit: 'Permit / toll tag',
        license: 'Driving licence',
        other: 'Other',
      }[v] ??
      v;
}

class VehicleDocument {
  int? id;
  int vehicleId;
  String kind;
  String? title, number, provider, paidBy, imagePath, notes;
  DateTime? issueDate, expiryDate;
  double? cost;
  int remindDays;

  VehicleDocument({
    this.id,
    required this.vehicleId,
    this.kind = DocKind.registration,
    this.title,
    this.number,
    this.provider,
    this.paidBy = PaidBy.me,
    this.imagePath,
    this.notes,
    this.issueDate,
    this.expiryDate,
    this.cost,
    this.remindDays = 30,
  });

  String get displayTitle =>
      (title != null && title!.trim().isNotEmpty) ? title! : DocKind.label(kind);

  Map<String, Object?> toMap() => {
        'id': id,
        'vehicle_id': vehicleId,
        'kind': kind,
        'title': title,
        'number': number,
        'provider': provider,
        'paid_by': paidBy,
        'image_path': imagePath,
        'notes': notes,
        'issue_date': fmtIso(issueDate),
        'expiry_date': fmtIso(expiryDate),
        'cost': cost,
        'remind_days': remindDays,
      };

  static VehicleDocument fromMap(Map<String, Object?> m) => VehicleDocument(
        id: toInt(m['id']),
        vehicleId: toInt(m['vehicle_id'])!,
        kind: (m['kind'] as String?) ?? DocKind.other,
        title: m['title'] as String?,
        number: m['number'] as String?,
        provider: m['provider'] as String?,
        paidBy: (m['paid_by'] as String?) ?? PaidBy.me,
        imagePath: m['image_path'] as String?,
        notes: m['notes'] as String?,
        issueDate: parseDate(m['issue_date']),
        expiryDate: parseDate(m['expiry_date']),
        cost: toDouble(m['cost']),
        remindDays: toInt(m['remind_days']) ?? 30,
      );
}

class ServiceKind {
  static const service = 'service';
  static const repair = 'repair';
  static const tyres = 'tyres';
  static const battery = 'battery';
  static const bodywork = 'bodywork';
  static const inspection = 'inspection';
  static const other = 'other';
  static const all = [service, repair, tyres, battery, bodywork, inspection, other];
  static String label(String v) => const {
        service: 'Scheduled service',
        repair: 'Repair',
        tyres: 'Tyres',
        battery: 'Battery',
        bodywork: 'Bodywork / accident',
        inspection: 'Inspection',
        other: 'Other',
      }[v] ??
      v;
}

class ServiceRecord {
  int? id;
  int vehicleId;
  DateTime date;
  int? odometer, nextDueKm;
  String kind;
  String? garage, description, paidBy, imagePath, notes;
  bool oilChange;
  double? cost;
  DateTime? nextDueDate;
  List<Part> parts;

  ServiceRecord({
    this.id,
    required this.vehicleId,
    required this.date,
    this.odometer,
    this.nextDueKm,
    this.kind = ServiceKind.service,
    this.garage,
    this.description,
    this.paidBy = PaidBy.me,
    this.imagePath,
    this.notes,
    this.oilChange = false,
    this.cost,
    this.nextDueDate,
    List<Part>? parts,
  }) : parts = parts ?? [];

  Map<String, Object?> toMap() => {
        'id': id,
        'vehicle_id': vehicleId,
        'date': fmtIso(date),
        'odometer': odometer,
        'next_due_km': nextDueKm,
        'kind': kind,
        'garage': garage,
        'description': description,
        'paid_by': paidBy,
        'image_path': imagePath,
        'notes': notes,
        'oil_change': oilChange ? 1 : 0,
        'cost': cost,
        'next_due_date': fmtIso(nextDueDate),
      };

  static ServiceRecord fromMap(Map<String, Object?> m) => ServiceRecord(
        id: toInt(m['id']),
        vehicleId: toInt(m['vehicle_id'])!,
        date: parseDate(m['date']) ?? DateTime.now(),
        odometer: toInt(m['odometer']),
        nextDueKm: toInt(m['next_due_km']),
        kind: (m['kind'] as String?) ?? ServiceKind.service,
        garage: m['garage'] as String?,
        description: m['description'] as String?,
        paidBy: (m['paid_by'] as String?) ?? PaidBy.me,
        imagePath: m['image_path'] as String?,
        notes: m['notes'] as String?,
        oilChange: toInt(m['oil_change']) == 1,
        cost: toDouble(m['cost']),
        nextDueDate: parseDate(m['next_due_date']),
      );
}

class Part {
  int? id;
  int? serviceId;
  int vehicleId;
  String name;
  double? cost;
  int? warrantyMonths;
  DateTime? warrantyUntil;
  bool warrantyAsked;

  Part({
    this.id,
    this.serviceId,
    required this.vehicleId,
    required this.name,
    this.cost,
    this.warrantyMonths,
    this.warrantyUntil,
    this.warrantyAsked = false,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'service_id': serviceId,
        'vehicle_id': vehicleId,
        'name': name,
        'cost': cost,
        'warranty_months': warrantyMonths,
        'warranty_until': fmtIso(warrantyUntil),
        'warranty_asked': warrantyAsked ? 1 : 0,
      };

  static Part fromMap(Map<String, Object?> m) => Part(
        id: toInt(m['id']),
        serviceId: toInt(m['service_id']),
        vehicleId: toInt(m['vehicle_id'])!,
        name: (m['name'] as String?) ?? '',
        cost: toDouble(m['cost']),
        warrantyMonths: toInt(m['warranty_months']),
        warrantyUntil: parseDate(m['warranty_until']),
        warrantyAsked: toInt(m['warranty_asked']) == 1,
      );
}

class ExpenseCategory {
  static const fuel = 'fuel';
  static const insurance = 'insurance';
  static const registration = 'registration';
  static const tolls = 'tolls';
  static const parking = 'parking';
  static const fines = 'fines';
  static const cleaning = 'cleaning';
  static const loan = 'loan';
  static const lease = 'lease';
  static const accessories = 'accessories';
  static const other = 'other';
  static const all = [fuel, tolls, parking, cleaning, fines, insurance, registration, loan, lease, accessories, other];
  static String label(String v) => const {
        fuel: 'Fuel / charging',
        insurance: 'Insurance',
        registration: 'Registration / renewal',
        tolls: 'Tolls (e.g. Salik)',
        parking: 'Parking',
        fines: 'Fines',
        cleaning: 'Washing / cleaning',
        loan: 'Loan instalment',
        lease: 'Lease payment',
        accessories: 'Accessories',
        other: 'Other',
      }[v] ??
      v;
}

class Expense {
  int? id;
  int vehicleId;
  DateTime date;
  String category;
  double amount;
  String paidBy;
  int? odometer;
  double? litres;
  String? notes;

  Expense({
    this.id,
    required this.vehicleId,
    required this.date,
    this.category = ExpenseCategory.fuel,
    this.amount = 0,
    this.paidBy = PaidBy.me,
    this.odometer,
    this.litres,
    this.notes,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'vehicle_id': vehicleId,
        'date': fmtIso(date),
        'category': category,
        'amount': amount,
        'paid_by': paidBy,
        'odometer': odometer,
        'litres': litres,
        'notes': notes,
      };

  static Expense fromMap(Map<String, Object?> m) => Expense(
        id: toInt(m['id']),
        vehicleId: toInt(m['vehicle_id'])!,
        date: parseDate(m['date']) ?? DateTime.now(),
        category: (m['category'] as String?) ?? ExpenseCategory.other,
        amount: toDouble(m['amount']) ?? 0,
        paidBy: (m['paid_by'] as String?) ?? PaidBy.me,
        odometer: toInt(m['odometer']),
        litres: toDouble(m['litres']),
        notes: m['notes'] as String?,
      );
}

class ContactRole {
  static const salesAdvisor = 'sales_advisor';
  static const serviceAdvisor = 'service_advisor';
  static const pickDrop = 'pick_drop';
  static const garage = 'garage';
  static const driver = 'driver';
  static const insurance = 'insurance';
  static const roadside = 'roadside';
  static const leaseCompany = 'lease_company';
  static const other = 'other';
  static const all = [serviceAdvisor, garage, pickDrop, salesAdvisor, driver, insurance, roadside, leaseCompany, other];
  static String label(String v) => const {
        salesAdvisor: 'Sales advisor',
        serviceAdvisor: 'Service advisor',
        pickDrop: 'Pick & drop driver',
        garage: 'Garage',
        driver: 'Driver',
        insurance: 'Insurance agent',
        roadside: 'Roadside assistance',
        leaseCompany: 'Lease company',
        other: 'Other',
      }[v] ??
      v;
}

class VehicleContact {
  int? id;
  int vehicleId;
  String role;
  String name;
  String? phone, company, notes;
  bool preferred;

  VehicleContact({
    this.id,
    required this.vehicleId,
    this.role = ContactRole.serviceAdvisor,
    this.name = '',
    this.phone,
    this.company,
    this.notes,
    this.preferred = false,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'vehicle_id': vehicleId,
        'role': role,
        'name': name,
        'phone': phone,
        'company': company,
        'notes': notes,
        'preferred': preferred ? 1 : 0,
      };

  static VehicleContact fromMap(Map<String, Object?> m) => VehicleContact(
        id: toInt(m['id']),
        vehicleId: toInt(m['vehicle_id'])!,
        role: (m['role'] as String?) ?? ContactRole.other,
        name: (m['name'] as String?) ?? '',
        phone: m['phone'] as String?,
        company: m['company'] as String?,
        notes: m['notes'] as String?,
        preferred: toInt(m['preferred']) == 1,
      );
}

/// A dated item that needs the owner's attention (expiry, service due, warranty end).
class Reminder {
  final int vehicleId;
  final String vehicleName;
  final String title;
  final DateTime due;
  final String kind; // document | service | warranty | lease
  Reminder(this.vehicleId, this.vehicleName, this.title, this.due, this.kind);

  int get daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(due.year, due.month, due.day).difference(today).inDays;
  }
}
