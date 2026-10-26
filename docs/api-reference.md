# PASAL API reference (v1)

For front-end developers: website, Flutter phone app, Mac app.
This file is checked against the code in `backend/` and its tests. If code and this file disagree, the code wins, then fix this file.

## 1. Quick facts

| Item | Value |
|------|-------|
| Base URL (local) | `http://localhost:8000/api/v1` (start with `php artisan serve` in `backend/`) |
| Format | JSON in, JSON out. Always send `Accept: application/json` and `Content-Type: application/json` |
| Auth | Bearer token. Header `Authorization: Bearer <token>` |
| Token life | 30 days. After that, log in again |
| Businesses | Many. Each business has its own data, users, VAT rate and PAN. A business never sees another one's data. Every request is automatically limited to the business of the logged-in user, so **no request ever sends a business id** |
| Who can log in | Invite-only. There is no sign-up endpoint. A new business is created by the platform owner (`php artisan pasal:add-business`). The business owner then adds staff with `POST /users` |
| Roles | `owner` (everything) and `staff` (counter work only). See section 2.1 |
| Currency | NPR, sent as **whole paisa** (integers). Rs 113.00 is `11300` |
| Rate limit | Login: 5 tries per minute for one email from one address, and 30 per minute per address. Everything else: 120 requests per minute per user |

## 2. Rules that apply everywhere

### Money
- All money fields are integers in **paisa**. Never send or expect decimals.
- Show to the user as `value / 100` with 2 decimals. Round only when displaying.
- Money names: `total`, `paid`, `balance`, `amount`, `*_price`, `*_cost`, `*_vat`, `payable`, `carry_*`, `profit`.

### Dates and times
- Date-times are ISO 8601 in UTC, for example `2026-10-26T07:26:03+00:00`. Convert to Nepal time (UTC+5:45) when showing.
- Plain dates are `YYYY-MM-DD` in the **Gregorian (AD)** calendar. The API does not know Nepali (BS) dates. The app must convert BS to AD before sending.
- Request fields named `*_at` accept any date string. Leave them out to use "now".

### Responses
- One record: `{ "data": { ... } }`
- A list: `{ "data": [ ... ], "links": { "first", "last", "prev", "next" }, "meta": { "current_page", "last_page", "per_page", "total", "from", "to", ... } }`
- Lists are paged. `?page=2`. `?per_page=` works where noted, **max 50**. Default 20.
- Delete: `{ "message": "Deleted." }`
- Reports, ledgers and the VAT preview are **not** wrapped in `data`. Each section below says so.

### Errors (one shape)
```json
{ "message": "The name field is required.", "errors": { "name": ["The name field is required."] } }
```
`errors` is only there for validation problems (422). Other errors only have `message`.

| Status | Meaning | What the app does |
|--------|---------|-------------------|
| 401 | No token, bad token, expired or revoked token. `{ "message": "Unauthenticated." }` | Clear the saved token, show the login screen |
| 404 | Record or URL does not exist. `{ "message": "Not found." }` | Show "not found" |
| 405 | Wrong HTTP method. `{ "message": "Method not allowed." }` | Bug in the app |
| 422 | Bad input, or a business rule failed (not enough stock, overpayment). Read `errors` | Show each message next to its field |
| 429 | Too many requests. Header `Retry-After` says how many seconds | Wait, then retry |
| 500 | Server bug. The message is generic on purpose | Show "something went wrong", do not retry in a loop |

Show the text from `errors` to the user as is. It is written to be read by people.

### Your business only
Every list, record, ledger and report shows only your own business. A record that belongs to another business answers **404**, the same as a record that does not exist. An id from another business inside a request body (an item in a sale, a customer, a supplier, a category) answers **422** on that field. A `business_id` in a request body is ignored.

### 2.1 Roles

| Area | Owner | Staff |
|------|-------|-------|
| Login, logout, `/me`, change own password, `GET /business` | yes | yes |
| Customers (all five methods) and a customer's ledger | yes | yes |
| Read categories and items | yes | yes, but `cost_price` is `null` |
| Create a sale, read sales, take a payment on a sale | yes | yes |
| Create, edit, delete categories and items | yes | **403** |
| Stock adjustments | yes | **403** |
| Suppliers, supplier ledger, purchases, paying a supplier | yes | **403** |
| Expenses, reports, VAT | yes | **403** |
| Users (`/users`) and editing the business (`PATCH /business`) | yes | **403** |

