# PASAL: start here

Home shop system for our own business. Two parts on one database: **Inventory** and **Finance**.
Built from zero in this folder. Nothing is copied from the old `pasal` Flutter app.

## Settled

- Many businesses can use the system, each fully separate (one database, `business_id` on every data table).
- Invite-only: no public sign-up. A new business is created with `php artisan pasal:add-business`.
- Two roles per business: `owner` (everything) and `staff` (counter work only, cannot see buying prices).
- Each business has many suppliers (dealers) and many customers.
- Money is in NPR, stored as whole paisa (integer), never decimals.
- Customer credit (udhar): a sale can be paid, part paid, or unpaid. Payments are recorded later.

## Stack

| Part | Choice |
|------|--------|
| Backend | Laravel 13, PHP 8.5, Sanctum tokens |
| Database | PostgreSQL 18, database name `pasal` |
| Phone app | Flutter 3.47 (`mobile/`) |
| Website | Svelte 5 and Vite (`web/`) |

## Folders

```
pasal-fullstack/
  backend/   Laravel API
  web/       Svelte website
  mobile/    Flutter phone app
  docs/      these notes
```

## Reading order

0. `api-reference.md` (every endpoint, for front-end developers)
0. `security.md` (what is protected, what is still open)
0. `06-clients.md` (website, phone app, Mac app decision)
1. `05-full-plan.md` (scope and order of work)
2. `01-architecture.md`
3. `02-database.md`
4. `03-api.md`
