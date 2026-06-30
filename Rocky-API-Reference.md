# Curaleaf Laboratories "Rocky" API — Reference

Source: published OpenAPI 3.1 spec at `https://api.curaleaflaboratories.co.uk/openapi.json` (fetched 30 Jun 2026). Confirmed by Phil Jones (Curaleaf CTO). Dev/sandbox base: `https://api.curaleaflaboratories.dev` (ask to activate).

## Authentication
- Header: `X-API-Key: <your key>` on **every** request. No Bearer token, no username pair.
- Rate limits apply (values TBC with Curaleaf).

## Core concepts
- **Formula** = something that can be *prescribed* (e.g. "Cura-WPT Flower THC 24% CBD <1%").
- **Product** = a specific orderable amount of a formula (e.g. a 10 g pack). A formula always has ≥1 product.
- Prescriptions/clinical-needs are expressed in **formulas**; purchase orders in **products**.
- Units: `ml, g, mg, count`. Forms: `CAPSULE, DEVICE, FLOS, GRANULATE, LOZENGE, OIL, OINTMENT, ORAL_DROPS, ORAL_SPRAY, PASTILLE, PESSARY_SUPPOSITORY, PRE_ROLL, SHAKE, VAPE_CARTRIDGE, WET_FLOWER`.

## Ordering flow A — manual prescription
1. `POST /v1/prescribers/` — prescriber details incl. PIN → returns Prescriber ID.
2. `GET /v1/formulas/` — look up formula IDs.
3. `POST /v1/prescriptions/` — `{serialNumber, prescriberId, issueDate, items[{formulaId, unitsNeededCount}]}` → returns Prescription ID.
4. `POST /v1/prescriptions/{id}/file/` — multipart upload of the prescription scan (the "copy").
5. `GET /v1/products/` — look up product IDs (and current stock/price).
6. `POST /v1/purchase-orders/` — `{customerReference, items[{productId, count}]}` → returns Purchase Order ID.
7. `GET /v1/shipments/?purchaseOrderId=…` — dispatched shipment details.

## Ordering flow B — Curaleaf Clinic prescription (barcode)
1. `POST /v1/prescription-from-image/` — multipart image of the barcoded script → returns Prescription ID.
2. `POST /v1/purchase-order-from-prescriptions/` — `{customerReference, prescriptionIds[]}` → returns Purchase Order ID.
3. `GET /v1/shipments/?purchaseOrderId=…`.

> For our prescription-gated **sub-order** model (each prescription independently placeable/trackable), call `post_purchase_order_from_prescriptions` **once per prescription** so each gets its own PO. The API also allows one PO to span multiple prescriptions if ever wanted.

## Stock & price re-check (the placement gate)
- `GET /v1/products/` returns `Product.quantity` (integer stock count) and `patientPackPrice` per product.
- `POST /v1/quotes/` — `{items[{packId, quantity}]}` → `{shippingPrice, taxRate, items[{packId, quantity, inStock(bool), wholesalePackPrice, patientPackPrice}]}`. This is the live in-stock + price check to run immediately before placing.

## Delivery / "delivered" status
- **No courier API** → Rocky cannot report a courier-sourced "delivered" status. Shipments give dispatch + contents only, no delivered timestamp.
- Courier enum on a PO: `DX, POLAR_SPEED, CURALEAF, TRANSFER, OTHER` (note: not DPD).
- ⇒ "Ready for collection" must be driven by **pharmacy staff goods-in**, not API delivery status. Use shipments for in-transit visibility only.

## Change polling (no webhooks)
Poll the event routes with an `after=<ISO datetime>` query to get changes since last check:
`GET /v1/product-events/`, `/v1/prescription-events/`, `/v1/purchase-order-events/`, `/v1/shipment-events/`, `/v1/formula-events/`, `/v1/prescriber-events/`, `/v1/clinical-need-events/`. Each returns `events[{<entity>Id, customerId, lastUpdated}]`; then GET the entity by ID for detail. Interval + rate limits still to agree with Curaleaf.

## Key response schemas
- **Product**: `id, customerId, state(ACTIVE|DISCONTINUED), formulaId, formulaName, formulaUnit, quantity, patientPackPrice`.
- **Prescription** (`PrescriptionWithItems`): `id, serialNumber, state(ACTIVE|FULFILLED|EXPIRED|CANCELLED|PENDING), prescriberId, prescriberName, customerId, issueDate, expiryDate, items[{formulaId, formulaName, unit, unitsNeededCount, unitsAssignedCount}]`. (Curaleaf returns its own `expiryDate` — our 28-day "appropriate date" dispensing rule remains the pharmacy's responsibility.)
- **PurchaseOrder** (`PurchaseOrderWithItems`): `id, state(CREATED|PROCESSING|FULLY_ALLOCATED|CANCELLED), courier, customerReference, customerId, issuedDate, shippingAddress[], items[{productId, packSize, packsOrderedCount, packsAllocatedCount, packsReturnedCount, unit, formulaId}]`.
- **Shipment** (`ShipmentWithItems`): `id, createdAt, customerId, shipmentCharge, taxRate, shippingAddress[], purchaseOrderId, purchaseOrderCustomerReference, purchaseOrderIssuedDate, items[{sku, productId, productPackSize, packCount, packsReturnedCount, packPrice, batchNumber, batchExpiryDate, unit, formulaId}]`.
- **Quote** (`POST /v1/quotes/`): `{shippingPrice, taxRate, items[{packId, quantity, inStock, wholesalePackPrice, patientPackPrice}]}`.

## Invoicing
No dedicated invoice endpoint. Financials come from the **Shipment** (`shipmentCharge`, `taxRate`, per-item `packPrice`) and the pre-order **Quote**. `customerReference` on the PO is the key to reconcile our order ↔ Curaleaf shipment/charge.

## Pagination (list endpoints)
`pageNumber, pageSize, sortColumn, sortDirection (asc|desc), searchQuery, stateFilter`.

## Corrections vs earlier TRD assumptions
- Auth is `X-API-Key` header (not API-key + username pair).
- Endpoints are `/v1/…` with trailing slashes; placing an order is `post_purchase_order` (products) or `post_purchase_order_from_prescriptions` (prescriptionIds[]).
- A prescriber must be created first (`post_prescriber`, incl. PIN/GMC/GPhC) before a prescription.
- The prescription scan is uploaded via a separate `…/file/` multipart call.
- Stock **is** available now (`Product.quantity` + `/v1/quotes/` `inStock`), even though Curaleaf's "canonical stock-status" reporting is still under internal discussion.
- Couriers are `DX/POLAR_SPEED/CURALEAF/TRANSFER/OTHER`, not DPD.
