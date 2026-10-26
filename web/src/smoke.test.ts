// Mounts every screen with fake server answers and checks that nothing throws.
// It does not look at pixels. It catches code that crashes when data is empty, missing or an error.
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { flushSync, mount, unmount } from 'svelte'
import { ROUTES, loaderFor } from './routes'
import { session } from './lib/session.svelte'
import { setToken } from './lib/api'

const meta = { current_page: 1, last_page: 1, per_page: 50, total: 0 }

// One answer that has every list the API can send, all empty.
const EMPTY = {
  data: [],
  meta,
  summary: { owed_total: 0, owing_customers: 0 },
  days: [],
  hours: Array.from({ length: 24 }, (_, hour) => ({ hour, bills: 0, sales: 0 })),
  top: [],
  slow: [],
  buckets: [],
  customers: [],
  sales: [],
  purchases: [],
  payments: [],
  total: 0,
  bills: 0,
  opening_balance: 0,
  money_in: 0,
  money_out: 0,
  closing_balance: 0,
}

// Answers shaped like the real API, picked by the address. Anything not listed gets EMPTY.
const customer = { id: 1, name: 'Hari Thapa', phone: '9800000001', address: null, pan: null, credit_limit: null, owes: 0, last_sale_at: null, oldest_unpaid_at: null }
const supplier = { id: 1, name: 'Everest Traders', phone: '9811111111', address: null, pan: null, note: null, we_owe: 0, last_purchase_at: null }
const item = {
  id: 1, category_id: null, name: 'Rice 5kg', sku: 'RICE-5', unit: 'pcs', vat_applies: true, cost_price: 80000, sell_price: 100000,
  quantity: 5, low_stock_at: 2, is_low_stock: false, photo_url: null,
}
const line = { id: 1, item_id: 1, item_name: 'Rice 5kg', quantity: 2, unit_price: 100000, discount: 0, line_total: 200000, returned_quantity: 0 }
const sale = {
  id: 1, bill_no: 'S-0001', customer_id: 1, customer, subtotal: 200000, discount: 0, total: 200000, returned_total: 0, paid: 50000, balance: 150000,
  cancelled_at: null, vat_rate: 13, taxable_amount: 176991, vat_amount: 23009, exempt_amount: 0, sold_at: '2026-10-26T07:26:03+00:00', note: null,
  sold_by: 'Asha Shrestha', items: [line],
  payments: [{ id: 1, direction: 'in', sale_id: 1, purchase_id: null, amount: 50000, method: 'cash', paid_at: '2026-10-26T07:26:03+00:00' }], returns: [],
}
const purchase = {
  id: 1, bill_no: 'INV-889', bill_date: '2026-10-24', supplier_id: 1, supplier, total: 1130000, paid: 500000, balance: 630000, vat_amount: 130000,
  bought_at: '2026-10-26T07:26:03+00:00', note: null, items: [{ item_id: 1, item_name: 'Rice 5kg', quantity: 10, unit_cost: 100000, line_total: 1000000 }],
  payments: [{ id: 2, direction: 'out', sale_id: null, purchase_id: 1, amount: 500000, method: 'bank', paid_at: '2026-10-26T07:26:03+00:00' }],
}
const filing = {
  id: 1, period: '2083-07', period_from: '2026-10-18', period_to: '2026-11-16', source: 'computed', sales_taxable: 0, sales_exempt: 0, output_vat: 0,
  purchases_taxable: 0, input_vat: 0, carry_in: 0, payable: 0, carry_out: 0, filed_on: null, paid_amount: 0, paid_on: null, receipt_no: null, note: null,
}
const preview = {
  period_from: '2026-10-18', period_to: '2026-11-16', due_date: '2026-12-11', vat_rate: 13, sales_bills: 0, sales_taxable: 0, sales_exempt: 0, output_vat: 0,
  purchase_bills_with_vat: 0, purchases_taxable: 0, input_vat: 0, carry_in: 0, payable: 0, carry_out: 0, carry_in_source: 'opening value you typed (0 if none)',
}
const business = { id: 1, name: 'Himal Kirana Pasal', pan: '600000001', phone: null, address: null, vat_rate: 13 }

