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

### Safe retries (Idempotency-Key)
Send a header `Idempotency-Key: <random text, 8 to 100 letters, digits or . _ : ->` on any POST that saves something (a sale, a payment, a return). A UUID made on the phone for each action is perfect. If the same request arrives again with the same key, the server does not save it a second time. It sends back the first answer, with the header `Idempotent-Replayed: true`.

- Make the key when the user taps the button, and reuse it for every retry of that tap. Make a new key for the next action.
- The same key with a different body gives 422 on `idempotency_key`.
- A request that fails (422, 500) does not use up the key, so the retry can use it again.
- Keys are kept for one day and belong to one business.
- The header is optional. Without it, every POST is a new action.

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

### POST `/forgot-password`  (no token needed)
Body `{ "email": "owner@example.com" }`. Always answers 200 with the same message, whether the email has an account or not, so nobody can use it to find out who has one. If the account exists, an email goes out with a link. The link opens `PASAL_PASSWORD_RESET_URL` (default `pasal://reset-password`) with `?token=...&email=...` added. Limit: 5 tries a minute per email and address together.

### POST `/reset-password`  (no token needed)
Body `{ "email": "...", "token": "...", "password": "..." }`. The token comes from the link and works once, for 60 minutes. The password follows the same rules as a new password (10 to 100 characters). On success every phone is signed out, so the person logs in again with the new password. A wrong, used or expired token gives 422 with `errors.token`.

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

### Stock count  POST `/stock-counts`  (owner)
Walk the shelves, type what you counted, and the system catches up.
```json
{ "note": "Month end", "items": [ { "item_id": 7, "counted": 12 }, { "item_id": 8, "counted": 0 } ] }
```
1 to 500 items, each item once. `counted` is 0 or more. Response 201:
```json
{ "data": [ { "item_id": 7, "item_name": "Rice 5kg", "system": 15, "counted": 12, "difference": -3 } ], "items_changed": 1 }
```
It is all or nothing. A history row (`reason: "count"`) is written only for items where the count differs.

### Stock history  GET `/items/{id}/stock-movements`  (owner, not wrapped)
Every change of one item, newest first, 30 per page (`per_page` max 100).
```json
{
  "item": { "id": 7, "name": "Rice 5kg", "quantity": 12 },
  "data": [ { "id": 41, "change": -3, "reason": "count", "ref_type": null, "ref_id": null, "note": "Month end", "by": "Sita", "at": "..." } ],
  "links": { "next": null, "prev": null },
  "meta": { "current_page": 1, "per_page": 30, "total": 1 }
}
```
`reason` is `sale`, `sale_return`, `sale_cancel`, `purchase`, `adjust` or `count`. `ref_type` is `sale` or `purchase` when the change came from a bill, and `ref_id` is that bill.

### Suppliers (dealers)  `/suppliers`
Fields: `id`, `name` (required, max 150), `phone`, `address`, `pan` (max 20), `note` (max 1000). Same five methods as categories (list, create, show, update, delete). List sorted by name, 50 per page.

---

## 5. Finance

### Customers  `/customers`
Fields: `id`, `name` (required), `phone`, `address`, `pan`, `credit_limit`. Same five methods as categories.
A customer is needed for credit sales (udhar). Walk-in cash sales need no customer.

`credit_limit` is the most this customer may owe at one time. `null` means no limit. `0` means cash only. Only the owner can set it (staff get 422). A credit sale that would push what they owe past the limit is refused with 422 on `customer_id`. The owner can still sell past the limit by sending `"ignore_credit_limit": true`.

### Sales  `/sales`
Sale response:
```json
{
  "data": {
    "id": 31, "bill_no": "S-0031", "customer_id": 4,
    "customer": { "id": 4, "name": "Hari", "phone": "9800000000", "address": null, "pan": null },
    "subtotal": 11300, "discount": 0, "total": 11300, "returned_total": 0,
    "paid": 5000, "balance": 6300, "cancelled_at": null,
    "vat_rate": 13.0, "taxable_amount": 10000, "vat_amount": 1300, "exempt_amount": 0,
    "sold_at": "2026-10-26T07:26:03+00:00", "note": null,
    "items": [ { "id": 52, "item_id": 7, "item_name": "Rice 5kg", "quantity": 1, "unit_price": 11300, "discount": 0, "line_total": 11300, "returned_quantity": 0 } ],
    "payments": [ { "id": 9, "direction": "in", "sale_id": 31, "purchase_id": null, "amount": 5000, "method": "cash", "paid_at": "..." } ],
    "returns": []
  }
}
```
`items`, `payments` and `returns` appear in `GET /sales/{id}`. The create response has `items`. The list has `customer` but none of these.

