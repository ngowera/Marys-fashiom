# Mary Inventory + Mary’s Fashion

`apps/mary_inventory` is one Flutter app for both Android and Linux. Both builds use the same inventory, order, operations and reporting code and read from the same backend.

## Open on Linux

Run `./open-mary-inventory.sh` from this folder, or open `Mary Inventory.desktop` (your file manager may ask you to allow launching). This starts the existing local API if needed and opens the native Linux inventory app. The staff password remains in `server/.staff-password`; existing stock and orders are preserved.

While the app is open, visit **http://127.0.0.1:8083/** for the separate customer website. Closing the app stops the backend only if this launcher started it. To keep the website running independently, run `python3 server/start.py` first.

## Publish clothes

1. Sign in to Mary Inventory. It retrieves the latest inventory from the backend.
2. Choose **Add product**, add photos, the selling price, cost, sizes/colours and quantities.
3. Leave **Visible in the shop** enabled, then choose **Save & publish to website**.
4. The website refreshes its catalogue within 15 seconds while open. It also refreshes on returning to the app. No website rebuild or deployment is needed for product changes.

Turn visibility off to save a hidden product. Stock receipts and customer orders use the same database. Saving requires a successful server response; offline publishing is not supported.

## Independent builds

From `apps/mary_inventory`:

```sh
flutter pub get
flutter build linux --release
flutter build apk --debug
```

Linux output: `build/linux/x64/release/bundle/` (keep the entire folder together).
Android output: `build/app/outputs/flutter-apk/app-debug.apk` (development build).

From `apps/marys_fashion_website`:

```sh
flutter pub get
flutter build web --release --no-web-resources-cdn
```

Website output: `build/web/`. The local server automatically serves this build. The website and inventory have separate build outputs and application entry points. They share code, not a single installation.

The Linux app defaults to `http://127.0.0.1:8083`; Android defaults to emulator host `http://10.0.2.2:8083`. The local server is deliberately bound to this computer. A real Android phone needs a reachable backend: rebuild with `--dart-define=API_URL=https://YOUR-BACKEND`. Use the same backend for both apps. The APK is not yet connected to a phone-accessible cloud server. Configure release signing before distributing a production APK.

### Inventory email sign-in

The inventory sign-in uses Supabase Auth email/password sessions. For local runs, the inventory app reads the public Supabase settings from the repository `.env` through the local API; no Flutter build flags are needed:

```sh
./open-mary-inventory.sh
```

Set `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` in the server-only `.env`. Each inventory email must also have a row in `public.staff_profiles`; a normal Supabase account is not automatically allowed into inventory. The server uses the session token to verify the user and staff profile before serving `/api/admin` or accepting staff changes. The service-role key is never sent to the app.

## Connect both to one Supabase project later

This separation does **not** migrate your data or connect staff inventory to Supabase. The current working publish flow uses the shared local Python/SQLite backend. No cloud database or policies were changed.

The existing direct Supabase adapter only implements customer catalogue, checkout and tracking; it does not implement staff authentication, product writes, uploads or operations. Staff requests now fail explicitly when that partial mode is enabled instead of silently writing to another backend. Do not enable the website’s partial Supabase mode while inventory still uses SQLite: those are different databases.

For the cloud handoff, connect the shared API layer to one Supabase project for **both** apps: implement staff Auth and authorization, product/stock transactions, Storage uploads, order operations and the matching API responses; review the draft migrations and RLS (including public unit-cost access); migrate existing products, photos and stock; then switch both builds together. Only a publishable key belongs in client configuration. Service-role and database credentials stay on the server. Verify one inventory publish appears on the website and that a website sale reduces inventory in the same project before launch.

## Verification

`flutter analyze` checks the monorepo. `flutter test` runs the UI and refresh tests; this installed Flutter SDK has a test-runner issue with apostrophes in directory names, so use a temporary copy of `lib`, `test`, `assets`, `packages`, `pubspec.yaml` and `pubspec.lock` under a path such as `/tmp/mary-inventory-check` for tests. Run `flutter pub get` there first. Backend contracts: `python3 -m unittest discover -s server -v`.