A 403 looks like `{ "message": "Only the owner can do this." }`. The app should read `role` from `/me` and hide what the user cannot use, but the server is what enforces it.

### Soft delete
Deleting an item, supplier or customer hides it from lists and from new sales. Old sales and purchases still show its name. Only items can be restored (`POST /items/{id}/restore`).

---

## 3. Auth

### POST `/login`  (no token needed)
Request
```json
{ "email": "mum@example.com", "password": "their-password", "device_name": "Pixel 8" }
```
`device_name` is optional (max 100). It is only a label.

Response 200
```json
{
  "token": "12|abcDEF...",
  "user": {
    "id": 1, "name": "Mum", "email": "mum@example.com", "role": "owner",
    "business": { "id": 3, "name": "Himal Store", "pan": "123456789", "phone": null, "address": null, "vat_rate": 13.0 }
  }
}
```
Wrong email or password: 422 with `errors.email`. The message is the same for both on purpose.
Too many tries: 429.

### POST `/logout`
Deletes the token that sent this request. Response `{ "message": "Logged out." }`.

### POST `/logout-all`
Deletes every token of this user, on every device. Use it for a lost phone. Response `{ "message": "Logged out on all devices." }`.

### GET `/me`
Same object as `user` in the login response (not wrapped). Use it at app start to check the saved token still works and to read the role.

### POST `/me/password`
```json
{ "current_password": "old-one", "password": "a-new-password-10+" }
```
New password: 10 to 100 characters and different from the old one. Wrong current password: 422 with `errors.current_password`. On success every **other** device is signed out and this one stays signed in. Response `{ "message": "Password changed." }`.

---

## 3.1 Business and users

### GET `/business`  (owner and staff)
```json
{ "data": { "id": 3, "name": "Himal Store", "pan": "123456789", "phone": null, "address": null, "vat_rate": 13.0 } }
```

### PATCH `/business`  (owner)
Send any of `name` (max 150), `pan` (max 20), `phone` (max 30), `address` (max 255), `vat_rate` (number from 0 to 100). Response is the same shape.
`vat_rate` applies to **new** sales. Old sales keep the rate they were made with.

### Users  `/users`  (owner)
User: `{ "id": 5, "name": "Sita", "email": "sita@example.com", "role": "staff" }`

| Method | Path | Notes |
|--------|------|-------|
| GET | `/users` | People of your business only, 50 per page |
| POST | `/users` | 201. Body `name`, `email`, `password`, `role` (`owner` or `staff`), all required. Password 10 to 100 characters. The email must not exist anywhere in the system, because one email belongs to one business |
| PATCH | `/users/{id}` | Send any of `name`, `email`, `password`, `role`. Changing `password` or `role` signs that person out on every device. You cannot change your own role (422) |
| DELETE | `/users/{id}` | Signs them out and removes them. You cannot delete yourself (422) |

A user from another business gives 404.

---

## 4. Inventory

### Categories  `/categories`
Fields: `id`, `name` (max 100, unique inside your business). Reading is for everyone, changing is owner only.

| Method | Path | Notes |
|--------|------|-------|
| GET | `/categories` | Sorted by name, 50 per page |
| POST | `/categories` | Body `{ "name": "Grocery" }`. 201 |
| GET | `/categories/{id}` | |
| PUT/PATCH | `/categories/{id}` | Body `{ "name": "..." }` |
| DELETE | `/categories/{id}` | Items in it keep existing with `category_id: null` |

### Items  `/items`
```json
{
  "id": 7, "category_id": 2, "name": "Rice 5kg", "sku": "RICE-5", "unit": "pcs",
  "vat_applies": true, "cost_price": 90000, "sell_price": 100000,
  "quantity": 12, "low_stock_at": 3, "is_low_stock": false
}
```
| Field | Rules |
|-------|-------|
| `name` | required, max 150. Extra spaces are removed. It must be **new inside your business**, ignoring capital letters ("Rice 5kg" and " rice  5KG" are the same name). Another business may use the same name. See "Reusing names" below |
| `sku` | **optional** (a code or barcode), max 50. Empty or missing is saved as `null`, and many items may have none. If given, it is unique **inside your business** |
| `unit` | optional, max 20, default `pcs` |
| `vat_applies` | optional boolean, default `true`. `false` means the item has no VAT |
| `cost_price`, `sell_price` | required, integer paisa, 0 to 10,000,000,000. When a **staff** user reads an item, `cost_price` is `null` |
| `low_stock_at` | optional, 0 to 1,000,000. `is_low_stock` is true when `quantity <= low_stock_at` |
| `category_id` | optional, must exist |
| `quantity` | **read only**. Sending it is ignored. It changes only by purchases, sales and stock adjustments |

