# PASAL

[![CI](https://github.com/Saajonsayrest/pasal/actions/workflows/ci.yml/badge.svg)](https://github.com/Saajonsayrest/pasal/actions/workflows/ci.yml)
[![Secret scan](https://github.com/Saajonsayrest/pasal/actions/workflows/secret-scan.yml/badge.svg)](https://github.com/Saajonsayrest/pasal/actions/workflows/secret-scan.yml)
[![Licence: AGPL v3](https://img.shields.io/badge/licence-AGPL--3.0-blue.svg)](LICENSE)

PASAL is a stock and money system for small shops in Nepal. It tracks what is on the shelf, what was sold, who still owes the shop money (udhar), and what the monthly VAT return should say.

I built it for our own family shop first. Then I made it work for many shops at once, each one fully separate from the others. It has a Laravel API, a Flutter phone app, a Svelte website and a Mac desktop app. English and Nepali, with Nepali (Bikram Sambat) dates.

<p align="center">
  <img src="docs/screenshots/desktop-home.png" alt="PASAL home screen of the demo shop Laxmi Kitchen House" width="880">
</p>

**Where it stands today.** The API is finished and tested. The phone app, the website and the Mac app all have every screen from the plan. Everything runs and is tested on a local computer. Nothing is hosted yet, and I say so on purpose. The [limits and roadmap](#status-limits-and-roadmap) list what is still open.

## Contents

1. [Screenshots](#screenshots)
2. [What it does](#what-it-does)
3. [At a glance](#at-a-glance)
4. [How the pieces fit](#how-the-pieces-fit)
5. [How the main things work](#how-the-main-things-work) (login, a sale, returns, credit, buying, VAT, safe retries, password reset)
6. [Data model](#data-model)
7. [Keeping shops apart](#keeping-shops-apart)
8. [Roles and screens](#roles-and-screens)
9. [The API](#the-api)
10. [Tests and CI](#tests-and-ci)
11. [Security](#security)
12. [Run it locally](#run-it-locally)
13. [Repository layout](#repository-layout)
14. [Status, limits and roadmap](#status-limits-and-roadmap)
15. [Licence](#licence)

## Screenshots

Every picture is the demo shop **Laxmi Kitchen House**. All names, phone numbers and amounts are made up by `php artisan pasal:demo-shop`.

### Mac app and website

The Mac app is the website in a native window. The screens are the same.

| | |
|---|---|
| ![Log in](docs/screenshots/desktop-login.png)<br>**Log in.** English and Nepali. | ![Home](docs/screenshots/desktop-home.png)<br>**Home.** Today's sales, money to collect, money owed, low stock and VAT due. |
| ![Home charts](docs/screenshots/desktop-home-charts.png)<br>**Home, lower part.** Last 7 days. | ![New sale](docs/screenshots/desktop-sell-cart.png)<br>**New sale.** Tap items, then check out. |
| ![Sales](docs/screenshots/desktop-sales.png)<br>**Sales.** Search, filter by date, see what is unpaid. | ![Bill](docs/screenshots/desktop-bill.png)<br>**Bill.** VAT shown on the bill. |
| ![Items](docs/screenshots/desktop-items.png)<br>**Items.** Stock level and category colour. | ![Item details](docs/screenshots/desktop-item-details.png)<br>**Item details.** |
| ![Low stock](docs/screenshots/desktop-low-stock.png)<br>**Low stock.** What to buy next. | ![Customers](docs/screenshots/desktop-customers.png)<br>**Customers.** Who owes how much. |
| ![Customer ledger](docs/screenshots/desktop-customer-ledger.png)<br>**Customer account (udhar).** Bills, payments, running balance. | ![Purchases](docs/screenshots/desktop-purchases.png)<br>**Purchases.** Supplier bills and what is still unpaid. |
| ![All payments](docs/screenshots/desktop-payments.png)<br>**All payments.** Money in, money out and refunds, by method. | ![Reports](docs/screenshots/desktop-reports.png)<br>**Reports.** Profit, stock value, money to collect. |
| ![Sales chart](docs/screenshots/desktop-reports-sales.png)<br>**Sales by day and hour.** | ![Credit age](docs/screenshots/desktop-credit-age.png)<br>**Credit age.** How old the unpaid bills are. |
| ![VAT](docs/screenshots/desktop-vat.png)<br>**VAT.** The monthly figures for the IRD return. | ![Staff](docs/screenshots/desktop-staff.png)<br>**Staff.** The owner adds and removes logins. |
| ![Nepali home](docs/screenshots/desktop-home-nepali.png)<br>**Nepali.** Every screen has both languages. | ![Forgot password](docs/screenshots/forgot-password-mac.png)<br>**Forgot password.** |

### Phone app

<p>
  <img src="docs/screenshots/phone-login.png" alt="Phone login" width="13%">
  <img src="docs/screenshots/phone-home.png" alt="Phone home" width="13%">
  <img src="docs/screenshots/phone-sell.png" alt="Phone new sale" width="13%">
  <img src="docs/screenshots/phone-items.png" alt="Phone items" width="13%">
  <img src="docs/screenshots/phone-customers.png" alt="Phone customers" width="13%">
  <img src="docs/screenshots/phone-reports.png" alt="Phone reports" width="13%">
  <img src="docs/screenshots/phone-vat.png" alt="Phone VAT" width="13%">
</p>

From left to right: log in, home, new sale, items, customers, reports, VAT. Pictures are from an iPhone simulator.

## What it does

- **Inventory.** Categories, items with photos, suppliers, stock in and out, manual corrections, stock counts, low-stock alerts.
- **Sales and purchases.** A sale can be paid in full, part paid, or left unpaid. Payments come in later and are matched to the sale. Bills are numbered by the server (`S-0001`).
- **Udhar (customer credit).** A running balance per customer and per supplier, with a credit limit per customer, reminders and a statement.
- **Returns and cancels.** Goods come back, the debt goes down or cash is refunded, stock goes back on the shelf.
- **Expenses, cash book and reports.** Profit for any date range, sales by day and hour, best and slowest items, credit age, sales per staff member.
- **IRD VAT.** A monthly preview with the numbers the return asks for, and saved filings per period.
- **Many shops, one system.** Invite-only. A shop has an `owner` and `staff`. Staff can run the counter but cannot see buying prices or profit.
- **Made for Nepal.** English and Nepali, Bikram Sambat dates, rupees stored as whole paisa, days that end at midnight in Nepal (UTC+5:45).

## At a glance

| | |
|---|---|
| API | 67 operations, described in [docs/openapi.json](docs/openapi.json) |
| Screens | 65 on the website and Mac app. The phone app has the same screens and paths, plus two barcode scanning screens |
| Automatic tests | 168 backend, 341 website, 361 phone app, plus a Rust test for the Mac app |
| Checks on every push | Backend tests with PostgreSQL and `composer audit`, website checks and build, phone analyze and tests, Mac app build and test, full-history secret scan |
| Languages | English, Nepali |
| Money | whole paisa in `bigint`, no decimals |

## How the pieces fit

```mermaid
flowchart LR
    subgraph Clients
        P["Flutter phone app<br/>mobile/"]
        W["Svelte website<br/>web/"]
        M["Tauri Mac app<br/>web/src-tauri/"]
    end
    P -->|"Bearer token"| API
    W -->|"Bearer token"| API
    M -->|"Bearer token"| API
    API["Laravel 13 API<br/>/api/v1"] --> DB[("PostgreSQL")]
    API --> FS["Item photos<br/>storage disk"]
    API --> MAIL["Email<br/>password reset"]
```

The API is the only place with business rules. The clients stay thin and only call the endpoints in the [API reference](docs/api-reference.md).

### Inside the API

Every request goes through the same path. Controllers stay thin. The money logic lives in services and runs inside one database transaction.

```mermaid
flowchart LR
    R["Request"] --> A["Sanctum<br/>token check"]
    A --> T["Throttle<br/>120 a minute"]
    T --> I["Idempotent<br/>safe retry"]
    I --> O{"Owner only<br/>route?"}
    O -- "staff" --> F403["403"]
    O -- "owner or open route" --> V["Form request<br/>validation"]
    V --> C["Controller"]
    C --> S["Service<br/>one transaction"]
    S --> M["Model<br/>business scope"]
    M --> D[("PostgreSQL")]
    C --> RES["JSON resource"]
```

### Inside the clients

```mermaid
flowchart TB
    subgraph Svelte["Website and Mac app (Svelte 5)"]
        SR["routes/<br/>one file per screen"] --> SL["lib/resource<br/>load, reload, errors"]
        SL --> SA["lib/api<br/>fetch, token, safe-retry key"]
        SR --> SC["components/<br/>Shell, Sheet, pickers"]
        SS["lib/session<br/>login, restore, logout"] --> SA
        SS --> TS["lib/token-store<br/>Keychain in the Mac app<br/>sessionStorage in a browser"]
    end
    subgraph Flutter["Phone app (Flutter)"]
        FF["features/<br/>screens per area"] --> FP["Riverpod providers"]
        FP --> FR["repositories"]
        FR --> FN["core/network<br/>HTTP client"]
        FS2["core/session"] --> SEC["secure storage<br/>Keychain or Keystore"]
        FS2 --> FN
    end
    SA --> API["Laravel API"]
    FN --> API
```

### Where it runs

```mermaid
flowchart LR
    subgraph Local["Today: one computer"]
        L1["php artisan serve"] --- LDB[("Postgres.app")]
        L2["Vite dev server"] -->|"forwards /api"| L1
        L3["Mac app"] --> L1
        L4["Phone simulator"] --> L1
    end
    subgraph Planned["Planned hosting"]
        H1["Docker image<br/>backend/Dockerfile"] --> H2["HTTPS web service"]
        H2 --- H3[("Managed PostgreSQL<br/>daily backups")]
    end
```

## How the main things work

### Login and session

The token is kept differently on each client, because each platform has a different safe place.

```mermaid
sequenceDiagram
    participant U as User
    participant C as Client app
    participant S as Safe storage
    participant A as API
    U->>C: Email and password
    C->>A: POST /login
    alt right password
        A-->>C: 200 token and user
        C->>S: Save token
        Note over S: Phone: Keychain or Keystore<br/>Mac: Keychain<br/>Browser: sessionStorage
    else wrong email or password
        A-->>C: 422 same message for both
    else more than 5 tries a minute
        A-->>C: 429 Retry-After
    end
    Note over C,A: Later, every call carries Authorization Bearer token
    C->>A: GET /me
    alt token expired or revoked
        A-->>C: 401
        C->>S: Delete token
        C-->>U: Show the login screen
    end
```

### One sale, start to finish

A sale touches several tables. They are written inside one database transaction, so a sale is either saved completely or not at all.

```mermaid
sequenceDiagram
    participant App as Client
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

### Credit (udhar) and payments

A sale is never rewritten after it is saved. Its state comes from `paid`, `returned_total` and `cancelled_at`.

```mermaid
stateDiagram-v2
    [*] --> Unpaid: credit sale, nothing paid
    [*] --> PartPaid: some money paid now
    [*] --> Paid: paid in full
    Unpaid --> PartPaid: payment
    PartPaid --> PartPaid: payment
    Unpaid --> Paid: payment
    PartPaid --> Paid: last payment
    Paid --> Paid: return, extra paid back in cash
    Unpaid --> Cancelled: cancel
    PartPaid --> Cancelled: cancel
    Paid --> Cancelled: cancel
    Cancelled --> [*]
```

A payment can name one bill, or a customer. For a customer, the amount pays the oldest unpaid bills first and one payment row is made per bill it touches. Paying more than is owed gives an error and saves nothing.

### Returns and cancels

```mermaid
flowchart TD
    A["Owner picks a sale<br/>and the lines to return"] --> B{"More than was sold?"}
    B -- yes --> X["422, nothing saved"]
    B -- no --> C["Save a sale_returns record<br/>kind = return or cancel"]
    C --> D{"Restock the goods?"}
    D -- yes --> E["stock_movements: stock goes up"]
    D -- "no, broken" --> F["Stock unchanged"]
    E --> G["Customer debt goes down first"]
    F --> G
    G --> H{"Paid more than the new total?"}
    H -- yes --> I["Refund in cash<br/>payment with direction = refund"]
    H -- no --> J["Balance left on the sale"]
    I --> K["Reports and VAT count the return<br/>on the day it happened"]
    J --> K
```

A return is its own record. It counts in reports and VAT on the day it happened, so a month that was already filed is never changed.

### Buying and stock

```mermaid
flowchart LR
    SUP["Supplier bill<br/>typed from the paper bill"] --> P["POST /purchases"]
    P --> T["One transaction"]
    T --> PI["purchase_items"]
    T --> SM["stock_movements<br/>reason = purchase"]
    T --> PAY["payments out<br/>if paid now"]
    ADJ["Stock adjustment<br/>or stock count"] --> SM2["stock_movements<br/>reason = adjust"]
    SALE["Sale"] --> SM3["stock_movements<br/>reason = sale"]
    RET["Return"] --> SM4["stock_movements<br/>reason = return"]
    SM --> Q["items.quantity<br/>never below zero, checked by the database"]
    SM2 --> Q
    SM3 --> Q
    SM4 --> Q
    Q --> LOW{"quantity at or below<br/>low_stock_at?"}
    LOW -- yes --> N["Low stock list<br/>and notification"]
```

### VAT, month by month

```mermaid
flowchart TD
    S["Sales in the period<br/>taxable and exempt amounts, VAT"] --> OUT["Output VAT"]
    R["Returns in the period<br/>count on the day they happened"] --> OUT
    P["Purchase bills with VAT<br/>by supplier bill date"] --> IN["Input VAT"]
    PREV["Last saved filing<br/>carry_out"] --> CI["Carry in<br/>or the opening value typed once"]
    OUT --> NET["net = output - input - carry in"]
    IN --> NET
    CI --> NET
    NET --> Q{"net above zero?"}
    Q -- yes --> PAY["Payable = net<br/>due 25 days after the period ends"]
    Q -- no --> CARRY["Pay nothing<br/>carry the extra to the next period"]
    PAY --> SAVE["Save the filing<br/>one per business and period"]
    CARRY --> SAVE
```

The app lets the user pick a Nepali month. It turns the first and last day into English dates and sends them. The API never converts Nepali months. I still have to check the VAT rate and the box names against the live IRD portal form.

### Safe retries

A weak connection makes people tap twice. Every save sends an `Idempotency-Key`, so the same tap is saved only once.

```mermaid
sequenceDiagram
    participant App as Client
    participant API as API
    participant DB as PostgreSQL
    App->>API: POST /sales with key K
    API->>DB: Key K seen before?
    DB-->>API: No
    API->>DB: Save the sale and store the answer under K
    API-->>App: 201
    Note over App: Connection drops, the app never sees the 201
    App->>API: Same POST with the same key K
    API->>DB: Key K seen before?
    DB-->>API: Yes, same request
    API-->>App: Saved answer again, header Idempotent-Replayed
    App->>API: Key K with a different body
    API-->>App: 422
```

### Password reset

```mermaid
sequenceDiagram
    participant U as User
    participant C as Client
    participant A as API
    participant M as Email
    U->>C: Forgot password, email
    C->>A: POST /forgot-password
    A-->>C: Same answer for every email
    A->>M: Reset link with a one-time token, only if the account exists
    U->>C: Opens the link, types a new password
    C->>A: POST /reset-password
    alt token valid, under 60 minutes old
        A-->>C: 200, every old login is signed out
    else token wrong or expired
        A-->>C: 422
    end
```

### Nepal days

Times are stored in UTC. A shop thinks in Nepal days, which end at midnight in UTC+5:45. Every date range in the API goes through one helper, `App\Support\ShopDay`, so a sale made at 00:30 in Nepal is counted on the Nepal day it happened. The Nepali calendar (Bikram Sambat) is handled in the clients.

## Data model

Every data table carries a `business_id`. Money columns are `bigint` paisa, so Rs 113.00 is `11300`.

```mermaid
erDiagram
    BUSINESSES ||--o{ USERS : has
    BUSINESSES ||--o{ CATEGORIES : owns
    BUSINESSES ||--o{ ITEMS : owns
    BUSINESSES ||--o{ CUSTOMERS : owns
    BUSINESSES ||--o{ SUPPLIERS : owns
    BUSINESSES ||--o{ EXPENSES : records
    BUSINESSES ||--o{ VAT_FILINGS : files
    BUSINESSES ||--o{ IDEMPOTENCY_KEYS : remembers
    CATEGORIES ||--o{ ITEMS : groups
    ITEMS ||--o{ STOCK_MOVEMENTS : changes
    USERS ||--o{ SALES : sold_by
    CUSTOMERS |o--o{ SALES : buys
    SALES ||--|{ SALE_ITEMS : contains
    ITEMS ||--o{ SALE_ITEMS : sold_as
    SALES ||--o{ SALE_RETURNS : has
    SALE_RETURNS ||--|{ SALE_RETURN_ITEMS : contains
    SALE_ITEMS ||--o{ SALE_RETURN_ITEMS : returned_as
    SUPPLIERS ||--o{ PURCHASES : supplies
    PURCHASES ||--|{ PURCHASE_ITEMS : contains
    ITEMS ||--o{ PURCHASE_ITEMS : bought_as
    SALES |o--o{ PAYMENTS : settled_by
    PURCHASES |o--o{ PAYMENTS : settled_by

    BUSINESSES {
        bigint id PK
        varchar name
        varchar pan
        numeric vat_rate "percent, default 13"
    }
    USERS {
        bigint id PK
        bigint business_id FK
        varchar email UK
        varchar role "owner or staff"
    }
    ITEMS {
        bigint id PK
        bigint business_id FK
        bigint category_id FK
        varchar name "unique per business"
        bigint cost_price
        bigint sell_price
        int quantity "never below zero"
        int low_stock_at
        boolean vat_applies
        timestamp deleted_at "soft delete"
    }
    STOCK_MOVEMENTS {
        bigint id PK
        bigint item_id FK
        int change
        varchar reason "purchase, sale, adjust, return"
        bigint ref_id
    }
    SALES {
        bigint id PK
        bigint customer_id FK "null for a walk-in"
        varchar bill_no
        bigint subtotal
        bigint discount
        bigint total
        bigint paid "never above the net total"
        bigint returned_total
        bigint vat_amount
        timestamp cancelled_at
    }
    SALE_ITEMS {
        bigint id PK
        bigint sale_id FK
        bigint item_id FK
        int quantity
        bigint unit_price
        bigint unit_cost
        int returned_quantity
    }
    PURCHASES {
        bigint id PK
        bigint supplier_id FK
        varchar bill_no
        date bill_date
        bigint total
        bigint paid "never above total"
        bigint vat_amount
    }
    PAYMENTS {
        bigint id PK
        bigint sale_id FK
        bigint purchase_id FK
        varchar direction "in, out or refund"
        bigint amount "above zero"
        varchar method
    }
    VAT_FILINGS {
        bigint id PK
        varchar period "unique per business"
        bigint output_vat
        bigint input_vat
        bigint payable
        bigint carry_out
    }
    IDEMPOTENCY_KEYS {
        bigint id PK
        varchar request_key "the column is named key, unique per business"
        varchar request_hash
        text body
    }
```

The diagram shows the main columns. `categories`, `customers`, `suppliers`, `expenses`, `sale_returns`, `sale_return_items`, `purchase_items` and the other tables carry `business_id` too. The migrations in `backend/database/migrations` are the full truth, and [docs/02-database.md](docs/02-database.md) has the design notes.

A few rules the database enforces, not just the code:

- `items.quantity` can never go below zero (a CHECK constraint).
- A sale's `paid` can never be higher than its total minus what was returned. A purchase's `paid` can never be higher than its total.
- A payment amount is always above zero, and its direction must match whether it points at a sale or a purchase.
- Item names are unique inside one shop, ignoring capital letters, through a partial index on `(business_id, lower(name))`.
- Items are soft-deleted, so old sales keep their names.

## Keeping shops apart

This is the biggest risk in a shared system, so it gets the most care.

```mermaid
flowchart TD
    R["Request with token"] --> A{"Token valid?"}
    A -- no --> X1["401"]
    A -- yes --> B["Business comes from the token<br/>never from the request body"]
    B --> S["Global scope adds<br/>WHERE business_id = yours"]
    S --> Q{"Record found?"}
    Q -- "other shop's record" --> X2["404, as if it did not exist"]
    Q -- yours --> OK["Return it"]
```

Validation rules such as `exists` and `unique` skip model scopes, so they are only built through one helper that adds the business filter. A test covers each case. The full table of risks and the tests that prove them is in [docs/security.md](docs/security.md).

PostgreSQL row-level security is planned as a second wall. I want it done before any real customer joins.

## Roles and screens

| | Owner | Staff |
|---|:---:|:---:|
| Sell, take payments, see customers | yes | yes |
| See items | yes | yes, without buying price |
| Purchases, suppliers, stock corrections | yes | no |
| Expenses, cash book, reports, VAT | yes | no |
| Users and shop settings | yes | no |

The server enforces this. A hidden button in the app is only a convenience.

The website and the phone app use the same screen numbers (A1 to J6) and the same paths. The side menu groups them like this:

```mermaid
flowchart LR
    LOGIN["Log in<br/>forgot password"] --> HOME["Home"]
    HOME --> MAIN["Main<br/>Sales, Items, Customers, Notifications"]
    HOME --> SELL["New sale<br/>cart, checkout, held carts, bill"]
    HOME --> STOCK["Stock (owner)<br/>Stock count, Low stock, Categories"]
    HOME --> BUY["Buying (owner)<br/>Purchases, Suppliers"]
    HOME --> MONEY["Money (owner)<br/>Expenses, Cash book, All payments"]
    HOME --> INS["Insights (owner)<br/>Reports, VAT"]
    HOME --> SET["Settings<br/>Shop, Staff, Activity, App look"]
    MAIN --> CUST["Customer account<br/>payment, reminder, statement"]
    MAIN --> SALEDET["Sale details<br/>return, cancel"]
    BUY --> SUPDET["Supplier account<br/>pay supplier"]
    INS --> REP["Sales chart, Top items,<br/>Credit age, Staff sales"]
    INS --> VATS["VAT filings, books"]
```

## The API

All paths start with `/api/v1`. Responses are JSON with one error shape. Lists are paged.

- [API reference](docs/api-reference.md): every endpoint with request and response examples.
- [docs/openapi.json](docs/openapi.json): 67 operations with their inputs. It is made from the real routes and validation rules by `php artisan pasal:openapi`, and a test fails if it goes out of date. Open it in Swagger Editor or Redoc.

A login, then one call with the token:

```bash
curl -X POST http://localhost:8000/api/v1/login \
  -H "Accept: application/json" -H "Content-Type: application/json" \
  -d '{"email":"you@example.com","password":"your-password"}'

curl http://localhost:8000/api/v1/reports/summary?from=2026-10-01\&to=2026-10-31 \
  -H "Accept: application/json" -H "Authorization: Bearer <token>"
```

## Tests and CI

Every push runs these on GitHub:

```mermaid
flowchart LR
    PUSH["git push"] --> SEC["Secret scan<br/>full history"]
    PUSH --> CI["CI"]
    CI --> B["backend<br/>composer audit<br/>PostgreSQL + php artisan test"]
    CI --> W["web<br/>npm audit, svelte-check<br/>vitest, build"]
    CI --> M["mobile<br/>flutter analyze<br/>flutter test"]
    CI --> D["desktop (macOS)<br/>web build<br/>cargo test"]
```

Run them yourself:

```bash
cd backend && php artisan test          # 168 tests, needs PostgreSQL
cd web && npm test && npm run check     # 341 tests, then the type check
cd mobile && flutter analyze && flutter test   # 361 tests
cd web/src-tauri && cargo test          # Keychain logic
```

Two kinds of tests matter most here. The shop isolation tests check that one shop can never read or change another's data. The finance tests check that a sale, a payment, a return and a VAT period add up to the paisa.

## Security

The short version, with the tests that prove each point, is in [docs/security.md](docs/security.md).

- Every route except login and password reset needs a token. Tokens expire after 30 days, and logout deletes them.
- 5 login tries a minute per email and address. Wrong email and wrong password give the same answer.
- Passwords are hashed, at least 10 characters. A reset signs out every device.
- The shop comes from the token, never from the request. Staff get no buying prices.
- Money and stock can only change through services, inside one transaction, with database CHECK constraints behind them.
- Error answers never show class names or stack traces. Money data is sent with `Cache-Control: no-store`.
- The phone and the Mac app keep the token in the system Keychain or Keystore.
- `composer audit` and `npm audit` run on every push.

What is still open (HTTPS hosting, backups, row-level security, signing the apps) is listed honestly in the [security notes](docs/security.md) and below.

## Run it locally

You need PHP 8.3 or newer with Composer (I use Laravel Herd) and PostgreSQL. For the apps you also need Node, Flutter and Rust.

```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate
```

Create two empty databases, `pasal` and `pasal_test`. Open `.env` and set `DB_DATABASE=pasal` along with your own `DB_USERNAME` and `DB_PASSWORD`.

```bash
php artisan migrate
php artisan pasal:demo-shop      # fake shop "Laxmi Kitchen House" with an owner and a staff login
php artisan serve                # http://localhost:8000/api/v1
```

The demo command prints two logins with random passwords, once. Add `--password=something` to choose one for local use. It only runs outside production, and every name and amount in it is invented. To make your own shop instead, use `php artisan pasal:add-business` and `php artisan pasal:add-user`.

### The website

Keep `php artisan serve` running, then in a second terminal:

```bash
cd web
npm install
npm run dev                      # http://localhost:5173
```

The page calls `/api` on its own address and Vite forwards it to Laravel, so no CORS setting is needed. More in [web/README.md](web/README.md).

### The Mac app

```bash
cd web
npm run tauri -- dev             # a window on the dev server
npm run mac                      # release build: src-tauri/target/release/bundle/macos/PASAL.app
```

The release build runs from `tauri://localhost`, so list that in `PASAL_CORS_ORIGINS` in `backend/.env`. The app is not code signed yet. Details are in [web/README.md](web/README.md#mac-app-tauri).

### The phone app

Start an Android emulator or an iOS simulator, keep `php artisan serve` running, then:

```bash
cd mobile
./setup.sh s                     # first time: packages (and pods on a Mac)
./setup.sh a                     # run on Android, or ./setup.sh ios
```

The Android emulator reaches your computer at `10.0.2.2`, so the default address works. A real phone needs your computer's address in `mobile/config.json`. More in [mobile/README.md](mobile/README.md).

You do not need XAMPP. The API and PostgreSQL are the only two programs the apps talk to.

## Repository layout

```
pasal-fullstack/
  backend/            Laravel API
    app/Http/           Controllers, Requests (validation), Resources (JSON shape), Middleware
    app/Services/       the money logic, one transaction each: sale, purchase, payment, return, stock, VAT
    app/Models/         Eloquent models with the business scope
    app/Support/        CurrentBusiness, ShopDay, BillNumber
    app/Console/        artisan commands: pasal:demo-shop, pasal:add-business, pasal:openapi
    database/           migrations and factories
    tests/Feature/      isolation, finance, inventory, security and API tests
  web/                Svelte website
    src/routes/         one file per screen (A1 to J6)
    src/lib/            api, session, router, money, Nepali calendar, i18n
    src/styles/         one stylesheet and the design tokens
    src-tauri/          the Mac app: Rust shell and Keychain commands
  mobile/             Flutter phone app
    lib/core/           network, session, router, theme, storage
    lib/features/       auth, selling, items, customers, suppliers, money, reports, vat, settings
  docs/               design notes, API reference, OpenAPI file, security notes, screenshots
  .github/workflows/  CI and the secret scan
  .githooks/          local secret check
```

## Status, limits and roadmap

Done: the API, all three clients, tests, CI, the OpenAPI file, a demo shop.

Not done, on purpose listed here:

1. **Hosting.** Nothing is deployed. There is a `Dockerfile` for a container host, but I have not picked one. HTTPS, daily backups and a restore test come with it.
2. **Row-level security** in PostgreSQL as a second wall between shops.
3. **IRD form.** The VAT rate and the exact box names still need to be checked against the live portal form.
4. **Signing.** The Mac app is not signed or notarised, and the Android app has no release key yet.
5. **Nepali text review** by a native speaker.
6. **Later screens:** purchase returns, expiry dates, a Bluetooth receipt printer, camera barcode scanning on the website, Excel and PDF export.
7. **Edit and cancel for purchases and expenses.** Sale returns, cancels and safe retries are done.

## Security of this repository

No secrets belong here. `.env` files, keys, database dumps and private notes are blocked three ways: `.gitignore`, a local pre-commit and pre-push check, and a GitHub Action that scans the full history. On a fresh clone, turn the local check on once:

```bash
git config core.hooksPath .githooks
```

Found a security problem? Please open a private security advisory on GitHub instead of a public issue.

## Licence

Copyright (C) 2026 Sajon Shrestha. Released under the GNU Affero General Public License v3.0. See [LICENSE](LICENSE).

In plain words: you can read, run and change this code. If you run a changed version as an online service, you must share your changes under the same licence. If you want to use PASAL in a way this licence does not allow, contact me and we can talk about a separate licence.
