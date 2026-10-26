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
| Website | CORS origin in `PASAL_CORS_ORIGINS`, HTTPS, cookie-login decision | open |
| Mac | Token login, all endpoints | ready |

## Build order

1. Phone: login, items list, new sale, customer credit, VAT summary.
2. Svelte web: same screens, plus reports and VAT filings (bigger screen, tables).
3. Tauri: wrap the web build, move the token to the Keychain through a Rust command.

Package and tool versions are checked on the official sites on the day each client starts.
