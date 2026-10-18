import 'dart:io';

import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

import 'db.dart';
import 'models.dart';
import 'scan_parser.dart';

/// Photos and scans are copied into the app's private folder so they survive
/// the user clearing their gallery.
class ImageStore {
  static final _picker = ImagePicker();

  static Future<String?> pick({required bool camera}) async {
    final x = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 2400,
      imageQuality: 85,
    );
    if (x == null) return null;
    final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'images'));
    await dir.create(recursive: true);
    final dest = p.join(dir.path, '${DateTime.now().microsecondsSinceEpoch}${p.extension(x.path)}');
    await File(x.path).copy(dest);
    return dest;
  }

  static Future<void> delete(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}

/// On-device text recognition (Google ML Kit). Free, offline, private.
class Scanner {
  static Future<ParsedScan> scanFile(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(path));
      return parseScan(result.text);
    } finally {
      await recognizer.close();
    }
  }
}

/// Local reminders: re-planned from the database after every change.
class Notifier {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    _ready = true;
  }

  static Future<void> requestPermission() async {
    await init();
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Reminders',
      channelDescription: 'Expiry dates, service due and warranty reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static Future<void> rescheduleAll() async {
    try {
      await init();
      await _plugin.cancelAll();
      final docs = {for (final d in await AppDb.instance.documents()) d.id: d};
      final reminders = await AppDb.instance.reminders();
      final now = DateTime.now();
      var id = 1;
      for (final r in reminders) {
        final leadDays = r.kind == 'document' ? null : 14;
        final offsets = <int>{
          0,
          7,
          leadDays ?? 30,
        };
        // Documents carry their own "remind me N days before" setting.
        if (r.kind == 'document') {
          final match = docs.values.where((d) => d.vehicleId == r.vehicleId && d.expiryDate == r.due);
          if (match.isNotEmpty) {
            offsets
              ..remove(30)
              ..add(match.first.remindDays);
          }
        }
        for (final days in offsets) {
          final at = DateTime(r.due.year, r.due.month, r.due.day, 9).subtract(Duration(days: days));
          if (!at.isAfter(now)) continue;
          final when = days == 0 ? 'today' : 'in $days days';
          await _plugin.zonedSchedule(
            id++,
            '${r.vehicleName}: ${r.title} $when',
            'Open Garagio to see details.',
            tz.TZDateTime.from(at.toUtc(), tz.UTC),
            _details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
          if (id > 450) return; // Android caps pending alarms per app
        }
      }
    } catch (_) {
      // Reminders are best effort; never block saving data.
    }
  }
}

class Dialer {
  static String _digits(String phone) => phone.replaceAll(RegExp(r'[^\d+]'), '');

  static Future<void> call(String phone) =>
      launchUrl(Uri(scheme: 'tel', path: _digits(phone)));

  static Future<void> whatsapp(String phone) => launchUrl(
        Uri.parse('https://wa.me/${_digits(phone).replaceAll('+', '')}'),
        mode: LaunchMode.externalApplication,
      );

  /// Opens the phone's own contact picker (asks for read-only contacts access).
  static Future<(String name, String? phone)?> pickFromPhone() async {
    if (!await FlutterContacts.requestPermission(readonly: true)) return null;
    final c = await FlutterContacts.openExternalPick();
    if (c == null) return null;
    final phone = c.phones.isNotEmpty ? c.phones.first.number : null;
    return (c.displayName, phone);
  }

  /// Opens the phone's "new contact" screen pre-filled.
  static Future<void> saveToPhone(VehicleContact vc) async {
    final names = vc.name.trim().split(RegExp(r'\s+'));
    final contact = Contact()
      ..name.first = names.first
      ..name.last = names.length > 1 ? names.sublist(1).join(' ') : ''
      ..phones = [if (vc.phone != null && vc.phone!.isNotEmpty) Phone(vc.phone!)]
      ..organizations = [
        Organization(company: vc.company ?? '', title: ContactRole.label(vc.role)),
      ];
    await FlutterContacts.openExternalInsert(contact);
  }
}