`sell_price` **includes VAT**. `cost_price` does **not** include VAT.

| Method | Path | Notes |
|--------|------|-------|
| GET | `/items` | Query: `search` (name or SKU, part of word), `category_id`, `low_stock=1`, `trashed=only` (deleted items, owner only), `per_page` (max 50), `page` |
| GET | `/items/suggest?q=ri&limit=10` | Type-ahead. See below. Owner and staff |
| POST | `/items` | 201. `quantity` starts at 0. Add stock with a purchase |
| GET | `/items/{id}` | |
| PUT/PATCH | `/items/{id}` | Send the full required fields again. An item may keep its own name |
| DELETE | `/items/{id}` | Soft delete. **422 if the item still has stock** (`errors.quantity`). Fix the stock to 0 first with a stock adjustment |
| POST | `/items/{id}/restore` | Owner only. Brings a deleted item back with its history. 422 if another item now has the same name |

**Reusing names.** Before creating an item, the app should call `GET /items/suggest?q=<what the user typed>` after each pause in typing (wait about 250 ms) and show the result as a pick list. Picking an existing item reuses it, so the same product is never made twice.
- Returns `{ "data": [ item, ... ] }` using the normal item shape. Only your own, not-deleted items. Names that **start with** the text come first, then names that contain it. `limit` is 1 to 20 (default 10). Empty `q` returns an empty list. Staff get `cost_price: null`.

If the user creates (or renames to) a name that already exists anyway, the answer is 422 in the usual shape, plus a pointer to the item to use:
```json
{
  "message": "An item named \"Rice 5kg\" already exists. Use that item instead.",
  "errors": { "name": ["An item named \"Rice 5kg\" already exists. Use that item instead."] },
  "existing_item": { "id": 7, "name": "Rice 5kg", "deleted": false }
}
```
When `deleted` is `true`, the name belongs to a deleted item. Show "Restore it?" and call `POST /items/{id}/restore`, so the old stock history comes back.

Deleting an item never changes old sales and purchases. They keep showing its name.

### Stock adjustment  POST `/stock-adjustments`
Fix stock by hand (damaged, counted again). Writes a history row.
```json
{ "item_id": 7, "change": -4, "note": "damaged" }
```
`change`: non-zero integer between -1,000,000 and 1,000,000. `note` required (max 255).
Response 200: the updated item inside `data`. If it would make stock negative: 422 with `errors.quantity`.

### Suppliers (dealers)  `/suppliers`
Fields: `id`, `name` (required, max 150), `phone`, `address`, `pan` (max 20), `note` (max 1000). Same five methods as categories (list, create, show, update, delete). List sorted by name, 50 per page.

---

## 5. Finance

### Customers  `/customers`
Fields: `id`, `name` (required), `phone`, `address`, `pan`. Same five methods as categories.
A customer is needed for credit sales (udhar). Walk-in cash sales need no customer.

### Sales  `/sales`
Sale response:
```json
{
  "data": {
    "id": 31, "bill_no": "S-0031", "customer_id": 4,
    "customer": { "id": 4, "name": "Hari", "phone": "9800000000", "address": null, "pan": null },
    "total": 11300, "paid": 5000, "balance": 6300,
    "vat_rate": 13.0, "taxable_amount": 10000, "vat_amount": 1300, "exempt_amount": 0,
    "sold_at": "2026-10-26T07:26:03+00:00", "note": null,
    "items": [ { "item_id": 7, "item_name": "Rice 5kg", "quantity": 1, "unit_price": 11300, "line_total": 11300 } ],
    "payments": [ { "id": 9, "direction": "in", "sale_id": 31, "purchase_id": null, "amount": 5000, "method": "cash", "paid_at": "..." } ]
  }
}
```
`items` and `payments` appear in `GET /sales/{id}` and in the create response (`items` only). The list has `customer` but not `items` or `payments`.

How the numbers work: `total` is what the customer pays, VAT included. `vat_amount` is the VAT inside `total` (only for items with `vat_applies = true`). `taxable_amount` is the price of those items without VAT. `exempt_amount` is the no-VAT items. `total = taxable_amount + vat_amount + exempt_amount`. `vat_rate` is saved on the sale, so changing the rate later does not change old sales.

