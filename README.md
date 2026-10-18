# Garagio (working name) — Android test build

Keep every car and bike's papers, services, warranties and costs in one place.
Snap the registration card or garage invoice and the details fill in automatically.

## Get the test APK

Every push to `main` builds a signed APK on GitHub:

1. Open the repository on GitHub → **Releases** → newest **Test build N** → download the `.apk`
   (or **Actions** → latest run → **Artifacts** → `garagio-apk`).
2. Open the file on an Android phone (Android 6.0 or newer) and allow "Install unknown apps" when asked.
3. Later builds install over the old one and keep your data, because every build uses the same test key.

## What's in this test version

| Area | Included |
|---|---|
| Garage | Cars, SUVs, bikes, scooters, vans, trucks, boats; emoji icon or own photo; active and sold tabs; mark as sold keeps history; delete permanently |
| Scanning | On-device text recognition (Google ML Kit, free, offline): registration card → make, model, year, plate, VIN, expiry; invoice → date, km, total, oil change, parts; document → expiry and number |
| Services | Date, km, garage, work done, oil change, cost, who paid, parts list, next service by date / km, photo of invoice |
| Warranty | After saving parts, asks if each part is under warranty (3 months to 3 years) and reminds before it ends |
| Documents | Registration, insurance, inspection, warranty, service contract, permits, licence; expiry with "remind me N days before" |
| Costs | Fuel, tolls, parking, fines, insurance, registration, loan / lease and more; cost-of-ownership dashboard by category and vehicle; "only what I paid" switch for leased / company vehicles |
| Contacts | Service advisor, garage, pick & drop driver, sales advisor, etc.; pick from phone contacts, save to phone contacts, one-tap call and WhatsApp |
| Ownership | Owned, on loan, leased (lease company, lease end reminder), company vehicle; service costs default to the lessor for leased vehicles |
| Reminders | Phone notifications 30 / 7 / 0 days before (documents use their own setting) plus a Reminders tab |

Not in this build yet: ads, payments, cloud backup / sign-in, iPhone and Huawei builds, other languages.

## Project layout

```
lib/
  main.dart              app shell (Garage / Reminders / Costs)
  models.dart            data classes and option lists
  db.dart                SQLite storage on the phone
  scan_parser.dart       turns OCR text into fields (unit tested)
  services.dart          camera, ML Kit, notifications, phone contacts
  widgets.dart           shared form widgets and formatting
  screens/               one file per screen
test/scan_parser_test.dart
tool/patch_android.py    adds permissions, signing and settings after `flutter create`
android/app/             test signing key + ProGuard rules (rest is generated in CI)
.github/workflows/build-apk.yml
```

## Build on your own PC instead

```
flutter create --platforms=android --org com.garagio --project-name garagio .
python3 tool/patch_android.py
flutter run
```

## Before publishing to Google Play

- `android/app/garagio-test.jks` is a **test key only**. Create a private upload key, keep it out of the repository, and enrol in Play App Signing.
- Choose the final app name and package ID (currently `com.garagio.garagio`); the package ID cannot change after the first Play Store upload.
- Add a privacy policy: the app stores photos of registration cards, which contain personal data.
