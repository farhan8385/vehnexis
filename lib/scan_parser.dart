/// Turns raw OCR text from a registration card, insurance policy or garage
/// invoice into structured fields. Pure Dart so it can be unit tested.
///
/// Dates are read day-first (dd/mm/yyyy) as used across Asia, the Gulf and
/// Europe; a date whose middle number is above 12 is read month-first (US).
class ParsedScan {
  final String rawText;
  final List<DateTime> dates;
  DateTime? expiry, issue, invoiceDate;
  String? vin, plate, make, model, documentNumber, garage, insurer;
  int? year, odometer;
  double? total;
  bool oilChange = false;
  final List<String> parts;

  ParsedScan(this.rawText, this.dates, this.parts);

  bool get isEmpty =>
      expiry == null &&
      issue == null &&
      invoiceDate == null &&
      vin == null &&
      plate == null &&
      make == null &&
      year == null &&
      odometer == null &&
      total == null &&
      parts.isEmpty;
}

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

const knownMakes = [
  'Toyota', 'Lexus', 'Nissan', 'Infiniti', 'Honda', 'Acura', 'Mitsubishi', 'Mazda',
  'Subaru', 'Suzuki', 'Isuzu', 'Daihatsu', 'Hyundai', 'Kia', 'Genesis', 'Ford',
  'Lincoln', 'Chevrolet', 'GMC', 'Cadillac', 'Buick', 'Dodge', 'Jeep', 'Chrysler',
  'Ram', 'Tesla', 'BMW', 'Mini', 'Mercedes-Benz', 'Mercedes', 'Audi', 'Volkswagen',
  'Porsche', 'Skoda', 'Seat', 'Cupra', 'Volvo', 'Polestar', 'Peugeot', 'Citroen',
  'Renault', 'Dacia', 'Fiat', 'Alfa Romeo', 'Maserati', 'Ferrari', 'Lamborghini',
  'Bentley', 'Rolls-Royce', 'Aston Martin', 'Jaguar', 'Land Rover', 'Range Rover',
  'MG', 'Geely', 'Chery', 'Haval', 'GWM', 'BYD', 'Changan', 'JAC', 'Jetour',
  'Hongqi', 'Tata', 'Mahindra', 'Maruti', 'Proton', 'Perodua', 'Opel', 'Vauxhall',
  'Harley-Davidson', 'Yamaha', 'Kawasaki', 'Ducati', 'KTM', 'Triumph', 'Royal Enfield',
  'Bajaj', 'TVS', 'Hero', 'Vespa', 'Piaggio', 'Aprilia', 'Benelli',
];

const partKeywords = [
  'oil filter', 'air filter', 'cabin filter', 'ac filter', 'fuel filter', 'filter',
  'engine oil', 'motor oil', 'gear oil', 'brake fluid', 'coolant', 'antifreeze',
  'brake pad', 'brake disc', 'brake shoe', 'rotor', 'pads', 'tyre', 'tire',
  'battery', 'spark plug', 'plug', 'belt', 'timing', 'wiper', 'blade', 'bulb',
  'headlamp', 'lamp', 'shock', 'absorber', 'strut', 'suspension', 'bush',
  'clutch', 'gasket', 'seal', 'radiator', 'thermostat', 'water pump', 'pump',
  'alternator', 'starter', 'compressor', 'sensor', 'mount', 'bearing', 'chain',
  'sprocket', 'hose', 'injector', 'ignition coil', 'coil', 'mirror', 'windscreen',
  'windshield', 'glass', 'arm', 'link', 'tie rod', 'boot', 'cv joint', 'axle',
];

final _numDate = RegExp(r'\b(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})\b');
final _isoDate = RegExp(r'\b(\d{4})[\/\-.](\d{1,2})[\/\-.](\d{1,2})\b');
final _textDate = RegExp(
    r'\b(\d{1,2})[\s\-]*(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[\s\-,]*(\d{2,4})\b',
    caseSensitive: false);
final _vin = RegExp(r'\b[A-HJ-NPR-Z0-9]{17}\b');
final _money = RegExp(r'(\d{1,3}(?:[,\s]\d{3})+(?:\.\d{1,2})?|\d+\.\d{1,2}|\d+)');

final _expiryLabel = RegExp(
    r'exp(iry|ires|\.|\b)|valid\s*(till|until|upto|up to|to)|expiration|renewal\s*date|end\s*date|period\s*to|insurance\s*exp',
    caseSensitive: false);
final _issueLabel = RegExp(
    r'issue|first\s*reg|reg(istration)?\.?\s*date|start\s*date|period\s*from|inception',
    caseSensitive: false);