| Method | Path | Notes |
|--------|------|-------|
| GET | `/sales` | Newest first. Query: `unpaid=1` (still owes), `customer_id`, `per_page` (max 50), `page` |
| GET | `/sales/{id}` | With lines, customer and payments |
| POST | `/sales` | 201. See below |

There is no edit and no delete for sales yet.

**POST `/sales`** request
```json
{
  "customer_id": 4,
  "paid": 5000,
  "method": "cash",
  "bill_no": "S-0031",
  "sold_at": "2026-10-26T13:00:00+05:45",
  "note": "",
  "items": [ { "item_id": 7, "quantity": 1, "unit_price": 11300 } ]
}
```
| Field | Rules |
|-------|-------|
| `items` | required, 1 to 100 lines. Each: `item_id` (must exist, not deleted), `quantity` 1 to 1,000,000, `unit_price` optional (default is the item's `sell_price`), 0 to 10,000,000,000 |
| `paid` | optional, default 0. Cannot be more than the total |
| `customer_id` | **required when `paid` is less than the total** (credit sale). Otherwise optional |
| `method`, `bill_no`, `sold_at`, `note` | optional |

It is all or nothing. If one line has not enough stock, nothing is saved (422, `errors.quantity`). On success stock goes down, and if `paid > 0` a payment is recorded.

### Purchases  `/purchases`
```json
{
  "data": {
    "id": 12, "bill_no": "INV-889", "bill_date": "2026-10-24",
    "supplier_id": 3, "supplier": { "id": 3, "name": "Himal Traders", "phone": null, "address": null, "pan": "123456789", "note": null },
    "total": 1130000, "paid": 500000, "balance": 630000, "vat_amount": 130000,
    "bought_at": "2026-10-26T07:26:03+00:00", "note": null,
    "items": [ { "item_id": 7, "item_name": "Rice 5kg", "quantity": 100, "unit_cost": 10000, "line_total": 1000000 } ],
    "payments": []
  }
}
```
`total = sum of line_total + vat_amount`. Unit costs are **without VAT**. `vat_amount` is copied from the supplier's bill.

| Method | Path | Notes |
|--------|------|-------|
| GET | `/purchases` | Newest first. Query: `unpaid=1` (we still owe), `supplier_id`, `per_page`, `page` |
| GET | `/purchases/{id}` | |
| POST | `/purchases` | 201 |

**POST `/purchases`** request
```json
{
  "supplier_id": 3, "bill_no": "INV-889", "bill_date": "2026-10-24", "vat_amount": 130000,
  "paid": 500000, "method": "cash",
  "items": [ { "item_id": 7, "quantity": 100, "unit_cost": 10000 } ]
}
```
`supplier_id` required. `items` 1 to 100 lines, each with `item_id`, `quantity` (1 to 1,000,000), `unit_cost` (0 to 10,000,000,000). `vat_amount` 0 to 1,000,000,000,000 (use 0 if the supplier gave no VAT bill). `paid` cannot be more than `total`.
On success stock goes **up**, and each item's `cost_price` is set to the newest `unit_cost`.
`bill_date` matters for VAT: input VAT is counted in the period of the supplier's bill date.

### Payments  POST `/payments`
Record money coming in from a customer (against a sale) or going out to a supplier (against a purchase). Send **exactly one** of `sale_id` or `purchase_id`.
```json
{ "sale_id": 31, "amount": 6300, "method": "cash", "paid_at": "2026-10-27T10:00:00+05:45" }
```
`amount`: integer, 1 to 1,000,000,000,000,000, and not more than the balance left (else 422, `errors.amount`, message says how much is left).
Response 201:
```json
{ "data": { "id": 10, "direction": "in", "sale_id": 31, "purchase_id": null, "amount": 6300, "method": "cash", "paid_at": "..." }, "balance_left": 0 }
```
`direction` is `in` for a sale and `out` for a purchase. It is set by the server. Staff may only send `sale_id`. A staff user who sends `purchase_id` gets 403.

### Expenses  `/expenses`
Fields: `id`, `title`, `category`, `amount`, `spent_at`.
| Method | Path | Notes |
|--------|------|-------|
| GET | `/expenses` | Newest first, `per_page` (max 50) |
| POST | `/expenses` | 201. Body `{ "title": "Electricity", "category": "bills", "amount": 150000, "spent_at": "2026-10-20" }`. `title` required (max 150), `amount` 1 to 1,000,000,000,000, `category` max 50 |

There is no edit and no delete for expenses yet.

### Ledgers (not wrapped in `data`)
**GET `/customers/{id}/ledger`** - what this customer owes us (udhar).
```json
{
  "customer": { "id": 4, "name": "Hari", "phone": null, "address": null, "pan": null },
  "total_sales": 20000, "total_paid": 8000, "owes": 12000,
  "sales": [ { "id": 31, "sold_at": "2026-10-26T07:26:03.000000Z", "total": 11300, "paid": 5000, "balance": 6300 } ]
}
```
**GET `/suppliers/{id}/ledger`** - what we owe this supplier. Same idea with `total_purchases`, `total_paid`, `we_owe` and `purchases` (with `bought_at`). Both show the latest 200 records.

### Report  GET `/reports/summary?from=2026-10-01&to=2026-10-31`  (not wrapped)
`from` and `to` required, `to` not before `from`, both AD dates, both days included.
```json
{
  "from": "2026-10-01", "to": "2026-10-31",
  "sales_total": 10000, "vat_collected": 1150, "cost_of_goods": 6000,
  "expenses_total": 1500, "profit": 1350,
  "stock_value": 24000, "owed_to_us": 0, "we_owe": 0
}
```
`profit = sales_total - vat_collected - cost_of_goods - expenses_total`. It can be negative.
`stock_value` (quantity x cost price), `owed_to_us` and `we_owe` are **as of today**, not limited to the date range.

---

## 6. IRD VAT section

All amounts are paisa. Dates are AD. The API does **not** convert Nepali months. The app lets the user pick the Nepali month, converts its first and last day to AD, and sends `from` and `to`.

### How the numbers are made
```
output_vat = VAT on sales in the period          (sum of sales.vat_amount)
input_vat  = VAT on purchase bills in the period (sum of purchases.vat_amount, by bill_date)
net        = output_vat - input_vat - carry_in
net > 0   -> payable = net, carry_out = 0
net <= 0  -> payable = 0,   carry_out = -net  (credit carried to the next period)
```
`carry_in` is the `carry_out` of the latest saved filing before this period. If there is none, it is `opening_carry` (a number the user types once, taken from their last real IRD return, and 0 if unsure).
Only purchases with `vat_amount > 0` count. Due date = last day of the period + 25 days (VAT Act 2052, section 18).

**Not confirmed with IRD yet:** the VAT rate (13% by default, and each business sets its own with `PATCH /business`), the names of the boxes on the IRD portal form, and return-form details. The numbers below are the building blocks. Map them to the portal's boxes once we have the form.

### GET `/vat/preview?from=2026-10-17&to=2026-11-16&opening_carry=0`  (not wrapped)
Calculates only. Saves nothing.
```json
{
  "period_from": "2026-10-17", "period_to": "2026-11-16", "due_date": "2026-12-11", "vat_rate": 13.0,
  "sales_bills": 140, "sales_taxable": 9000000, "sales_exempt": 200000, "output_vat": 1170000,
  "purchase_bills_with_vat": 12, "purchases_taxable": 5000000, "input_vat": 650000,
  "carry_in": 0, "payable": 520000, "carry_out": 0,
  "carry_in_source": "opening value you typed (0 if none)"
}
```

### Filings (saved periods)
```json
{
  "data": {
    "id": 3, "period": "2083-07", "period_from": "2026-10-17", "period_to": "2026-11-16", "source": "computed",
    "sales_taxable": 9000000, "sales_exempt": 200000, "output_vat": 1170000,
    "purchases_taxable": 5000000, "input_vat": 650000, "carry_in": 0, "payable": 520000, "carry_out": 0,
    "filed_on": null, "paid_amount": 0, "paid_on": null, "receipt_no": null, "note": null
  }
}
```
`source` is `computed` (made from our records) or `manual` (an old return typed in).

| Method | Path | Notes |
|--------|------|-------|
| GET | `/vat/filings` | Newest period first. `per_page` (max 50) |
| GET | `/vat/filings/{id}` | |
| POST | `/vat/filings` | 201. See below |
| PATCH | `/vat/filings/{id}` | Only `filed_on`, `paid_amount`, `paid_on`, `receipt_no`, `note`. The numbers are frozen |

**POST computed**
```json
{ "period": "2083-07", "from": "2026-10-17", "to": "2026-11-16", "opening_carry": 0, "filed_on": null }
```
The server recalculates. Do not send amounts here (422 if you do).

**POST old return typed by hand**
```json
{
  "manual": true, "period": "2083-05", "from": "2026-08-17", "to": "2026-09-16",
  "sales_taxable": 1000000, "sales_exempt": 0, "output_vat": 130000, "purchases_taxable": 600000,
  "input_vat": 78000, "carry_in": 0, "payable": 52000, "carry_out": 0,
  "filed_on": "2026-09-30", "paid_amount": 52000, "receipt_no": "R-123"
}
```
All eight amounts are required when `manual` is true.
Rules: `period` is a label you choose (max 20, unique, for example `2083-07`). A period cannot overlap one already saved (422, `errors.from`). Save periods in date order, because each one reads the carry of the one before it.

---

## 7. Endpoint list (51 routes)

"All" means owner and staff. "Owner" means staff get 403.

| Method | Path | Who |
|--------|------|-----|
| POST | `/login` | no token |
| POST | `/logout`, `/logout-all`, `/me/password` | all |
| GET | `/me`, `/business` | all |
| GET | `/categories`, `/categories/{id}`, `/items`, `/items/suggest`, `/items/{id}` | all |
| GET, POST, PUT/PATCH, DELETE | `/customers`, `/customers/{id}` | all |
| GET | `/customers/{id}/ledger` | all |
| GET, POST | `/sales` | all |
| GET | `/sales/{id}` | all |
| POST | `/payments` | all (staff: sales only) |
| PATCH | `/business` | owner |
| GET, POST, PATCH, DELETE | `/users`, `/users/{id}` (no single GET) | owner |
| POST, PUT/PATCH, DELETE | `/categories`, `/items` and their `{id}` | owner |
| POST | `/items/{id}/restore` | owner |
| POST | `/stock-adjustments` | owner |
| GET, POST, PUT/PATCH, DELETE | `/suppliers`, `/suppliers/{id}` | owner |
| GET | `/suppliers/{id}/ledger` | owner |
| GET, POST | `/purchases`, `/expenses` | owner |
| GET | `/purchases/{id}`, `/reports/summary` | owner |
| GET | `/vat/preview`, `/vat/filings`, `/vat/filings/{id}` | owner |
| POST | `/vat/filings` | owner |
| PATCH | `/vat/filings/{id}` | owner |

## 8. Per-client notes

**Phone app (Flutter).** Save the token in secure storage (`flutter_secure_storage`: Keychain on iOS, Keystore on Android). Never in plain preferences. On any 401, delete it and show login. No CORS needed.

**Mac app (Tauri, Rust).** Keep the token on the Rust side in the macOS Keychain, not in the web view. The screen asks Rust to call the API. No CORS needed.

**Website.** Browsers need CORS. The owner adds the site's address to `PASAL_CORS_ORIGINS` in `backend/.env` (comma separated, for example `https://shop.example.com`). Empty means no website is allowed. The token is a Bearer token, so keep it in memory and ask for login again after a refresh, until we decide on a safer cookie design.

**All clients.**
- Read `role` from `/me` and show only the screens that role can use. Staff should not see purchases, expenses, reports, VAT, suppliers or settings.
- Never send a business id. The server takes it from the token.
- Never log the token or the password.
- Use HTTPS in production. Plain HTTP is for local testing only.
- Money is paisa integers. Do the `/ 100` only for display.
- Do not retry a POST after a network timeout without first checking with a GET. A repeated sale would be saved twice, because there is no idempotency key yet.
- Show 422 messages as they come.

## 9. Not built yet (do not call)
- Editing or cancelling sales, purchases, expenses. Sale returns.
- Stock history per item. Payments list.
- Public sign-up, billing and plans. A new business is made by the platform owner on the command line.
- Platform-admin API (list or suspend businesses).
- Nepali date conversion on the server.
- Idempotency keys (safe retries).

## 10. Change log
- v1: first version.
- v1.2: item names are reused. `GET /items/suggest`, no duplicate names inside a business, optional SKU, `POST /items/{id}/restore`, `GET /items?trashed=only`, deleting an item with stock is refused. Name errors can carry `existing_item`.
- v1.1: many businesses (each isolated), roles owner and staff, `/users`, `/business`, `/logout-all`, `/me/password`. Login and `/me` now return `role` and `business`. Staff see `cost_price: null`. VAT rate is per business. Login limit is per email and address.
