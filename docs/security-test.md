# Security test report

A short attack-minded review of PASAL's own code, done on 2026-10-28. Scope: the Laravel API, the Svelte website and Tauri Mac app, the Flutter phone app, the CI setup and the dependencies. Everything ran on a local machine with fake data. No live system was touched.

## How it was done

1. Read every route, middleware, request rule and raw SQL query, asking one question: what can a logged-in staff member or a stranger do by calling the API directly, without the app?
2. Checked the secrets rules: no `.env`, key or private notes are tracked.
3. Ran `composer audit` and `npm audit`.
4. Wrote an attack as a test for each suspected hole, ran it against the old code to prove it worked, fixed the code, and ran it again.

## What held up

- Every raw SQL query carries `business_id` and uses bound values. No user text reaches SQL.
- Reports, the cash book and the activity feed never mix two businesses.
- Mass assignment is closed on `User`. `role` and `business_id` cannot be sent by a client.
- Idempotency keys are scoped per business, so one shop cannot replay another shop's answer.
- No unsafe HTML in the website (`{@html}` and `innerHTML` are not used). The phone token sits in secure storage and Android backup is off.
- `composer audit`: no advisories.

## Found and fixed

| # | Finding | Proof (before the fix) | Fix | Test |
|---|---------|------------------------|-----|------|
| 1 | Staff could set their own `unit_price` and sell at 1 paisa, which gets around the 10% staff discount cap | Staff sale with `unit_price: 1` answered 201 | Price, date and bill number are owner-only fields | `StaffAbuseTest` "stops staff from selling below the list price..." |
| 2 | Staff could backdate a sale or pick its bill number, which breaks the VAT bill sequence | Staff sale with `sold_at` in 2020 answered 201 | Same rule | `StaffAbuseTest` "stops staff from backdating..." |
| 3 | Staff could delete a customer, which hides that customer's udhar from the lists | `DELETE /customers/{id}` as staff answered 200 | Route moved into the owner group. Delete button hidden for staff on web and phone | `StaffAbuseTest` "lets only the owner delete a customer" |
| 4 | Login timing showed which emails have an account. Unknown email took 0.8 ms, wrong password 28 ms | Measured in the test | A dummy hash runs for unknown emails | `SecurityTest` "takes about as long to refuse an unknown email..." |
| 5 | CI token had default write rights | Read of `ci.yml` | `permissions: contents: read` | n/a |

After the fixes: 172 backend tests, 341 website tests and 361 phone tests pass, and both analysers are clean.

## Known gaps, to close before real customers

These need a hosting decision first. Nothing is deployed yet.

- Android reset link uses the custom scheme `pasal://`. Another app on the same phone could register it and read the reset token. Fix: HTTPS App Links on the real domain.
- The website has no Content-Security-Policy yet. Add one on the host, since the token lives in `sessionStorage`. The Mac app's policy allows any `https:` host in `connect-src`. Narrow it to the API host.
- Behind a load balancer the API must trust the proxy, or every user shares one IP in the login limit.
- The `Dockerfile` starts `php artisan serve` as root. Use a real PHP server and a non-root user for production.
- `npm audit` shows 2 low advisories (`deepmerge`, build tool only, no fix published). Not shipped to users.