final _invoiceDateLabel = RegExp(r'(invoice|bill|job|tax)?\s*date', caseSensitive: false);
final _odoLabel = RegExp(r'odo(meter)?|mileage|km\s*reading|kms?\s*in|kilomet', caseSensitive: false);
final _odoUnit = RegExp(r'(\d[\d,\.\s]{1,9}\d|\d{2,})\s?(km|kms|kilometers|kilometres)\b', caseSensitive: false);
final _totalLabel = RegExp(
    r'grand\s*total|net\s*(amount|total|payable)|amount\s*(due|payable)|balance\s*due|total\s*(amount|incl|including|aed|inr|usd|eur)?|total',
    caseSensitive: false);
final _plateLabel = RegExp(
    r'(traffic\s*plate|plate\s*(no|number)?|number\s*plate|reg(istration)?\.?\s*(no|number|mark)|licen[cs]e\s*plate|vehicle\s*no)',
    caseSensitive: false);
final _yearLabel = RegExp(r'(model\s*year|year\s*of\s*(manufacture|make)|mfg\.?\s*year|year|model)', caseSensitive: false);
final _docNoLabel = RegExp(
    r'(policy\s*(no|number)|certificate\s*(no|number)|document\s*(no|number)|t\.?c\.?\s*(no|number)|file\s*(no|number)|licen[cs]e\s*(no|number))',
    caseSensitive: false);
final _oil = RegExp(r'engine\s*oil|motor\s*oil|oil\s*change|oil\s*filter|\b\d{1,2}w[\s\-]?\d{2}\b', caseSensitive: false);

DateTime? _mk(int y, int m, int d) {
  if (y < 100) y += 2000;
  if (y < 1950 || y > 2100 || m < 1 || m > 12 || d < 1 || d > 31) return null;
  final dt = DateTime(y, m, d);
  return dt.month == m ? dt : null; // rejects 31/02 etc.
}

