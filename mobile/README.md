# PASAL phone app (Flutter)

The shop counter app for Android and iOS. It only calls the API in `../docs/api-reference.md`. All business rules stay in the Laravel backend.

## Run it

You need the API running first (see `../web/README.md` for the two commands: `php artisan serve` in `backend/`).

```sh
cd mobile
./setup.sh s          # first time: pub get (and pods on a Mac)
./setup.sh a          # run on a running Android emulator
./setup.sh ios        # run on a running iOS simulator
./setup.sh            # list every shortcut
```

`setup.sh` follows the shortcut style of the other Flutter projects. `./setup.sh cgan` means clean, get, analyze.

### Where the app finds the API

| Where the app runs | API address (default) |
|---|---|
| Android emulator | `http://10.0.2.2:8000/api/v1` (10.0.2.2 is the computer) |
| iOS simulator | `http://localhost:8000/api/v1` |
| A real phone | your computer's address, for example `http://192.168.1.20:8000/api/v1`. Start the API with `php artisan serve --host=0.0.0.0` |

To change it, copy `config.example.json` to `config.json` (git-ignored) and set `API_URL`. Or run `flutter run --dart-define=API_URL=https://api.example.com/api/v1`. Release builds need `https`. Plain `http` works only in debug builds.

## How it is built

| Path | What |
|---|---|
| `lib/core/network/api_client.dart` | `ApiClient` (Dio), `ApiException`, `newKey()` for the `Idempotency-Key` header |
| `lib/core/models/models.dart` | every API record as a Dart class |
| `lib/core/session/session.dart` | login, logout, `sessionProvider` (`isOwner`, `business`) |
| `lib/core/settings/settings.dart` | language, theme (light, dark, black), main colour, BS dates (saved on the phone) |
| `lib/core/l10n/tr.dart` | `context.tr('English', 'नेपाली')`, `context.rs(paisa)`, `context.num(n)` |
| `lib/core/utils/` | `money.dart` (`toPaisa`, `fromPaisa`), `bs.dart` (Nepali calendar), `launch.dart` (call, SMS, WhatsApp, share), `guard.dart` |
| `lib/core/widgets/` | the shared parts: `PageScaffold`, `AsyncBody`, `PCard`, `HeroCard`, `StatBlock`, `ListRow`, `ListCard`, `AvatarCircle`, `PBadge`, `EmptyState`, `SkeletonList`, `ErrorView`, `PField`, `MoneyField`, `ChipsRow`, `Seg`, `PrimaryButton`, `AmountPad`, `showPasalSheet`, `confirmSheet`, `BsDateField`, `MonthNav`, `showToast` |
| `lib/core/router/app_router.dart` | the routes and the login and owner-only guard |
| `lib/features/<area>/` | `data/` (repository and providers), `presentation/` (screens and widgets), `<area>_routes.dart` |

State: Riverpod 3 (`Notifier`, `AsyncNotifier`, `FutureProvider`). Navigation: go_router. Text, money and dates never use code generation.

## How a screen is written

- A screen reads data through a provider: `final data = ref.watch(customersProvider(query))`. The provider calls a repository, the repository calls `ApiClient`. A widget never calls `ApiClient` for data.
- Show `SkeletonList` while loading, `ErrorView` with a retry on error, `EmptyState` when there is nothing. `AsyncBody` does the first two.
- Saves use local state in a `ConsumerStatefulWidget`: a busy flag, the `ApiException` of the last try, and `guard(...)`. Show 422 messages under the field with `PField(error: err?.field('name'))`.
- `Idempotency-Key`: on every POST that saves a sale, payment, return, purchase, stock change or expense, make `final key = newKey()` once when the screen opens (and a new one after a success) and pass `key: key` to `api.post`. Make a new key when the body changes.
- Money is whole paisa in the API. Inputs are rupees as text: `toPaisa(text)` and `fromPaisa(paisa)`. Never use a double for money. Show with `context.rs(paisa)`.
- Dates: the API wants AD `YYYY-MM-DD`. Show with `formatDate(iso)` (Nepali date first). Pick with `BsDateField`, `MonthNav`, `bsMonthRange`.
- Every visible text: `context.tr('English', 'नेपाली')`. Names of people, shops and items are never translated.
- Staff: `ref.watch(sessionProvider).isOwner`. Staff never see `costPrice` (it is null) or profit.
- Routes: each area has `<area>_routes.dart`. Screens that open over the bottom menu use `parentNavigatorKey: rootNavigatorKey`. Paths are the same as the website (`/customers/:id`, `/sales/:id/bill`).

## Checks

```sh
flutter analyze        # must say: No issues found
flutter test           # unit and widget tests (they use FakeApi, no network)
```

Tests use `test/helpers/pump_app.dart` (`pumpApp`) and `test/helpers/fake_api.dart` (`FakeApi`).
