import 'package:flutter_test/flutter_test.dart';
import 'package:garagio/scan_parser.dart';

void main() {
  test('reads a registration card', () {
    const text = '''
VEHICLE LICENSE
Traffic Plate No: K 12345
Make: TOYOTA LAND CRUISER
Model Year: 2021
Chassis No: JTMHV05J804123456
Reg. Date: 14/03/2021
Exp. Date: 13/03/2027
''';
    final r = parseScan(text);
    expect(r.plate, 'K 12345');
    expect(r.make, 'Toyota');
    expect(r.year, 2021);
    expect(r.vin, 'JTMHV05J804123456');
    expect(r.expiry, DateTime(2027, 3, 13));
    expect(r.issue, DateTime(2021, 3, 14));
  });

  test('reads a garage invoice', () {
    const text = '''
AL FUTTAIM AUTO CENTRE
Tax Invoice
Invoice Date: 02-Sep-2026
Odometer: 45,210 km
1 Engine Oil 5W-30 4L 180.00
2 Oil Filter 45.00
3 Brake Pads Front 320.00
Labour 150.00
Sub Total 695.00
VAT 5% 34.75
Grand Total 729.75
''';
    final r = parseScan(text);
    expect(r.invoiceDate, DateTime(2026, 9, 2));
    expect(r.odometer, 45210);
    expect(r.total, 729.75);
    expect(r.oilChange, isTrue);
    expect(r.garage, 'AL FUTTAIM AUTO CENTRE');
    expect(r.parts, containsAll(['Engine Oil 5W-30 4L', 'Oil Filter', 'Brake Pads Front']));
  });

  test('US-style date with day above 12 is read month-first', () {
    expect(findDates('Expires 12/25/2026'), [DateTime(2026, 12, 25)]);
  });
}