/// All dates found in [s], in order of appearance.
List<DateTime> findDates(String s) {
  final found = <(int, DateTime)>[];
  for (final m in _isoDate.allMatches(s)) {
    final d = _mk(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    if (d != null) found.add((m.start, d));
  }
  for (final m in _numDate.allMatches(s)) {
    if (found.any((f) => (f.$1 - m.start).abs() < 3)) continue;
    var a = int.parse(m[1]!), b = int.parse(m[2]!);
    final y = int.parse(m[3]!);
    // day-first unless the middle number cannot be a month
    final d = b > 12 ? _mk(y, a, b) : _mk(y, b, a);
    if (d != null) found.add((m.start, d));
  }
  for (final m in _textDate.allMatches(s)) {
    final d = _mk(int.parse(m[3]!), _months[m[2]!.toLowerCase().substring(0, 3)]!, int.parse(m[1]!));
    if (d != null) found.add((m.start, d));
  }
  found.sort((x, y) => x.$1.compareTo(y.$1));
  return found.map((e) => e.$2).toList();
}

double? _parseMoney(String s) => double.tryParse(s.replaceAll(RegExp(r'[,\s]'), ''));

String? _valueAfterLabel(List<String> lines, int i, RegExp label) {
  final m = label.firstMatch(lines[i]);
  if (m == null) return null;
  var rest = lines[i]
      .substring(m.end)
      .replaceFirst(RegExp(r'^[\s:\.\-#]+'), '')
      .replaceFirst(RegExp(r'^(no|number|nr)\b\.?[\s:\.\-#]*', caseSensitive: false), '')
      .trim();
  if (rest.isEmpty && i + 1 < lines.length) rest = lines[i + 1].trim();
  return rest.isEmpty ? null : rest;
}

ParsedScan parseScan(String text) {
  final lines = text
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  final allDates = findDates(text);
  final r = ParsedScan(text, allDates, []);
  final now = DateTime.now();

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final next = i + 1 < lines.length ? lines[i + 1] : '';

    // Label-driven dates: look on the same line, then the next one.
    List<DateTime> near() {
      final d = findDates(line);
      return d.isNotEmpty ? d : findDates(next);
    }

    if (r.expiry == null && _expiryLabel.hasMatch(line)) {
      final d = near();
      if (d.isNotEmpty) r.expiry = d.last;
    }
    if (r.issue == null && _issueLabel.hasMatch(line)) {
      final d = near();
      if (d.isNotEmpty) r.issue = d.first;
    }
    if (r.invoiceDate == null && _invoiceDateLabel.hasMatch(line) && !_expiryLabel.hasMatch(line)) {
      final d = near();
      if (d.isNotEmpty) r.invoiceDate = d.first;
    }

    if (r.odometer == null && _odoLabel.hasMatch(line)) {
      final v = _valueAfterLabel(lines, i, _odoLabel);
      final m = v == null ? null : RegExp(r'\d[\d,\.\s]*\d|\d').firstMatch(v);
      final n = m == null ? null : int.tryParse(m[0]!.replaceAll(RegExp(r'[,\.\s]'), ''));
      if (n != null && n >= 10 && n < 2000000) r.odometer = n;
    }

    if (_totalLabel.hasMatch(line) && !RegExp(r'sub\s*-?\s*total', caseSensitive: false).hasMatch(line)) {
      var nums = _money.allMatches(line.substring(_totalLabel.firstMatch(line)!.end)).toList();
      if (nums.isEmpty) nums = _money.allMatches(next).toList();
      if (nums.isNotEmpty) {
        final v = _parseMoney(nums.last[0]!);
        final strong = RegExp(r'grand|net|due|payable', caseSensitive: false).hasMatch(line);
        if (v != null && v > 0 && (r.total == null || strong || v > r.total!)) r.total = v;
      }
    }

    if (r.plate == null && _plateLabel.hasMatch(line)) {
      final v = _valueAfterLabel(lines, i, _plateLabel);
      final m = v == null ? null : RegExp(r'[A-Za-z0-9][A-Za-z0-9 \-]{0,11}').firstMatch(v);
      final plate = m?[0]?.trim();
      if (plate != null && plate.length >= 2 && RegExp(r'\d').hasMatch(plate)) r.plate = plate.toUpperCase();
    }

    if (r.year == null && _yearLabel.hasMatch(line)) {
      final m = RegExp(r'\b(19[5-9]\d|20[0-4]\d)\b').firstMatch(_valueAfterLabel(lines, i, _yearLabel) ?? '');
      if (m != null && findDates(line).isEmpty) r.year = int.parse(m[1]!);
    }

    if (r.documentNumber == null && _docNoLabel.hasMatch(line)) {
      final v = _valueAfterLabel(lines, i, _docNoLabel);
      final m = v == null ? null : RegExp(r'[A-Za-z0-9][A-Za-z0-9\/\-]{3,}').firstMatch(v);
      if (m != null) r.documentNumber = m[0];
    }

    // Parts on invoice lines.
    final lower = line.toLowerCase();
    if (!_totalLabel.hasMatch(line) && partKeywords.any((k) => lower.contains(k))) {
      final name = line
          .replaceAll(RegExp(r'(\s+[\d,\.]+)+\s*$'), '') // trailing qty / price columns
          .replaceAll(RegExp(r'^\s*[\d\.\)\-]+\s+'), '') // leading line numbers
          .trim();
      if (name.length >= 3 && name.length <= 60 && !r.parts.any((p) => p.toLowerCase() == name.toLowerCase())) {
        r.parts.add(name);
      }
    }
  }

  if (r.odometer == null) {
    final m = _odoUnit.firstMatch(text);
    final n = m == null ? null : int.tryParse(m[1]!.replaceAll(RegExp(r'[,\.\s]'), ''));
    if (n != null && n >= 10 && n < 2000000) r.odometer = n;
  }

  final upper = text.toUpperCase().replaceAll('O', '0');
  for (final m in _vin.allMatches(upper)) {
    final v = m[0]!;
    if (RegExp(r'\d').hasMatch(v) && RegExp(r'[A-Z]').hasMatch(v)) {
      r.vin = v;
      break;
    }
  }

  for (final make in knownMakes) {
    final m = RegExp('\\b${RegExp.escape(make)}\\b', caseSensitive: false).firstMatch(text);
    if (m != null) {
      r.make = make == 'Mercedes' ? 'Mercedes-Benz' : make;
      final after = text.substring(m.end).split('\n').first.trim();
      final model = RegExp(r'^[\s\-:]*([A-Za-z0-9][A-Za-z0-9\-]{1,15}(?:\s[A-Za-z0-9\-]{1,10})?)').firstMatch(after);
      if (model != null) r.model = model[1]!.trim();
      break;
    }
  }

  // Fallbacks when no label was found.
  if (r.expiry == null) {
    final future = allDates.where((d) => d.isAfter(now)).toList()..sort();
    if (future.isNotEmpty) r.expiry = future.last;
  }
  if (r.invoiceDate == null) {
    final past = allDates.where((d) => !d.isAfter(now)).toList();
    if (past.isNotEmpty) r.invoiceDate = past.first;
  }

  r.oilChange = _oil.hasMatch(text);

  // The first line with letters is usually the garage / company name.
  for (final l in lines.take(4)) {
    if (RegExp(r'[A-Za-z]{3,}').hasMatch(l) && !RegExp(r'invoice|receipt|tax|quotation', caseSensitive: false).hasMatch(l)) {
      r.garage = l.length > 50 ? l.substring(0, 50) : l;
      break;
    }
  }
  if (r.parts.length > 20) r.parts.removeRange(20, r.parts.length);
  return r;
}
