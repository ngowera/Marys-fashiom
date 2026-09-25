# Build status

Project location: /home/mary-tamvekenji/Documents/nyasa threads

- Flutter analysis: passed, no issues.
- Flutter widget tests: 3 passed, including browsing, size selection and bag totals at 390px and 1280px widths, and the inventory sign-in gate.
- API integration test: passed; verifies staff access, server pricing, idempotent checkout, rollback, private tracking, cancellation/restock, stale edits and competing checkouts.
- Customer web release: built successfully.
- Inventory web release: built successfully.
- Android: source and two flavours are present. No APK has been produced or verified. The initial build was interrupted; an offline Gradle check subsequently timed out after 90 seconds. Flutter doctor reports missing Android command-line tools and unknown license status; no NDK was installed when checked.
- Hosting: local preview only; a hosted API and database are required before publishing the apps.
- Real online payments: not connected. Checkout uses pay on collection/delivery.

Custom looping-thread logo installed in both Flutter apps, web favicon and Android launcher assets. Both web releases rebuilt successfully with the new logo. Three Flutter widget tests passed after the logo change; both previews serve the exact PNG.

Main-logo update: larger header mark, named browser icon, adaptive/round launcher icons and Android 13 monochrome layer added. Android resources compiled and linked successfully with aapt2 using the installed android-37.0 platform. This validates resources only; it is not a runnable app APK. Three Flutter layout/flow tests passed.

Rebrand: Mary’s Fashion; website and Flutter package identity marysfashion. Added bundled serif/sans fonts, a two-photo editorial display and a branded footer. Cloud/payment integration remains pending.

Mary’s Fashion rebrand verified: Flutter analysis passed, all three widget tests passed, both web release builds succeeded, metadata and bundled brand fonts verified. Both local routes returned HTTP 200.


10 September 2026 shopping-flow update: Flutter analyzer clean; five widget tests passed at phone/desktop sizes, including red hearts, cart order, checkout fees, inventory sale fields and comparison layout. Two server integration tests passed, covering authentication, stock concurrency and rollback, uploads, discounts and expected-total validation. Shop release web build passed. Updated local server runs on http://127.0.0.1:8081/ because an older process holds port 8080. Supabase/PayChangu and Android APK verification remain pending.
Inventory release web build also passed; both preview routes return HTTP 200.

Configuration and local operations update: seven Flutter widget tests and four server integration tests passed. Flutter analyzer reports no issues. Shop and inventory release web builds passed and both routes on port 8082 return HTTP 200. `.env` is owner-only (0600), not bundled, and cannot be downloaded from the server. A database/photo backup was created and its archive integrity verified. Android build is being checked separately.

After resume: shop and inventory web builds passed on port 8083; seven widget tests and four server integration tests passed; analyzer clean. No further Android builds were run after the user requested web-only work. Supabase project selection, live integration credentials and final shop policies remain pending.

Book-flow completion review: product-detail comparison entry, explicit express surcharge, itemised copyable confirmation report, cart price/stock guards added. Eleven Flutter tests (including a complete phone-sized shopping journey) and four server integration tests passed. Analyzer clean. Local web preview uses release optimization level 1 for faster iteration. PayChangu and Supabase integration remain pending; no Android builds were run.
