# PASAL website

Svelte 5 + TypeScript + Vite single page app. It only calls the API in `../docs/api-reference.md`. All business rules stay in the Laravel backend.

## Run it on your own computer

Two programs must run. Postgres and PHP are already installed (Postgres.app and Herd).

```sh
# 1. The API (in one terminal)
cd backend
php artisan migrate
php artisan serve              # http://localhost:8000

# 2. The website (in another terminal)
cd web
npm install                    # first time only
npm run dev                    # http://localhost:5173
```

The website calls `/api/...` on its own address and Vite forwards it to `http://localhost:8000`, so no CORS setting is needed here. To use another API address: `PASAL_API_URL=https://api.example.com npm run dev`.

Build the final files with `npm run build` (output in `dist/`) and try them with `npm run preview`.

Checks: `npm run check` (types), `npm test` (unit tests).

## Folders

| Path | What |
|------|------|
| `src/lib/api.ts` | `api.get/post/patch/put/delete/page/all`, `ApiError`, `newKey()` for the `Idempotency-Key` header |
| `src/lib/types.ts` | TypeScript shapes of every API record |
| `src/lib/session.svelte.ts` | login, logout, `session.user`, `session.isOwner`, `session.business` |
| `src/lib/settings.svelte.ts` | language, theme, main colour, BS dates on or off (saved in the browser) |
| `src/lib/i18n.ts` | `tr(en, ne)`, `num()`, `digits()`, `plural()` |
| `src/lib/money.ts` | `rs()`, `toPaisa()`, `fromPaisa()`, `percentOf()` |
| `src/lib/bs.ts` | Nepali (BS) calendar: `adToBs`, `bsToAd`, `bsMonthRange`, `formatDate`, `todayAd`, `daysUntil` |
| `src/lib/resource.svelte.ts` | `resource()` to load data, `action()` to save with a busy flag and field errors, `debounce()` |
| `src/lib/router.svelte.ts` | hash router: `navigate()`, `setQuery()`, `route.query` |
| `src/lib/toast.svelte.ts` | `toast('Saved', 'सेभ भयो')` |
| `src/lib/shell.svelte.ts` | `setTitle(name)` to change the top bar title after loading |
| `src/lib/util.ts` | `initials`, `telHref`, `whatsappHref`, `smsHref`, `csvCell`, `downloadText` |
| `src/components/` | `Sheet`, `Field`, `AmountPad`, `Empty`, `Skeleton`, `ErrorCard`, `Shell`, `Locked` |
| `src/routes.ts` | every screen: path, component name, Nepali title, menu key, owner only |
| `src/routes/` | one `.svelte` file per screen, named in `routes.ts` (for example `C1NewSale.svelte`) |
| `src/styles/pasal.css` | the design system (Cashew style: one main colour, rounded cards, big numbers) |

## How a screen is written

- The root element is `<div class="page">` (or `class="page narrow"` for forms and details). The frame, top bar and menus come from `Shell`. Never write them.
- Every visible text uses `tr('English', 'नेपाली')`. Numbers go through `num()`, money through `rs()`, dates through `formatDate()` (BS first). Names of people, shops and items stay as they are.
- Load data with `resource(() => api.get<T>(...))`. It runs again by itself when a `$state` value read inside changes (search text, filter chip). Show `Skeleton` while `loading && !data`, `ErrorCard` on `error`, `Empty` when the list is empty.
- Save with `const save = action()` then `await save.run(() => api.post(...))`. Show 422 messages next to the field with `<Field error={save.field('name')}>`. Show `save.message` for a general error.
- `Idempotency-Key`: on every POST that saves a sale, payment, return, purchase, stock change or expense, make `const key = newKey()` once when the screen opens (or after a successful save) and pass it as the third argument of `api.post`. Reuse the same key for a retry of the same tap.
- Money is whole paisa in the API. Inputs are rupees as text. Convert with `toPaisa(text)` and `fromPaisa(paisa)`. Never use floats for money.
- Staff: `cost_price` is `null`. Hide buying price and profit with `{#if session.isOwner}`. `ownerOnly: true` in `routes.ts` already shows a lock card to staff.
- Wide screens show a table (`.table-wrap.wide-only`) next to the phone list (`.list.phone-only`).
- Buttons for the top bar (right side) are placed with `<div use:portal={'#topbar-actions'} class="contents">...</div>`.
- Floating button: `<a class="fab" href="#/...">`. Bottom save bar: `<div class="bottom-bar">`.
- Bottom sheets: `<Sheet bind:open title="...">`.
- Links are hash links: `href="#/customers/12"`. Go from code with `navigate('/customers/12')`.
- Icons are Material Symbols Rounded names: `<span class="ms">add</span>`.
- Money colours always come with words or arrows, never colour alone. Orange is "To collect" or "Given", green is "Received".

## Tests

Pure logic (money, dates, cart maths) has unit tests in `src/**/*.test.ts`, run with `npm test`.

## Mac app (Tauri)

`src-tauri/` puts this website in a native Mac window. The only native code is three Rust commands that keep the login token in the macOS Keychain (`src/lib/token-store.ts` calls them). Needs Rust (`rustc`) and Xcode command line tools.

```sh
npm run tauri -- dev           # window on the Vite server; needs the API on :8000 like the browser
cd src-tauri && cargo test     # Keychain logic test

npm run mac                    # release build that talks to the API on this computer (http://localhost:8000/api/v1)

# Release build for a hosted API: bake in its HTTPS address.
VITE_API_URL=https://api.example.com/api/v1 npm run mac
```

The release app runs from `tauri://localhost`, so the API must allow that origin. In `backend/.env` set `PASAL_CORS_ORIGINS=http://localhost:5173,tauri://localhost` (restart `php artisan serve` after). The app refuses any answer that is not JSON, so a wrong address shows an error instead of an empty screen.

The app lands in `src-tauri/target/release/bundle/macos/PASAL.app`. It is not code signed, so macOS asks before the first open. Signing and notarising need an Apple developer account.
