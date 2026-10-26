# Database (PostgreSQL, database `pasal`)

All money columns are `bigint` paisa. All tables have `id`, `created_at`, `updated_at`.

## Businesses (many can use the app)

`businesses`: name, pan, phone, address, vat_rate (percent, default 13).
`users` also have `business_id` and `role` (`owner` or `staff`). One email belongs to one business.
Every data table below (categories, items, suppliers, customers, stock_movements, sales, sale_items, purchases, purchase_items, payments, expenses, vat_filings) has a `business_id` column that points to `businesses` and is never empty.
Rules that used to be unique across the system are now unique inside one business: `items.sku` (optional, many items may have none), `categories.name`, `vat_filings.period`.
An item name is also unique inside one business, ignoring capital letters, among items that are not deleted. A partial index `items_business_name_unique` on `(business_id, lower(name)) WHERE deleted_at IS NULL` enforces it in the database.
Every index on a list starts with `business_id`, so each business's queries stay fast as the total grows.

The VAT tables and columns (`vat_filings`, `sales.vat_amount`, `purchases.vat_amount`, `items.vat_applies`, `pan` on customers and suppliers, bill numbers) are described in `api-reference.md` section 6.

## Inventory

| Table | Main columns |
|-------|--------------|
| `users` | name, email, password |
| `categories` | name |
| `items` | category_id, name, sku (unique), unit, cost_price, sell_price, quantity, low_stock_at |
| `suppliers` | name, phone, address, note |
| `stock_movements` | item_id, change (+/-), reason (`purchase`, `sale`, `adjust`, `return`), ref_type, ref_id, user_id |

## Finance

| Table | Main columns |
|-------|--------------|
| `customers` | name, phone, address |
| `sales` | customer_id (null = walk-in), total, paid, sold_at, user_id |
| `sale_items` | sale_id, item_id, quantity, unit_price |
| `purchases` | supplier_id, total, paid, bought_at, user_id |
| `purchase_items` | purchase_id, item_id, quantity, unit_cost |
| `payments` | direction (`in` from customer, `out` to supplier), customer_id or supplier_id, sale_id or purchase_id (nullable), amount, paid_at, method |
| `expenses` | title, category, amount, spent_at, user_id |

## Rules

- Customer owes = sum of `sales.total - sales.paid` for that customer.
- Supplier owed = sum of `purchases.total - purchases.paid` for that supplier.
- A payment raises `paid` on its sale or purchase in the same transaction.
- `paid` can never exceed `total` (check constraint).
- Items are soft-deleted so old sales keep their names.