How the numbers work: `subtotal` is the lines added up. `discount` is the bill discount. `total = subtotal - discount` and is what the customer pays, VAT included. `vat_amount` is the VAT inside `total` (only for items with `vat_applies = true`), worked out after the discount. `taxable_amount` is the price of those items without VAT. `exempt_amount` is the no-VAT items. `total = taxable_amount + vat_amount + exempt_amount`. `vat_rate` is saved on the sale, so changing the rate later does not change old sales.

The bill discount is shared over the lines by price, and each line shows its share in `discount`. `line_total` is after that share. The shares always add up to the discount exactly.

`returned_total` is the value of goods sent back so far. `balance = total - returned_total - paid`. `cancelled_at` is set when every item has been sent back.

| Method | Path | Notes |
|--------|------|-------|
| GET | `/sales` | Newest first. Query: `unpaid=1` (still owes), `customer_id`, `per_page` (max 50), `page` |
| GET | `/sales/{id}` | With lines, customer and payments |
| POST | `/sales` | 201. See below |

There is no edit and no delete for sales. Use a return or a cancel (below).

**POST `/sales`** request
```json
{
  "customer_id": 4,
  "paid": 5000,
  "discount": 0,
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
| `discount` | optional, default 0. Taken off the whole bill. Cannot be more than the subtotal (422, `errors.discount`). Staff can give up to 10% of the subtotal (`PASAL_STAFF_MAX_DISCOUNT_PERCENT`). More needs the owner |
| `paid` | optional, default 0. Cannot be more than the total (after the discount) |
| `customer_id` | **required when `paid` is less than the total** (credit sale). Otherwise optional |
| `ignore_credit_limit` | optional, owner only. Sell on udhar past the customer's limit |
| `method`, `bill_no`, `sold_at`, `note` | optional. Without `bill_no` the server numbers the bill `S-0001`, `S-0002` ... (one counter per business). A number you type is kept as it is |

It is all or nothing. If one line has not enough stock, nothing is saved (422, `errors.quantity`). On success stock goes down, and if `paid > 0` a payment is recorded.

#### Sale return  POST `/sales/{id}/returns`  (owner)
Goods come back. Send the lines (from `items[].id` of the sale) and how many.
```json
{ "items": [ { "sale_item_id": 52, "quantity": 1 } ], "restock": true, "note": "wrong size" }
```
`restock` defaults to true. Send `false` for broken goods, which then do not go back on the shelf. You cannot return more than was sold, and the same line twice in one request is added together first.

Response 201:
```json
{ "data": { "id": 3, "sale_id": 31, "kind": "return", "returned_at": "...", "total": 11300, "vat_amount": 1300, "refunded": 5000, "restocked": true, "note": "wrong size", "items": [ { "sale_item_id": 52, "quantity": 1, "amount": 11300 } ] }, "sale_balance": 0, "sale_cancelled": false }
```
What happens: the customer's debt goes down first. If they had already paid more than the new total, the extra is paid back in cash. That shows in `refunded`, and as a payment with `direction: "refund"`. The sale row itself is not rewritten. A return is its own record and counts in reports and VAT on the day it happened, so a VAT month that is already filed never changes.

#### Sale cancel  POST `/sales/{id}/cancel`  (owner)
Returns every item that is still with the customer in one step. Body is optional: `{ "restock": true, "note": "customer left" }`. Same response as a return, with `kind: "cancel"` and `sale_cancelled: true`. A cancelled sale gives 422 on a second cancel, and takes no more payments.

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
`direction` is `in` for a sale and `out` for a purchase. It is set by the server. Staff may only send `sale_id` or `customer_id`. A staff user who sends `purchase_id` or `supplier_id` gets 403.

**Pay by customer or supplier.** Instead of one bill, send `customer_id` (money in) or `supplier_id` (money out). The amount pays their oldest unpaid bills first, and one payment row is made for each bill it touches.
```json
{ "customer_id": 4, "amount": 1500, "method": "esewa" }
```
Response 201: `{ "data": [ { ...payment }, { ...payment } ], "owes_left": 4500 }`. An amount bigger than everything they owe gives 422 on `amount` and saves nothing. Bills that were returned or cancelled are counted after the return.

`direction: "refund"` is money paid back to a customer after a return. The server makes it. You cannot send it.

### Payments list  GET `/payments`  (owner)
Newest first, 30 per page (`per_page` max 100). Each row has the fields above plus `party`, the customer or supplier name.
Query: `direction` (`in`, `out`, `refund`), `method`, `from`, `to`, `sale_id`, `purchase_id`, `customer_id`, `supplier_id`.

### Cash book  GET `/cash-book?from=2026-10-01&to=2026-10-31`  (owner, not wrapped)
Every rupee in and out, in the order it happened, with a running balance. `from` and `to` are required.
```json
{
  "from": "2026-10-01", "to": "2026-10-31",
  "opening_balance": 5000, "money_in": 1500, "money_out": 3400, "closing_balance": 3100,
  "data": [ { "kind": "payment_in", "id": 9, "at": "...", "amount": 1500, "method": "esewa", "label": "Hari", "balance": 6500 } ],
  "meta": { "current_page": 1, "per_page": 50, "total": 4 }
}
```
`kind` is `payment_in`, `payment_out`, `refund` or `expense`. `amount` is negative when money goes out. Money in is customer payments. Money out is refunds, supplier payments and expenses (counted as cash). `opening_balance` is everything before `from`, and `balance` on each row continues from it, also on page 2. Paging: `page`, `per_page` (max 100).

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
  "customer": { "id": 4, "name": "Hari", "phone": null, "address": null, "pan": null, "credit_limit": 50000 },
  "total_sales": 20000, "total_paid": 8000, "owes": 12000, "credit_limit": 50000,
  "sales": [ { "id": 31, "sold_at": "2026-10-26T07:26:03.000000Z", "total": 11300, "returned_total": 0, "paid": 5000, "balance": 6300, "cancelled_at": null } ]
}
```
`total_sales` and `owes` are after returns, so a cancelled sale counts as nothing.
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
Returns count on the day they happened. They lower `sales_total` and `vat_collected`. The cost of goods that went back on the shelf is taken out of `cost_of_goods`. Goods marked `restock: false` keep their cost, because that is a real loss.
`stock_value` (quantity x cost price), `owed_to_us` and `we_owe` are **as of today**, not limited to the date range.

