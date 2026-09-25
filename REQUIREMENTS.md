# Book-based requirements and implementation

Reference: Emrah Yayici, *Business Analysis Methodology Book: Business Analyst's Guide to Requirements Analysis, Lean UX Design and Project Management at Lean Enterprises and Lean Startups*, 2015. Read from the PDF supplied in Downloads. Page references below count PDF pages, including front matter. No book content or page images are bundled in this project.

Chapter 5, “Requirements Gathering” (PDF pages 40–44), separates business goals, user requirements, functional requirements, quality requirements and business rules. It recommends customer-centred discovery, prototypes, resolving conflicts early and considering the impact of changes. It does not itself contain the detailed cart and checkout flow.

Chapter 6, “Requirements Documentation” (starts PDF page 45), distinguishes main, alternative and exception scenarios. Its “View and Order a Product” discussion describes category browsing as the main path, search as an alternative, and ordering unavailable stock as an exception. The flowchart on PDF page 53 shows item review, shopping list, shipment details, payment and order confirmation. Our checkout adapts this to pay on collection/delivery; it does not claim to implement online payment.

Chapter 7, “UX Design and Usability”, provides the interaction and information architecture guidance. PDF page 71 discusses card sorting to organise categories. Here “cards” means a research technique, not payment cards. Our initial categories are Dresses, Shoes, Bags and Accessories. These are a hypothesis to test with real customers, not the result of a completed card-sorting study.

| Goal / scenario | Implementation | Acceptance condition |
|---|---|---|
| Find and buy an item | Browse categories, search, product details, select variant, bag, checkout | The selected size and quantity appear in the order |
| Find an item another way | Search by product name and sort by price | Search and category filtering work together |
| Item becomes unavailable | Server checks variant stock inside one transaction | Failure does not partially reduce stock or create an order |
| Review cost before ordering | MWK subtotal, delivery fee and total | The server recalculates prices and never trusts client prices |
| Retry checkout | Random idempotency reference | One reference creates only one order |
| Track an order | Order reference plus private tracking token | Incorrect tokens cannot retrieve customer details |
| Manage inventory | Staff-only edit/create forms with size/colour quantities | Public API cannot change products or read costs |
| Count stock while orders arrive | Optimistic check against prior variant quantities | Stale stock updates are rejected |
| Cancel an order | Allowed state transitions and restock transaction | Stock is restored once, not on repeated cancellation |
| Audit stock | Opening balances, adjustments and order events | Every quantity change is recorded with a reason and time |

## Explicit business rules

- Currency: MWK, confirmed by the user. This MVP uses whole kwacha prices stored as integers.
- Stock is tracked separately by size/colour. Quantities cannot be negative.
- A shopping bag does not reserve stock. Successful order placement reserves it by deducting availability.
- Pickup fee: MWK 0. Demonstration delivery fee: MWK 3,000, controlled by the server. Actual service areas, rates and tax handling remain to be confirmed.
- Payment method: pay on collection/delivery. Order placement does not mean payment was collected.
- Fulfilment: Placed → Packed → Dispatched → Completed. Cancellation is allowed before dispatch and restores stock. Returns after delivery are outside this initial implementation.
- Staff access uses a local development password with expiring sessions. Production identity and account recovery are not implemented.

## Discovery still needed

The name is Mary’s Fashion. Confirm own-stock versus independent sellers, delivery areas, pickup location, product photography, real prices, returns/refunds and payment provider. Observe customers trying to find a dress, choose their size and check out; observe staff receiving and counting stock. Run a real card-sorting exercise with representative shoppers before expanding categories. These activities are recommended by the book; they have not yet been carried out.

## Shopping flow implemented from the supplied screenshots (10 September 2026)

The book's diagrams describe tasks and screen groupings. These map to: (1) homepage and categories, (2) category results, (3) search results, (4) product details and cart shortcut, (5) selecting products for comparison, (6) side-by-side comparison and choosing size/colour, (7) cart review and quantity changes, (8) contact, payment method, delivery fees and final review, and (9) order confirmation with tracking details. Favorites use red hearts; header actions are cart, favorites, then location tracking.

Inventory supports up to eight uploaded JPG/PNG/WebP photos per product (4 MB each), cover selection, product name, category, description, size/colour stock rows, unit cost, regular price, optional lower sale price, visibility, and adjustment reasons. The storefront displays the original crossed-out price beside the sale price. Existing order and stock-movement workflows remain available.

Current storage is local SQLite plus server/uploads. Back up both together. Supabase and PayChangu are not connected. Checkout is pay on delivery/collection in the local preview; standard and express delivery fees are demonstration rates. Android source shares these screens, but a full APK build remains unverified.

## Local operations update (10 September 2026)

Added server-only `.env` loading, public shop-policy settings, supplier records, stock receipts with delivery references, damaged-stock adjustments, completed-order returns, payment-collection records, low-stock lists, and gross-margin reporting. Operations are transactional and receipt/return retries are idempotent. Returns cannot exceed the original purchased quantity and only explicitly inspected resalable items restore stock. Refund transfers remain external and pending review.

Cart contents and favourites now persist on the current device. The shop includes size/fit guidance and configurable delivery, contact and return-policy information. An owner-only backup command includes the local database and uploaded product photos.

Remaining external/business dependencies: selected active Supabase project, deployed schema and staff authentication, PayChangu account credentials and reachable HTTPS integration, actual delivery/returns rules, independent-seller decision, real product measurements, customer/staff usability sessions, and Android device acceptance testing. Blank `.env` service settings do not activate those integrations.
