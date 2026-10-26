# PASAL

PASAL is a stock and money system for small shops in Nepal. It tracks what is on the shelf, what was sold, who still owes the shop money, and what the VAT return should say at the end of the month.

I built it for our own family business first. Then I made it work for many shops at once, each one fully separate from the others.

**Where it stands today:** the backend API is finished and tested (51 routes, 84 automatic tests). The Flutter phone app is next. The website and the Mac app come after that. Nothing here is deployed yet, and I say so on purpose. The [security notes](docs/security.md) list what is still open.

## What it does

- **Inventory.** Categories, items, suppliers, stock in and out, manual stock corrections, low-stock alerts.
- **Sales and purchases.** A sale can be paid in full, part paid, or left unpaid. Payments come in later and are matched to the sale.
- **Udhar (customer credit).** The system keeps a running balance per customer and per supplier.
- **Expenses and reports.** A profit summary for any date range.
- **IRD VAT.** A monthly preview with the numbers the return asks for, and saved filings per period.
- **Many shops, one system.** Invite-only. A shop has an `owner` and `staff`. Staff can run the counter but cannot see buying prices.

## How the pieces fit

```mermaid
flowchart LR
    subgraph Clients
        P[Flutter phone app<br/>next]
        W[Svelte website<br/>planned]
        M[Tauri Mac app<br/>planned]
    end
    P -->|Bearer token| API
    W -->|Bearer token| API
    M -->|Bearer token| API
    API[Laravel 13 API<br/>/api/v1] --> DB[(PostgreSQL 18)]
    API --> INV[Inventory]
    API --> FIN[Finance]
```

The API is the only place with business rules. The clients stay thin and only call the endpoints in the [API reference](docs/api-reference.md).

## One sale, start to finish

A sale touches three tables. They are written inside one database transaction, so a sale is either saved completely or not at all.

```mermaid
sequenceDiagram
    participant App as Phone app
    participant API as Laravel API
    participant DB as PostgreSQL
    App->>API: POST /sales (items, paid amount)
    API->>API: Check token, role and input
    API->>DB: BEGIN, lock the item rows
    API->>DB: insert sales and sale_items
    API->>DB: insert stock_movements (stock goes down)
    API->>DB: insert payments (only if money was paid now)
    alt anything fails
        DB-->>API: ROLLBACK
        API-->>App: 422 with a clear message
    else all good
        DB-->>API: COMMIT
        API-->>App: 201 with the saved sale
    end
```

Stock is never edited by hand. It is the sum of `stock_movements`, with a cached `quantity` on each item that changes in the same transaction.

## Data model

Every data table carries a `business_id`. The diagram shows the main tables only.

```mermaid
erDiagram
    BUSINESSES ||--o{ USERS : has
    BUSINESSES ||--o{ ITEMS : owns
    BUSINESSES ||--o{ CUSTOMERS : owns
    BUSINESSES ||--o{ SUPPLIERS : owns
    CATEGORIES ||--o{ ITEMS : groups
    ITEMS ||--o{ STOCK_MOVEMENTS : changes
    CUSTOMERS ||--o{ SALES : buys
    SALES ||--|{ SALE_ITEMS : contains
    ITEMS ||--o{ SALE_ITEMS : sold_as
    SUPPLIERS ||--o{ PURCHASES : supplies
    PURCHASES ||--|{ PURCHASE_ITEMS : contains
    ITEMS ||--o{ PURCHASE_ITEMS : bought_as
    SALES ||--o{ PAYMENTS : settled_by
    PURCHASES ||--o{ PAYMENTS : settled_by
    BUSINESSES ||--o{ EXPENSES : records
    BUSINESSES ||--o{ VAT_FILINGS : files
```

A few rules the database enforces, not just the code:

- Money is stored as whole paisa in `bigint`. Rs 113.00 is `11300`. No decimals, so no rounding drift.
- `paid` can never be higher than `total` (a CHECK constraint).
- Item names are unique inside one shop, ignoring capital letters, through a partial index on `(business_id, lower(name))`.
- Items are soft-deleted, so old sales keep their names.

More detail is in [docs/02-database.md](docs/02-database.md).

## Keeping shops apart

This is the biggest risk in a shared system, so it gets the most care.