---

## 6. IRD VAT section

All amounts are paisa. Dates are AD. The API does **not** convert Nepali months. The app lets the user pick the Nepali month, converts its first and last day to AD, and sends `from` and `to`.

### How the numbers are made
```
output_vat = VAT on sales in the period          (sum of sales.vat_amount, less the VAT of returns made in the period)
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

## 7. Endpoint list (59 routes)

"All" means owner and staff. "Owner" means staff get 403.

| Method | Path | Who |
|--------|------|-----|
| POST | `/login`, `/forgot-password`, `/reset-password` | no token |
| POST | `/logout`, `/logout-all`, `/me/password` | all |
| GET | `/me`, `/business` | all |
| GET | `/categories`, `/categories/{id}`, `/items`, `/items/suggest`, `/items/{id}` | all |
| GET, POST, PUT/PATCH, DELETE | `/customers`, `/customers/{id}` | all |
| GET | `/customers/{id}/ledger` | all |
| GET, POST | `/sales` | all |
| GET | `/sales/{id}` | all |
| POST | `/payments` | all (staff: sale_id or customer_id only) |
| PATCH | `/business` | owner |
| GET, POST, PATCH, DELETE | `/users`, `/users/{id}` (no single GET) | owner |
| POST, PUT/PATCH, DELETE | `/categories`, `/items` and their `{id}` | owner |
| POST | `/items/{id}/restore` | owner |
| POST | `/stock-adjustments`, `/stock-counts` | owner |
| GET | `/items/{id}/stock-movements`, `/payments`, `/cash-book` | owner |
| POST | `/sales/{id}/returns`, `/sales/{id}/cancel` | owner |
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
- Send an `Idempotency-Key` header on every POST that saves money or stock. Then a retry after a network timeout is safe. Without a key, check with a GET before you retry.
- Show 422 messages as they come.

## 9. Not built yet (do not call)
- Editing or cancelling purchases and expenses. Editing a sale (use a return or a cancel).
- Purchase returns, expiry dates, a photo of the paper purchase bill.
- Public sign-up, billing and plans. A new business is made by the platform owner on the command line.
- Platform-admin API (list or suspend businesses).
- Nepali date conversion on the server.

## 9.1 Added in v1.4

**Days in the new reports and filters are shop days (Nepal, UTC+5:45).** `from` and `to` are Nepal calendar dates, both included. (The older `/reports/summary`, `/payments`, `/cash-book` and the VAT dates still cut the day at UTC. This is on the open list.)

### Customers and suppliers now show the money
- `GET /customers` and `GET /customers/{id}`: each customer also has `owes` (paisa still to collect, after returns), `last_sale_at` and `oldest_unpaid_at` (or `null`). Query: `search` (name or phone), `owes=1`, `paid_up=1`, `over_limit=1`, `sort=name|owed|oldest`, `per_page` (max 50). The list answer also has `summary: { owed_total, owing_customers }` for the whole business.
- `GET /suppliers` and `GET /suppliers/{id}`: each supplier also has `we_owe` and `last_purchase_at`. Query: `search`, `owed=1`, `per_page`. The list answer has `summary: { owed_total }`.
- `GET /customers/{id}/ledger` and `GET /suppliers/{id}/ledger` now also return `payments` (the same shape as in a sale, newest first, 200 at most), and each sale or purchase row has `bill_no`.

### Sales and purchases filters
- `GET /sales` adds `from`, `to` (shop days) and `search` (bill number or customer name). Each sale has `sold_by` (the person's name).
- `GET /purchases` adds `from`, `to` and `search` (bill number or supplier name).

### Categories and item photos
- Category: `icon` (a Material Symbols name such as `egg`, letters, digits and `_`, max 40) and `color` (`#rrggbb`), both optional.
- Item: `photo_url` (or `null`).
- `POST /items/{id}/photo` (owner): multipart form with the file in `photo`. JPG, PNG or WebP, at most 2 MB. Replaces the old photo. Returns the item. `DELETE /items/{id}/photo` removes it. The file name from the client is never used.

