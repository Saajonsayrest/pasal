# Security notes

Threat model in one line: a stranger on the internet tries to read or change a shop's money data, another business using the same system tries to look at ours, or a lost phone falls into the wrong hands. Family members and staff are trusted only as far as their role allows.

## What is done, and the test that proves it

| Risk | What we do | Test (in `backend/tests/Feature`) |
|------|-----------|-----------------------------------|
| Anyone reads data without a login | Every route except `/login` needs a token | `AuthTest` "blocks every data route without a token" |
| One business reads or changes another's data (the biggest risk of a shared system) | Every data table has `business_id`. A global scope adds `WHERE business_id = <your business>` to every query. With nobody logged in it matches nothing. Other businesses' records answer 404 | `BusinessIsolationTest` "lists only your own records", "answers 404 for another shop record...", "fails closed..." |
| An id from another business sneaking into a request | Validation `exists` and `unique` rules skip model scopes, so they are built only through `App\Support\CurrentBusiness`, which adds the business filter | `BusinessIsolationTest` "refuses to use another shop item, customer or supplier...", "refuses payments and stock changes..." |
| A client claiming to be another business | The business always comes from the token. A `business_id` in the body is ignored and the column is not mass-assignable | `BusinessIsolationTest` "ignores a business_id sent by the client" |
| Reports or VAT mixing two businesses | Same scope on sales, purchases, payments, expenses, filings | `BusinessIsolationTest` "counts only your own money in reports and VAT" |
| Staff doing owner work, or seeing profit | `owner` middleware on stock, buying, money, reports, VAT, users and settings. Staff get `cost_price: null` | `BusinessIsolationTest` "limits staff to counter work" |
| Guessing passwords | 5 login tries a minute per email and address, 30 per address, passwords hashed, minimum 10 characters | `SecurityTest` "stops the sixth login try in a minute" |
| Stolen or old token | Tokens expire after 30 days. Logout deletes the token. Deleted tokens stop working | `SecurityTest` "rejects a token that was revoked", `AuthTest` "shows the current user and logs out" |
| Account probing | Same message for wrong email and wrong password. Failed logins are logged without the password | `AuthTest` "rejects a wrong password...", `SecurityTest` "logs a failed login..." |
| Information leaks | Missing records and wrong methods give a plain JSON message, never class names or stack traces | `SecurityTest` "hides internal class names...", "gives a clean JSON error..." |
| Browser attacks | Safety headers on every response, and `Cache-Control: no-store` so money data is not cached | `SecurityTest` "sends safety headers and forbids caching" |
| Other websites calling the API | CORS allows nothing unless the owner lists an address in `PASAL_CORS_ORIGINS` | not tested yet |
| Crashes from huge numbers | Every number has a maximum, so bad input gives 422, not a server error | `SecurityTest` "rejects huge numbers..." |
| Changing stock or paid amounts directly | `quantity` and `paid` are not mass-assignable. Only the services change them, inside one database transaction | `InventoryTest` "creates an item and ignores a sent quantity" |
| Two sales taking the last item | Row locks in `StockService` and `PaymentService` | not tested under real parallel load |
| SQL injection | Eloquent bindings only. Search text has `%` and `_` escaped | no raw SQL takes user input |
| Overpaying or negative stock | Checked in code and by database CHECK constraints | `FinanceTest` "takes a later payment and refuses to overpay", `InventoryTest` "refuses to take stock below zero" |
| Vulnerable packages | `composer audit` found no advisories on 2026-10-26 | run it again before every release |

## Open items (not done yet)

1. **HTTPS and hosting.** The API must run only behind HTTPS in production. We have not chosen where it runs.
2. **`.env` in production.** `APP_DEBUG=false`, `APP_ENV=production`, a strong `APP_KEY`, and `.env` never committed.
3. **Database backups.** Daily `pg_dump`, stored off the machine, and one restore test.
4. **Audit log.** Money rows carry `user_id`, but there is no table for edits and deletes. Edits do not exist yet, so add it together with them.
5. **Database-level business separation.** The separation lives in the application. If someone later writes a query that skips the scope (`withoutGlobalScopes`, raw SQL), the database would not stop it. Add PostgreSQL row-level security, or composite foreign keys `(id, business_id)`, before real customers join.
6. **Website token storage.** A token in the browser can be stolen by injected script. Decide on cookie login before the website goes public.
7. **Safe retries.** A repeated POST after a timeout creates a second sale. Add an idempotency key.
8. **CI.** Run the tests and `composer audit` on every push, and turn on Dependabot.
9. **Platform admin.** Creating, suspending and removing businesses is a command-line job. Nobody should log in as a "super user" through the API.
10. **Per-business limits.** One noisy business shares the 120-per-minute pool only with its own user, but there is no cap on stored rows per business yet.

Closed since the first version: per-email login limit, password change, "log out on all devices", removing a user.