const SPECIFIC: [RegExp, unknown][] = [
  [/\/customers\/\d+\/ledger/, { customer, total_sales: 0, total_paid: 0, owes: 0, credit_limit: null, sales: [], payments: [] }],
  [/\/suppliers\/\d+\/ledger/, { supplier, total_purchases: 0, total_paid: 0, we_owe: 0, purchases: [], payments: [] }],
  [/\/items\/\d+\/stock-movements/, { item: { id: 1, name: 'Rice 5kg', quantity: 5 }, data: [], links: { next: null, prev: null }, meta: { current_page: 1, per_page: 30, total: 0 } }],
  [/\/customers\/\d+/, { data: customer }],
  [/\/suppliers\/\d+/, { data: supplier }],
  [/\/items\/\d+/, { data: item }],
  [/\/sales\/\d+/, { data: sale }],
  [/\/purchases\/\d+/, { data: purchase }],
  [/\/vat\/filings\/\d+/, { data: filing }],
  [/\/vat\/preview/, preview],
  [/\/business/, { data: business }],
  [/\/reports\/summary/, { from: '2026-10-01', to: '2026-10-31', sales_total: 0, vat_collected: 0, cost_of_goods: 0, expenses_total: 0, profit: 0, stock_value: 0, owed_to_us: 0, we_owe: 0 }],
  [/\/reports\/credit-age/, { as_of: '2026-10-26', total: 0, buckets: [], customers: [] }],
  [/\/cash-book/, { from: '2026-10-26', to: '2026-10-26', opening_balance: 0, money_in: 0, money_out: 0, closing_balance: 0, data: [], meta }],
]

const RECORD = Symbol('record')
const POPULATED = Symbol('populated')

const listOf = (rows: unknown[], extra: object = {}) => ({ ...EMPTY, data: rows, meta: { ...meta, total: rows.length }, ...extra })
const payment = { id: 1, direction: 'in', sale_id: 1, purchase_id: null, amount: 50000, method: 'cash', paid_at: '2026-10-26T07:26:03+00:00', party: 'Hari Thapa' }
const ledgerSale = { id: 1, bill_no: 'S-0001', sold_at: '2026-10-26T07:26:03+00:00', total: 200000, returned_total: 0, paid: 50000, balance: 150000, cancelled_at: null }

