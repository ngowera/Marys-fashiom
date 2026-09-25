# Shopping flow acceptance map

Reference: the two book screenshots supplied on 10 September 2026. Their numbered interfaces group related tasks; they are a flow specification, not nine required pages with identical visual layouts.

| Book interface | Mary’s Fashion screen | Result |
|---|---|---|
| 1: main page/category selection | Collection homepage and category controls | Implemented |
| 2: category items | Filtered product grid | Implemented |
| 3: search results | Search combined with category filtering | Implemented |
| 4: review item/add to shopping list | Product gallery, description, selling/regular price, size/colour, stock and quantity, Add to cart | Implemented |
| 5: choose models to compare | Compare controls on product cards and from item details; up to three pieces | Implemented |
| 6: review models/select best option | Side-by-side details and Choose this piece | Implemented |
| 7: review/confirm shopping list | Cart, quantities, removal, subtotal, availability/price refresh | Implemented |
| 8: shipment/payment/delivery/confirmation | Contact, payment method, delivery method/fee, final order review | Implemented for pay on collection/delivery; PayChangu payment initiation and verified payment confirmation remain blocked |
| 9: order confirmation report | Itemised quantities, variants, delivery charge, total, contact/address, payment-due notice, private tracking code and copyable report | Implemented |

The express-delivery branch states the complete fee and the difference from standard delivery before order submission. Cart price changes require reviewing the updated cart. An unavailable size or quantity cannot proceed to checkout; server-side transactions also reject stock races and roll back the entire order.

Content requirements are represented alongside actions: each piece has photos, name, category, description, sizes/colours, availability and pricing. The help screen exposes configured delivery, pickup, contact and returns information without inventing policies. Staff maintain the product content through Inventory; Operations records supplier receipts, damage, returns and payments already received.

## Verification

The automated journey at phone width exercises category selection, search, product details, variant selection, cart review, contact, payment-method information, express delivery notice, final review and itemised confirmation. Additional tests cover comparison layout, red favourites, product-editor sale fields, supplier validation, persistence and transactional inventory exceptions.

## Completion boundary

The local pay-on-collection/delivery flow is usable. An order placed is never labelled as a successful online payment. End-to-end PayChangu checkout, payment verification, failure/cancellation recovery and refund integration cannot be claimed complete yet. Supabase project selection and deployment, actual business policies and real-user acceptance testing remain outstanding. No Android build is required for this update.
