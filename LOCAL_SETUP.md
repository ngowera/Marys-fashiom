# Mary’s Fashion local setup

The project `.env` is server-only, excluded from Git, and restricted to its owner. `.env.example` lists supported settings without credentials. Do not add either file as a Flutter asset. Operating-system environment variables take precedence. Restart the server after changing configuration.

Run `python3 server/start.py` from this project. The configured preview port is **8083**, with the shop at `/` and inventory at `/inventory/`. Earlier preview processes on 8080/8081/8082 may still show older code. The existing staff password remains in `server/.staff-password`; a nonempty `NYASA_ADMIN_PASSWORD` environment setting overrides it.

Run `python3 server/check_setup.py` to see missing configuration names without showing secret values. The Supabase and PayChangu fields are reserved setup fields; supplying them alone does **not** deploy a database or activate payments. Project selection, schema and authentication integration, a reachable HTTPS backend, payment initiation and webhook verification still need completion. Never place a service-role key or PayChangu secret in the Flutter app.

`STANDARD_DELIVERY_MWK` and `EXPRESS_DELIVERY_MWK` are read by the server and used in checkout. The current amounts are demonstration rates. Complete `DELIVERY_AREAS`, `PICKUP_LOCATION`, `SHOP_CONTACT`, and `RETURNS_POLICY` before launch. Own-stock operations remain the working assumption until the selling model is confirmed.

## Staff workflow

1. Add products and their size/colour stock, photos and selling prices in Inventory.
2. In Operations, add a supplier, then use Receive stock with its invoice/delivery reference. Repeated submission of the same operation cannot add stock twice.
3. Record damaged stock with a reason and reference; quantities cannot exceed available stock.
4. Manage order packing, dispatch and completion in Orders. Record payment collected only after receiving the money; it does not charge a customer.
5. Record returns against completed orders. Mark items suitable for resale only after inspecting them. Repeated returns cannot exceed purchased quantities. Return records identify refund amounts for manual review; no refund is sent automatically.
6. Reports show completed item sales, return values, cost of goods and gross margin, plus low-stock sizes. This is not a net-profit report. Older orders without cost snapshots are explicitly marked as estimates. Delivery costs, operating expenses and taxes are excluded.

Cart contents and favourites are saved on the shopper’s device. Clearing browser/app data removes them; they do not synchronise across devices. Staff credentials and customer addresses are not stored with the cart.

## Backups

Run `python3 server/backup.py`. It creates an owner-only ZIP in `server/backups/` containing a consistent SQLite snapshot and uploaded photos. Back up the archive somewhere private. To recover, stop the local server first, preserve the current data, and restore `nyasa.sqlite` into `server/` and `uploads/` into `server/uploads/`. The environment and staff password are intentionally excluded and should be managed separately.

## Acceptance walkthrough before launch

- A shopper finds a dress through categories and through search, compares pieces, chooses the correct size/colour, saves it and reopens the shop.
- A shopper reviews the complete price, delivery fee and policy before placing an order. Unavailable sizes and changed prices produce clear errors.
- Staff upload real product photos, receive stock, record a loss and fulfil an order.
- Staff record an eligible return once and verify the stock and gross-margin report.
- Test live payments only after the selected provider/account is configured, including failed, cancelled and repeated attempts, webhook verification and refund reconciliation.
- Test the Android builds on real devices and slow networks before publishing.