// Lists with real looking rows, so the row markup runs too.
const ROWS: [RegExp, unknown][] = [
  [/\/customers\/\d+\/ledger/, { customer, total_sales: 200000, total_paid: 50000, owes: 150000, credit_limit: 500000, sales: [ledgerSale], payments: [payment] }],
  [/\/suppliers\/\d+\/ledger/, { supplier, total_purchases: 1130000, total_paid: 500000, we_owe: 630000, purchases: [{ id: 1, bill_no: 'INV-889', bought_at: '2026-10-26T07:26:03+00:00', total: 1130000, paid: 500000, balance: 630000 }], payments: [{ ...payment, direction: 'out', sale_id: null, purchase_id: 1 }] }],
  [/\/items\/\d+\/stock-movements/, { item: { id: 1, name: 'Rice 5kg', quantity: 5 }, data: [{ id: 1, change: -2, reason: 'sale', ref_type: 'sale', ref_id: 1, note: null, by: 'Asha', at: '2026-10-26T07:26:03+00:00' }], links: { next: null, prev: null }, meta: { current_page: 1, per_page: 30, total: 1 } }],
  [/\/api\/v1\/customers(\?|$)/, listOf([{ ...customer, owes: 150000 }], { summary: { owed_total: 150000, owing_customers: 1 } })],
  [/\/api\/v1\/suppliers(\?|$)/, listOf([{ ...supplier, we_owe: 630000 }], { summary: { owed_total: 630000 } })],
  [/\/api\/v1\/items(\?|$)/, listOf([item, { ...item, id: 2, name: 'Sugar', quantity: 1, is_low_stock: true }])],
  [/\/api\/v1\/items\/suggest/, listOf([item])],
  [/\/api\/v1\/categories(\?|$)/, listOf([{ id: 1, name: 'Grocery', icon: 'rice_bowl', color: '#e0731a' }])],
  [/\/api\/v1\/sales(\?|$)/, listOf([{ ...sale, items: undefined, payments: undefined, returns: undefined }])],
  [/\/api\/v1\/purchases(\?|$)/, listOf([{ ...purchase, items: undefined, payments: undefined }])],
  [/\/api\/v1\/payments(\?|$)/, listOf([payment])],
  [/\/api\/v1\/expenses(\?|$)/, listOf([{ id: 1, title: 'Electricity', category: 'bills', amount: 185000, spent_at: '2026-10-20T00:00:00+00:00' }])],
  [/\/api\/v1\/users(\?|$)/, listOf([{ id: 1, name: 'Asha Shrestha', email: 'asha@example.com', role: 'owner' }, { id: 2, name: 'Bikash K.', email: 'b@example.com', role: 'staff' }])],
  [/\/api\/v1\/vat\/filings(\?|$)/, listOf([filing])],
  [/\/api\/v1\/notifications/, { data: [{ type: 'low_stock', title: '2 items are low on stock', body: 'Sugar, Salt', at: '2026-10-26T07:26:03+00:00', count: 2 }] }],
  [/\/api\/v1\/activity/, listOf([{ kind: 'sale', ref_id: 1, at: '2026-10-26T07:26:03+00:00', by: 'Asha Shrestha', label: 'S-0001', amount: 200000 }])],
  [/\/reports\/daily/, { from: '2026-10-20', to: '2026-10-26', days: [{ date: '2026-10-26', bills: 3, sales: 450000 }, { date: '2026-10-25', bills: 1, sales: 90000 }], hours: Array.from({ length: 24 }, (_, hour) => ({ hour, bills: hour === 10 ? 2 : 0, sales: hour === 10 ? 300000 : 0 })), total: 540000, bills: 4 }],
  [/\/reports\/items/, { from: '2026-10-01', to: '2026-10-31', top: [{ item_id: 1, name: 'Rice 5kg', unit: 'pcs', quantity: 5, revenue: 500000 }], slow: [{ item_id: 2, name: 'Sugar', unit: 'pcs', in_stock: 8, sold: 0, stock_value: 80000 }] }],
  [/\/reports\/staff/, { from: '2026-10-01', to: '2026-10-31', data: [{ user_id: 1, name: 'Asha Shrestha', bills: 4, sales: 540000, discount: 0 }] }],
  [/\/reports\/credit-age/, { as_of: '2026-10-26', total: 150000, buckets: [{ key: 'd0_30', label: '0-30 days', bills: 1, amount: 150000 }, { key: 'd31_60', label: '31-60 days', bills: 0, amount: 0 }, { key: 'd61_90', label: '61-90 days', bills: 0, amount: 0 }, { key: 'd90_plus', label: 'Over 90 days', bills: 0, amount: 0 }], customers: [{ customer_id: 1, name: 'Hari Thapa', phone: '9800000001', owes: 150000, oldest_days: 12, bucket: 'd0_30' }] }],
  [/\/cash-book/, { from: '2026-10-26', to: '2026-10-26', opening_balance: 10000, money_in: 50000, money_out: 20000, closing_balance: 40000, data: [{ kind: 'payment_in', id: 1, at: '2026-10-26T07:26:03+00:00', amount: 50000, method: 'cash', label: 'Hari Thapa', balance: 60000 }, { kind: 'expense', id: 2, at: '2026-10-26T08:26:03+00:00', amount: -20000, method: 'cash', label: 'Tea', balance: 40000 }], meta: { ...meta, total: 2 } }],
]

