import type { Component } from 'svelte'

// Every screen of the product. `comp` is the file name in src/routes/ (without .svelte).
// `nav` is the menu button that shows as active. `title` is [English, Nepali] for the top bar.
// A page can change its title later with setTitle() from lib/shell.svelte.

export interface RouteDef {
  /** Screen number from the plan (docs: private/system-plan.md), for example "C1". */
  id: string
  path: string
  comp: string | ((owner: boolean) => string)
  title: [string, string]
  nav?: string
  /** Staff see a lock card instead of the page. */
  ownerOnly?: boolean
  /** No menus at all (login, first-run guide). */
  noShell?: boolean
  /** Keep the top bar, hide the bottom menu (focused flows such as checkout). */
  noNav?: boolean
  /** Works without logging in. */
  public?: boolean
  /** Back arrow target. */
  back?: string
}

export const ROUTES: RouteDef[] = [
  // A. Account
  { id: 'A1', path: '/login', comp: 'A1Login', title: ['Log in', 'लग इन'], noShell: true, public: true },
  { id: 'A2', path: '/forgot-password', comp: 'A2ForgotPassword', title: ['Forgot password', 'पासवर्ड बिर्सनुभयो'], noShell: true, public: true },
  { id: 'A2b', path: '/reset-password', comp: 'A2ResetPassword', title: ['New password', 'नयाँ पासवर्ड'], noShell: true, public: true },
  { id: 'A3', path: '/welcome', comp: 'A3FirstRun', title: ['First-run guide', 'सुरुको गाइड'], noShell: true, ownerOnly: true },
  { id: 'A4', path: '/profile', comp: 'A4Profile', title: ['My profile', 'मेरो प्रोफाइल'], nav: 'more', back: '/more' },

  // B. Home
  { id: 'B1', path: '/', comp: (owner) => (owner ? 'B1OwnerHome' : 'B2StaffHome'), title: ['Home', 'गृहपृष्ठ'], nav: 'home' },
  { id: 'B3', path: '/notifications', comp: 'B3Notifications', title: ['Notifications', 'सूचनाहरू'], nav: 'notifications', back: '/' },
  { id: 'B4', path: '/more', comp: 'B4More', title: ['Everything else', 'अरू सबै'], nav: 'more' },

  // C. Selling
  { id: 'C1', path: '/sell', comp: 'C1NewSale', title: ['New sale', 'नयाँ बिक्री'], nav: 'sell' },
  { id: 'C2', path: '/sell/checkout', comp: 'C2Checkout', title: ['Cart and checkout', 'कार्ट र भुक्तानी'], nav: 'sell', noNav: true, back: '/sell' },
  { id: 'C8', path: '/sell/held', comp: 'C8HeldCarts', title: ['Held carts', 'रोकिएका कार्ट'], nav: 'sell', back: '/sell' },
  { id: 'C4', path: '/sales', comp: 'C4Sales', title: ['Sales', 'बिक्री सूची'], nav: 'sales' },
  { id: 'C5', path: '/sales/:id', comp: 'C5SaleDetails', title: ['Sale details', 'बिक्री विवरण'], nav: 'sales', back: '/sales' },
  { id: 'C3', path: '/sales/:id/bill', comp: 'C3Bill', title: ['Bill', 'बिल'], nav: 'sales', back: '/sales' },
  { id: 'C6', path: '/sales/:id/return', comp: 'C6SaleReturn', title: ['Sale return', 'बिक्री फिर्ता'], nav: 'sales', ownerOnly: true, back: '/sales' },
  { id: 'C7', path: '/sales/:id/cancel', comp: 'C7CancelSale', title: ['Cancel sale', 'बिक्री रद्द'], nav: 'sales', ownerOnly: true, back: '/sales' },

  // D. Items and stock
  { id: 'D1', path: '/items', comp: 'D1Items', title: ['Items', 'सामानहरू'], nav: 'items' },
  { id: 'D3', path: '/items/new', comp: 'D3ItemForm', title: ['Add item', 'सामान थप्ने'], nav: 'items', ownerOnly: true, back: '/items' },
  { id: 'D9', path: '/items/deleted', comp: 'D9DeletedItems', title: ['Deleted items', 'हटाइएका सामान'], nav: 'items', ownerOnly: true, back: '/items' },
  { id: 'D2', path: '/items/:id', comp: 'D2ItemDetails', title: ['Item details', 'सामान विवरण'], nav: 'items', back: '/items' },
  { id: 'D3e', path: '/items/:id/edit', comp: 'D3ItemForm', title: ['Edit item', 'सामान सच्याउने'], nav: 'items', ownerOnly: true, back: '/items' },
  { id: 'D4', path: '/items/:id/adjust', comp: 'D4AdjustStock', title: ['Adjust stock', 'स्टक मिलाउने'], nav: 'items', ownerOnly: true, back: '/items' },
  { id: 'D5', path: '/items/:id/history', comp: 'D5StockHistory', title: ['Stock history', 'स्टक इतिहास'], nav: 'items', ownerOnly: true, back: '/items' },
  { id: 'D6', path: '/stock-count', comp: 'D6StockCount', title: ['Stock count', 'स्टक गणना'], nav: 'stock-count', ownerOnly: true, back: '/more' },
  { id: 'D7', path: '/low-stock', comp: 'D7LowStock', title: ['Low stock and reorder', 'कम स्टक र पुनः अर्डर'], nav: 'low-stock', ownerOnly: true, back: '/more' },
  { id: 'D8', path: '/categories', comp: 'D8Categories', title: ['Categories', 'वर्गहरू'], nav: 'categories', ownerOnly: true, back: '/more' },
  { id: 'D10', path: '/barcode-labels', comp: 'D10BarcodeLabels', title: ['Barcode labels', 'बारकोड लेबल'], nav: 'items', ownerOnly: true, back: '/items' },
  { id: 'D11', path: '/expiry', comp: 'D11Expiry', title: ['Expiry dates', 'म्याद सकिने मिति'], nav: 'items', ownerOnly: true, back: '/items' },

  // E. Customers and credit (udhar)
  { id: 'E1', path: '/customers', comp: 'E1Customers', title: ['Customers', 'ग्राहकहरू'], nav: 'customers' },
  { id: 'E4', path: '/customers/new', comp: 'E4CustomerForm', title: ['Add customer', 'ग्राहक थप्ने'], nav: 'customers', back: '/customers' },
  { id: 'E2', path: '/customers/:id', comp: 'E2CustomerLedger', title: ['Customer ledger', 'ग्राहक खाता'], nav: 'customers', back: '/customers' },
  { id: 'E4e', path: '/customers/:id/edit', comp: 'E4CustomerForm', title: ['Edit customer', 'ग्राहक सच्याउने'], nav: 'customers', back: '/customers' },
  { id: 'E3', path: '/customers/:id/payment', comp: 'E3TakePayment', title: ['Take payment', 'भुक्तानी लिने'], nav: 'customers', back: '/customers' },
  { id: 'E5', path: '/customers/:id/remind', comp: 'E5Reminder', title: ['Reminder', 'सम्झना सन्देश'], nav: 'customers', back: '/customers' },
  { id: 'E6', path: '/customers/:id/statement', comp: 'E6Statement', title: ['Statement', 'हिसाब विवरण'], nav: 'customers', back: '/customers' },

  // F. Suppliers and purchases (owner)
  { id: 'F1', path: '/suppliers', comp: 'F1Suppliers', title: ['Suppliers', 'डिलरहरू'], nav: 'suppliers', ownerOnly: true, back: '/more' },
  { id: 'F1n', path: '/suppliers/new', comp: 'F1SupplierForm', title: ['Add supplier', 'डिलर थप्ने'], nav: 'suppliers', ownerOnly: true, back: '/suppliers' },
  { id: 'F2', path: '/suppliers/:id', comp: 'F2SupplierLedger', title: ['Supplier ledger', 'डिलर खाता'], nav: 'suppliers', ownerOnly: true, back: '/suppliers' },
  { id: 'F1e', path: '/suppliers/:id/edit', comp: 'F1SupplierForm', title: ['Edit supplier', 'डिलर सच्याउने'], nav: 'suppliers', ownerOnly: true, back: '/suppliers' },
  { id: 'F5', path: '/suppliers/:id/pay', comp: 'F5PaySupplier', title: ['Pay supplier', 'डिलरलाई भुक्तानी'], nav: 'suppliers', ownerOnly: true, back: '/suppliers' },
  { id: 'F3', path: '/purchases/new', comp: 'F3NewPurchase', title: ['New purchase', 'नयाँ खरिद'], nav: 'purchases', ownerOnly: true, back: '/purchases' },
  { id: 'F4', path: '/purchases', comp: 'F4Purchases', title: ['Purchases', 'खरिदहरू'], nav: 'purchases', ownerOnly: true, back: '/more' },
  { id: 'F4d', path: '/purchases/:id', comp: 'F4PurchaseDetails', title: ['Purchase details', 'खरिद विवरण'], nav: 'purchases', ownerOnly: true, back: '/purchases' },
  { id: 'F6', path: '/purchase-return', comp: 'F6PurchaseReturn', title: ['Purchase return', 'खरिद फिर्ता'], nav: 'purchases', ownerOnly: true, back: '/purchases' },

  // G. Money
  { id: 'G1', path: '/expenses', comp: 'G1Expenses', title: ['Expenses', 'खर्चहरू'], nav: 'expenses', ownerOnly: true, back: '/more' },
  { id: 'G2', path: '/expenses/new', comp: 'G2AddExpense', title: ['Add expense', 'खर्च थप्ने'], nav: 'expenses', ownerOnly: true, noNav: true, back: '/expenses' },
  { id: 'G3', path: '/cash-book', comp: 'G3CashBook', title: ['Cash book', 'नगद किताब'], nav: 'cash-book', ownerOnly: true, back: '/more' },
  { id: 'G4', path: '/payments', comp: 'G4Payments', title: ['All payments', 'सबै भुक्तानी'], nav: 'payments', ownerOnly: true, back: '/more' },

  // H. Reports
  { id: 'H1', path: '/reports', comp: 'H1Reports', title: ['Reports', 'रिपोर्टहरू'], nav: 'reports', ownerOnly: true, back: '/more' },
  { id: 'H2', path: '/reports/sales', comp: 'H2SalesChart', title: ['Sales chart', 'बिक्री चार्ट'], nav: 'reports', ownerOnly: true, back: '/reports' },
  { id: 'H3', path: '/reports/items', comp: 'H3TopItems', title: ['Top and slow items', 'धेरै र कम बिक्ने सामान'], nav: 'reports', ownerOnly: true, back: '/reports' },
  { id: 'H4', path: '/reports/credit-age', comp: 'H4CreditAge', title: ['Credit age', 'उधारोको उमेर'], nav: 'reports', ownerOnly: true, back: '/reports' },
  { id: 'H5', path: '/reports/staff', comp: 'H5StaffSales', title: ['Staff sales', 'कर्मचारीको बिक्री'], nav: 'reports', ownerOnly: true, back: '/reports' },
  { id: 'H6', path: '/reports/export', comp: 'H6Export', title: ['Export', 'निर्यात'], nav: 'reports', ownerOnly: true, back: '/reports' },

  // I. VAT
  { id: 'I1', path: '/vat', comp: 'I1Vat', title: ['VAT this month', 'यो महिनाको भ्याट'], nav: 'vat', ownerOnly: true, back: '/more' },
  { id: 'I2', path: '/vat/filings', comp: 'I2VatFilings', title: ['VAT filings', 'भ्याट फाइलिङ'], nav: 'vat', ownerOnly: true, back: '/vat' },
  { id: 'I4', path: '/vat/old-return', comp: 'I4OldReturn', title: ['Add old return', 'पुरानो रिटर्न थप्ने'], nav: 'vat', ownerOnly: true, back: '/vat/filings' },
  { id: 'I5', path: '/vat/books', comp: 'I5VatBooks', title: ['Sales and purchase books', 'बिक्री र खरिद खाता'], nav: 'vat', ownerOnly: true, back: '/vat' },
  { id: 'I3', path: '/vat/filings/:id', comp: 'I3FilingDetails', title: ['Filing details', 'फाइलिङ विवरण'], nav: 'vat', ownerOnly: true, back: '/vat/filings' },

  // J. Settings
  { id: 'J1', path: '/settings/shop', comp: 'J1Shop', title: ['Shop details', 'पसलको विवरण'], nav: 'shop', ownerOnly: true, back: '/more' },
  { id: 'J2', path: '/settings/staff', comp: 'J2Staff', title: ['Staff', 'कर्मचारी'], nav: 'staff', ownerOnly: true, back: '/more' },
  { id: 'J3', path: '/settings/look', comp: 'J3AppLook', title: ['App look', 'एपको रूप'], nav: 'look', back: '/more' },
  { id: 'J4', path: '/settings/printer', comp: 'J4Printer', title: ['Printer', 'प्रिन्टर'], nav: 'look', back: '/more' },
  { id: 'J5', path: '/settings/activity', comp: 'J5Activity', title: ['Activity log', 'गतिविधि लग'], nav: 'activity', ownerOnly: true, back: '/more' },
  { id: 'J6', path: '/settings/backup', comp: 'J6Backup', title: ['Backup and export', 'ब्याकअप र निर्यात'], nav: 'look', ownerOnly: true, back: '/more' },
]

type Loader = () => Promise<{ default: Component<any> }>

// Vite finds every file in src/routes/. A screen that is not written yet shows a "not built" card.
const files = import.meta.glob<{ default: Component<any> }>('./routes/*.svelte') as Record<string, Loader>

export function loaderFor(def: RouteDef, owner: boolean): Loader | null {
  const name = typeof def.comp === 'function' ? def.comp(owner) : def.comp
  return files[`./routes/${name}.svelte`] ?? null
}
