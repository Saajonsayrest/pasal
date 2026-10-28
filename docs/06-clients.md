# Clients: website, phone app, Mac app

## Decision

| Order | Client | Tool | Why |
|-------|--------|------|-----|
| 1 | Phone app | Flutter | Used at the shop counter every day. You already know Flutter |
| 2 | Website | Svelte + Vite single-page app, calling the API | One screen design for the website and the Mac app |
| 3 | Mac app | Tauri (Rust shell) around the same Svelte screens | No second UI to build. Rust holds the token in the Keychain |

The API stays the only place with business rules. The three clients are thin and only call `docs/api-reference.md`.

## Why not more

- Not a Laravel-rendered website. It would be a second way to talk to the data, and the Mac app could not reuse it.
- Not three separate UIs. Two UI projects (Flutter, Svelte) is the smallest set that covers phone, web and Mac.

## Roles in the screens

After login the app reads `role` and `business` and builds its menu from them. Staff see: sell, items (without buying price), customers and customer credit. Owners also see: purchases, suppliers, expenses, reports, VAT, users and business settings. The server enforces this too, so a hidden button is a convenience and not the protection.

## What each client needs from the backend

| Client | Needs | Status |
|--------|-------|--------|
| Phone | Token login, all endpoints | ready |
| Website | Local: nothing (Vite forwards `/api`). Hosted: CORS origin in `PASAL_CORS_ORIGINS`, HTTPS, cookie-login decision | open for hosting |
| Mac | Token login, all endpoints. The release build runs from `tauri://localhost`, so add that to `PASAL_CORS_ORIGINS` and build with `VITE_API_URL` set to the HTTPS API address | open for hosting |

## Build order and state

1. Phone (`mobile/`): built, every screen from the plan, tested with fake API answers. Not yet run on a real device against the API.
2. Svelte web (`web/`): built, the same screens plus tables on wide screens. Unit tests and a mount test for every screen pass. Not yet clicked through in a browser against the API.
3. Tauri (`web/src-tauri/`): the web build in a native window, token in the Keychain through three Rust commands. Builds to `PASAL.app`, Rust test passes. Not yet opened and clicked through, not signed.

Both apps keep the same screen numbers (A1 to J6) and the same paths (`/customers/:id`, `/sales/:id/bill`), so a change in one is easy to copy to the other.

## Token storage

| Client | Where the token lives |
|--------|-----------------------|
| Phone | Keychain or Keystore (`flutter_secure_storage`). The last known user (name and role, no secret) is cached so the app opens on a weak connection |
| Website | `sessionStorage`: survives a refresh, gone when the tab closes. Not in `localStorage`, never in a URL |
| Mac | macOS Keychain through Rust (`keyring` crate). It survives closing the app. Logout removes it |

Package and tool versions are checked on the official sites on the day each client starts.
