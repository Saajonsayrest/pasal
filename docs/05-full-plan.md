# PASAL full plan

## Scope

**Inventory:** categories, items, suppliers, stock in and out, manual adjustment, low-stock alert.
**Finance:** sales, purchases, customer credit (udhar), supplier dues, payments, expenses, profit report.

## Order of work

1. Backend setup: `laravel new backend` (starter kit: none, API only), PostgreSQL, `install:api` for Sanctum.
2. Auth: login, logout, family users by seeder. Test.
3. Inventory: migrations, models, CRUD, stock movements. Tests.
4. Finance: sales and purchases as transactions, payments, expenses, ledgers. Tests.
5. Reports endpoint. Tests.
6. OpenAPI file `docs/openapi.json` (done, made by `php artisan pasal:openapi`).
7. Flutter app in `mobile/`: login, items, new sale, customer credit, reports.
8. Git: small commits, one feature per branch, tests must pass.

## Many businesses and scaling

- **Model:** one database, `business_id` on every data table, enforced by a global scope and by validation that checks only the caller's own business. This is the right fit for tens to a few thousand small businesses.
- **API is stateless** (Bearer tokens, no server sessions), so more API servers can sit behind a load balancer with no change.
- **Indexes** all start with `business_id`. Lists are paged with a hard cap of 50. Ledgers are capped at 200 rows.
- **Writes that move money** are short database transactions with row locks, so they stay correct under many users at once.
- **Housekeeping:** expired tokens are removed daily (`sanctum:prune-expired`).
- **Next steps when load grows:** PostgreSQL row-level security as a second wall, a read replica for reports, a queue for slow work, cache for the report numbers, and table partitioning of `stock_movements` and `sales` by month. None is needed until there are many busy businesses.
- **When one business gets very large or demands its own data:** move that business to its own database. The `business_id` design makes the move a copy of its rows.
- **Not built:** sign-up, billing, plans, a platform-admin panel.

## Security basics

- Tokens expire. Passwords hashed. Login rate limit.
- Every route needs a token except `/login`.
- Eloquent bindings only, no raw SQL with user input.
- `APP_DEBUG=false` outside local. `.env` never committed.
- Family logins are created by us, no public sign-up route.

## Checked later (not yet verified)

- Exact Laravel 13 install result and Sanctum setup.
- Flutter version and package versions (check pub.dev the day we start the app).
- Where it runs for real (home computer or a server). Open question.
