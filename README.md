# Mary Inventory and Mary’s Fashion website

The independent app projects are now:

- `apps/mary_inventory`: **Mary Inventory**, Android and Linux desktop.
- `apps/marys_fashion_website`: **Mary’s Fashion**, customer website only.
- `packages/mary_shared`: shared screens, API contract and assets, so the apps stay compatible.
- `server`: current local backend, stock ledger, photos and database.
- `supabase`: existing draft schema for the future shared cloud connection.

See [SEPARATE_APPS.md](SEPARATE_APPS.md) for launching, building, publishing products and the Supabase handoff. The root Flutter entry points remain compatibility launchers for older commands; use `apps/` for new builds.

## GitHub Pages deployment

The repository includes a GitHub Actions workflow that builds and publishes
only the customer website. The inventory app remains in the repository without
being deployed to Pages. See [GITHUB_DEPLOYMENT.md](GITHUB_DEPLOYMENT.md) for the
one-time GitHub settings, the default live URL format, Supabase secrets, and
custom-domain steps.

## Previous project notes

A working local MVP built with Flutter for web and Android, using Malawi kwacha (MWK). The brand name is Mary’s Fashion. This first version assumes one business selling its own stock; seller onboarding, commissions and payouts are not implemented.

The custom looping-thread N logo is in `assets/images/nyasa-threads-logo.png` and is installed in the shop, inventory app, web favicon and Android launcher assets.

## Open the local apps

- Customer shop: http://127.0.0.1:8080/
- Staff inventory: http://127.0.0.1:8080/inventory/
- Staff password: `server/.staff-password`, generated uniquely by the local launcher. Do not publish that file.

Run `python3 server/start.py` from this folder to start the local server. It serves the compiled Flutter apps and the shared API. The development server intentionally binds only to this computer. Products, orders and the stock ledger persist in `server/nyasa.sqlite`; browser refresh does not delete them.

Customer shopping bags and favourites currently last for the open app session. Save the private tracking code after checkout to retrieve an order later. All listings and prices are illustrative. No online payment is taken. Delivery is a configurable demo rule of MWK 3,000; pickup is free. No taxes are calculated. A real shop must confirm its prices, tax handling, pickup address, delivery coverage and charges before launch.

## What works

Customer app: category browsing, name search, price sorting, saved pieces, product details, size/colour selection, stock-aware shopping bag, guest checkout, itemised totals, order confirmation and private order tracking.

Inventory app: staff sign-in, product creation and editing, unit costs and selling prices, quantity by size/colour, catalogue visibility, low-stock summary, inventory cost value, order details and fulfilment, cancellations that restore inventory, timestamped stock movements with reasons.

Both apps use the same database. Checkout prices come from the server. Transactions prevent overselling; checkout retries use an idempotency reference. Staff updates reject stale stock counts. Cancellation can only restore stock once. Public product responses exclude unit cost. Staff endpoints require a session token and expire after eight hours.

## Build and test

Flutter SDK used: 3.47.2. Add your Flutter SDK's `bin` directory to PATH first.

```sh
flutter pub get
flutter analyze
flutter test
python3 -m unittest discover -s server -v
flutter build web --release --no-web-resources-cdn
flutter build web --release --target lib/main_inventory.dart --base-href /inventory/ --output build/inventory --no-web-resources-cdn
python3 server/start.py
```

The Flutter web packaging follows https://docs.flutter.dev/deployment/web . Android packaging guidance: https://docs.flutter.dev/deployment/android .

## Android apps

The `shop` and `inventory` Android flavours have separate application IDs and app labels, so both can be installed together. Both share Flutter components and API contracts.

```sh
flutter build apk --debug --flavor shop
flutter build apk --debug --flavor inventory --target lib/main_inventory.dart
```

By default Android targets the host API at `http://10.0.2.2:8080`, suitable for an Android emulator on this computer. Physical devices need a reachable HTTPS backend and a build configured with `--dart-define=API_URL=https://your-api.example`. Web builds use their own origin by default. Serving web and API on different origins requires deliberate CORS configuration.

For public releases, configure your own release signing key; the generated project's debug signing is for development only. Debug cleartext traffic is enabled for the local emulator. Release builds require HTTPS. The local environment was missing Android command-line tools and NDK at the start of the build; see BUILD_STATUS.md for the actual build outcome.

## Before accepting real customers

This is a functional development MVP, not a publicly launched payment service. Deploy the API and database to managed infrastructure with HTTPS, backups and monitoring; use managed staff accounts with password hashing, login rate limiting and recovery instead of the local single-password setup. Add an authorised Malawi payment provider if online payments are desired, then verify payment webhooks and reconciliation. Add product photography uploads, a permanent brand, real stock, shipping/returns policies, tax rules and accessibility testing with customers. Decide whether to introduce independent sellers; that requires seller permissions, onboarding, moderation and settlement flows.

The supplied Python server cannot run directly on Sites' Cloudflare Workers runtime. Publishing only the Flutter files would leave checkout and inventory disconnected, so this handoff retains a working local preview. A compatible hosted API or a Worker/D1 port is still required for public hosting.

See REQUIREMENTS.md for the book-based design rationale, IMAGE_SOURCES.md for demo image attribution, and BUILD_STATUS.md for validation results.

### Latest local setup

See [LOCAL_SETUP.md](LOCAL_SETUP.md) for `.env` configuration, the Operations and Reports screens, backup instructions and acceptance testing. The updated server uses port 8083 from `.env`. Run `python3 server/check_setup.py` to check missing settings without printing secrets.