function stubFetch(status: number, body: unknown): void {
  vi.stubGlobal(
    'fetch',
    vi.fn(async (url: string) => {
      const find = (table: [RegExp, unknown][]) => table.find(([pattern]) => pattern.test(String(url)))?.[1]
      let answer = body
      if (body === RECORD) answer = find(SPECIFIC) ?? EMPTY
      if (body === POPULATED) answer = find(ROWS) ?? find(SPECIFIC) ?? EMPTY
      return new Response(JSON.stringify(answer), { status, headers: { 'Content-Type': 'application/json' } })
    }),
  )
}

const errors: unknown[] = []
const onError = (e: ErrorEvent) => errors.push(e.error ?? e.message)
const onRejection = (e: PromiseRejectionEvent) => errors.push(e.reason)

beforeEach(() => {
  errors.length = 0
  document.body.innerHTML = '<div class="app"><div id="topbar-actions"></div><div id="host"></div></div>'
  window.addEventListener('error', onError)
  window.addEventListener('unhandledrejection', onRejection)
  setToken('test-token')
  session.user = { id: 1, name: 'Asha Shrestha', email: 'asha@example.com', role: 'owner', business: { id: 1, name: 'Himal Kirana Pasal', pan: '600000001', phone: null, address: null, vat_rate: 13 } }
})

afterEach(() => {
  window.removeEventListener('error', onError)
  window.removeEventListener('unhandledrejection', onRejection)
  vi.unstubAllGlobals()
})

const wait = (ms: number) => new Promise((r) => setTimeout(r, ms))

const scenarios: [string, number, unknown][] = [
  ['normal answers (records, empty lists)', 200, RECORD as unknown],
  ['lists with rows', 200, POPULATED as unknown],
  ['server error', 500, { message: 'Something went wrong.' }],
  ['forbidden', 403, { message: 'Only the owner can do this.' }],
]

describe('rows really show on the screen', () => {
  it.each([
    ['E1', 'Hari Thapa'],
    ['D1', 'Rice 5kg'],
    ['C4', 'S-0001'],
    ['F4', 'INV-889'],
    ['G1', 'Electricity'],
    ['J2', 'Bikash K.'],
    ['H4', 'Hari Thapa'],
  ])('%s lists "%s"', async (id, text) => {
    stubFetch(200, POPULATED)
    const def = ROUTES.find((r) => r.id === id)!
    const mod = await loaderFor(def, true)!()
    const host = document.getElementById('host')!
    const component = mount(mod.default, { target: host, props: { params: {}, query: {} } })
    flushSync()
    await wait(30)
    flushSync()
    expect(host.textContent).toContain(text)
    unmount(component)
  })
})

describe('staff screens', () => {
  it.each(ROUTES.filter((r) => !r.public && !r.ownerOnly))('$id $path mounts for staff', async (def) => {
    stubFetch(200, RECORD)
    session.user = { id: 2, name: 'Bikash K.', email: 'bikash@example.com', role: 'staff', business: session.user?.business }
    const mod = await loaderFor(def, false)!()
    const host = document.getElementById('host')!
    const params = Object.fromEntries([...def.path.matchAll(/:(\w+)/g)].map((m) => [m[1], '1']))
    const component = mount(mod.default, { target: host, props: { params, query: {} } })
    flushSync()
    await wait(15)
    flushSync()
    expect(errors, `${def.id} threw`).toEqual([])
    unmount(component)
  })
})

describe.each(scenarios)('every screen with %s', (_name, status, body) => {
  it.each(ROUTES.filter((r) => !r.public || r.id === 'A2' || r.id === 'A2b'))('$id $path mounts without throwing', async (def) => {
    stubFetch(status, body)
    const load = loaderFor(def, true)
    expect(load, `component file for ${def.id} exists`).not.toBeNull()
    const mod = await load!()
    const host = document.getElementById('host')!
    const params = Object.fromEntries([...def.path.matchAll(/:(\w+)/g)].map((m) => [m[1], '1']))
    const component = mount(mod.default, { target: host, props: { params, query: {} } })
    flushSync()
    await wait(15)
    flushSync()
    expect(errors, `${def.id} threw`).toEqual([])
    expect(host.innerHTML.length).toBeGreaterThan(0)
    unmount(component)
  })
})