### Report details  (owner, not wrapped)
- `GET /reports/daily?from&to` gives `days: [{ date, bills, sales }]` (every day in the range, returns taken off on the day they happened), `hours: [{ hour, bills, sales }]` (0 to 23) and `total`, `bills`. At most 400 days.
- `GET /reports/items?from&to&limit` gives `top` (best sellers by quantity after returns: `item_id, name, unit, quantity, revenue`) and `slow` (in stock but sold least: `item_id, name, unit, in_stock, sold, stock_value`).
- `GET /reports/credit-age` gives `buckets` (`d0_30`, `d31_60`, `d61_90`, `d90_plus`, each with `bills` and `amount`), `total`, and `customers` (`customer_id, name, phone, owes, oldest_days, bucket`, oldest first).
- `GET /reports/staff?from&to` gives `data: [{ user_id, name, bills, sales, discount }]`, highest first.

### Notifications and activity
- `GET /notifications` (everyone) gives `data: [{ type, title, body, at, ... }]`. `type` is `low_stock`, `credit_overdue` (not paid for over 30 days), `vat_unfiled` (owner, a saved period that is not filed) or `staff_added` (owner, joined in the last 7 days). Worked out when asked, no stored read mark. VAT due dates by Nepali month are worked out in the apps.
- `GET /activity` (owner) gives who did what: `data: [{ kind, ref_id, at, by, label, amount }]`, newest first, 30 per page (`per_page` max 100, `page`, `user_id` filter), with `meta.total`. `kind` is `sale`, `return`, `cancel`, `purchase`, `payment_in`, `payment_out`, `refund`, `expense`, `stock_adjust`, `stock_count` or `vat_filing`.

## 10. Change log
- v1.4: sales get an automatic bill number (`S-0001`), customer and supplier balances in the lists, search and filters, ledger payments, sales and purchase date filters, `sold_by`, category icon and colour, item photos, report details (daily, items, credit age, staff), notifications, activity log.
- v1.3: password reset (`/forgot-password`, `/reset-password`), bill discount on sales, sale returns and cancel, pay by customer or supplier (oldest bills first), customer credit limit, stock count and stock history, payments list, cash book, `Idempotency-Key` for safe retries. Sales now show `subtotal`, `discount`, `returned_total`, `cancelled_at`, and `balance` counts returns. Payments can have `direction: "refund"`.
- v1: first version.
- v1.2: item names are reused. `GET /items/suggest`, no duplicate names inside a business, optional SKU, `POST /items/{id}/restore`, `GET /items?trashed=only`, deleting an item with stock is refused. Name errors can carry `existing_item`.
- v1.1: many businesses (each isolated), roles owner and staff, `/users`, `/business`, `/logout-all`, `/me/password`. Login and `/me` now return `role` and `business`. Staff see `cost_price: null`. VAT rate is per business. Login limit is per email and address.