```mermaid
flowchart TD
    R[Request with token] --> A{Token valid?}
    A -- no --> X1[401]
    A -- yes --> B[Business comes from the token<br/>never from the request body]
    B --> S[Global scope adds<br/>WHERE business_id = yours]
    S --> Q{Record found?}
    Q -- other shop's record --> X2[404, as if it did not exist]
    Q -- yours --> OK[Return it]
```

Validation rules such as `exists` and `unique` skip model scopes, so they are only built through one helper that adds the business filter. A test covers each case. The full table of risks and the test that proves each one is in [docs/security.md](docs/security.md).

Row-level security in PostgreSQL is the planned second wall. It is on the open list, and I want it done before any real customer joins.

## Roles

| | Owner | Staff |
|---|:---:|:---:|
| Sell, take payments, see customers | yes | yes |
| See items | yes | yes, without buying price |
| Purchases, suppliers, stock corrections | yes | no |
| Expenses, reports, VAT | yes | no |
| Users and shop settings | yes | no |

The server enforces this. A hidden button in the app is only a convenience.

## Tech

| Part | Choice |
|---|---|
| API | Laravel 13, PHP 8.5, Sanctum tokens |
| Database | PostgreSQL 18 |
| Phone app | Flutter |
| Website | Svelte and Vite (planned) |
| Mac app | Tauri around the same Svelte screens (planned) |

Two UI projects (Flutter and Svelte) is the smallest set that covers phone, web and Mac. The reasoning is in [docs/06-clients.md](docs/06-clients.md).

## Run it locally

You need PHP 8.5 with Composer (I use Laravel Herd) and PostgreSQL 18.

```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate
```

Create two empty databases, `pasal` and `pasal_test`. Then open `.env` and set `DB_DATABASE=pasal` along with your own `DB_USERNAME` and `DB_PASSWORD`.

```bash
php artisan migrate
php artisan pasal:add-business   # creates a shop and its owner login
php artisan pasal:add-user       # adds staff to a shop
php artisan serve                # http://localhost:8000/api/v1
```

Run the tests:

```bash
php artisan test
```

Try a login:

```bash
curl -X POST http://localhost:8000/api/v1/login \
  -H "Accept: application/json" -H "Content-Type: application/json" \
  -d '{"email":"you@example.com","password":"your-password"}'
```

The response holds a token. Send it as `Authorization: Bearer <token>` on every other call.

## Repository layout

```
pasal-fullstack/
  backend/   Laravel API
  docs/      design notes and the API reference
  mobile/    Flutter app (not started)
```

Inside `backend/`, controllers stay thin. The transactions live in `app/Services`, validation in `app/Http/Requests`, and the JSON shape in `app/Http/Resources`.

## Docs

- [API reference](docs/api-reference.md): every endpoint, with request and response examples.
- [Security notes](docs/security.md): what is protected, what is tested, what is still open.
- [Architecture](docs/01-architecture.md) and [database](docs/02-database.md).
- [Full plan](docs/05-full-plan.md) and [clients](docs/06-clients.md).

## Roadmap

1. Flutter phone app: login, items, new sale, customer credit, VAT summary.
2. Row-level security, hosting with HTTPS, daily backups.
3. CI that runs the tests and `composer audit`.
4. Edit and cancel for purchases and expenses. (Sale returns, cancel and safe retries with an idempotency key are done.)
5. Svelte website, then the Tauri Mac app.
6. An OpenAPI file for the API.

One open question is the exact IRD monthly return layout. I still need to check the VAT rate and the box names against the live portal form.

## Security of this repository

No secrets belong here. `.env` files, keys, database dumps and private notes are blocked three ways: `.gitignore`, a local pre-commit and pre-push check, and a GitHub Action that scans the full history. After cloning, turn the local check on once:

```bash
git config core.hooksPath .githooks
```

Found a security problem? Please open a private security advisory on GitHub instead of a public issue.

## Licence

Copyright (C) 2026 Sajon Shrestha. Released under the GNU Affero General Public License v3.0. See [LICENSE](LICENSE).

In plain words: you can read, run and change this code. If you run a changed version as an online service, you must share your changes under the same licence. If you want to use PASAL in a way this licence does not allow, contact me and we can talk about a separate licence.
