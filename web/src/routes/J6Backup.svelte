<script lang="ts">
  import { api } from '../lib/api'
  import { action } from '../lib/resource.svelte'
  import { tr, num } from '../lib/i18n'
  import { fromPaisa } from '../lib/money'
  import { adOfStamp, todayAd } from '../lib/bs'
  import { csvCell, downloadText } from '../lib/util'
  import type { Category, Customer, Expense, Item, Sale, Supplier } from '../lib/types'

  type Kind = 'items' | 'customers' | 'suppliers' | 'sales' | 'expenses'
  const EXPORTS: { kind: Kind; icon: string; en: string; ne: string; sub: string; subNe: string }[] = [
    { kind: 'items', icon: 'table_view', en: 'Items (CSV)', ne: 'सामानहरू (CSV)', sub: 'All items, prices and stock', subNe: 'सबै सामान, भाउ र स्टक' },
    { kind: 'customers', icon: 'group', en: 'Customers (CSV)', ne: 'ग्राहकहरू (CSV)', sub: 'Names, phones and balances', subNe: 'नाम, फोन र बाँकी उधारो' },
    { kind: 'suppliers', icon: 'local_shipping', en: 'Suppliers (CSV)', ne: 'डिलरहरू (CSV)', sub: 'Names, phones and what we owe', subNe: 'नाम, फोन र बाँकी' },
    { kind: 'sales', icon: 'receipt_long', en: 'Sales (CSV)', ne: 'बिक्री (CSV)', sub: 'All bills with dates', subNe: 'मिति सहित सबै बिल' },
    { kind: 'expenses', icon: 'receipt', en: 'Expenses (CSV)', ne: 'खर्च (CSV)', sub: 'All expenses with dates', subNe: 'मिति सहित सबै खर्च' },
  ]

  const job = action()
  let page = $state(0)
  let pages = $state(0)
  let label = $state('')
  let doneText = $state<string | null>(null)

  const pct = $derived(pages > 0 ? Math.round((page * 100) / pages) : 0)

  async function fetchAll<T>(path: string, name: string): Promise<T[]> {
    const out: T[] = []
    let last = 1
    label = name
    for (let p = 1; p <= last && p <= 200; p++) {
      const res = await api.page<T>(path, { per_page: 50, page: p })
      out.push(...res.data)
      last = res.meta.last_page ?? 1
      page = p
      pages = last
    }
    return out
  }

  const rupees = (paisa: number | null | undefined): string => (paisa === null || paisa === undefined ? '' : fromPaisa(paisa))
  const table = (header: string[], rows: (string | number | null | undefined)[][]): string =>
    [header, ...rows].map((r) => r.map(csvCell).join(',')).join('\n')

  async function build(kind: Kind): Promise<string> {
    if (kind === 'items') {
      const cats = await api.all<Category>('/categories')
      const names = new Map(cats.map((c) => [c.id, c.name]))
      const items = await fetchAll<Item>('/items', tr('items', 'सामान'))
      return table(
        ['Name', 'SKU', 'Unit', 'Category', 'Sell price (Rs)', 'Buying price (Rs)', 'Stock', 'Low stock level', 'VAT applies'],
        items.map((i) => [i.name, i.sku, i.unit, i.category_id ? names.get(i.category_id) ?? '' : '', rupees(i.sell_price), rupees(i.cost_price), i.quantity, i.low_stock_at, i.vat_applies ? 'Yes' : 'No']),
      )
    }
    if (kind === 'customers') {
      const customers = await fetchAll<Customer>('/customers', tr('customers', 'ग्राहक'))
      return table(
        ['Name', 'Phone', 'Address', 'PAN', 'Credit limit (Rs)', 'Owes (Rs)'],
        customers.map((c) => [c.name, c.phone, c.address, c.pan, rupees(c.credit_limit), rupees(c.owes ?? 0)]),
      )
    }
    if (kind === 'suppliers') {
      const suppliers = await fetchAll<Supplier>('/suppliers', tr('suppliers', 'डिलर'))
      return table(
        ['Name', 'Phone', 'Address', 'PAN', 'We owe (Rs)'],
        suppliers.map((s) => [s.name, s.phone, s.address, s.pan, rupees(s.we_owe ?? 0)]),
      )
    }
    if (kind === 'sales') {
      const sales = await fetchAll<Sale>('/sales', tr('sales', 'बिक्री'))
      return table(
        ['Bill no', 'Date (AD)', 'Sold at (UTC)', 'Customer', 'Subtotal (Rs)', 'Discount (Rs)', 'Total (Rs)', 'Paid (Rs)', 'Balance (Rs)', 'Returned (Rs)', 'VAT (Rs)', 'Cancelled', 'Sold by'],
        sales.map((s) => [
          s.bill_no,
          adOfStamp(s.sold_at),
          s.sold_at,
          s.customer?.name,
          rupees(s.subtotal),
          rupees(s.discount),
          rupees(s.total),
          rupees(s.paid),
          rupees(s.balance),
          rupees(s.returned_total),
          rupees(s.vat_amount),
          s.cancelled_at ? 'Yes' : 'No',
          s.sold_by,
        ]),
      )
    }
    const expenses = await fetchAll<Expense>('/expenses', tr('expenses', 'खर्च'))
    return table(
      ['Date (AD)', 'Title', 'Category', 'Amount (Rs)'],
      expenses.map((e) => [adOfStamp(e.spent_at), e.title, e.category, rupees(e.amount)]),
    )
  }

  async function exportKind(kind: Kind): Promise<void> {
    page = 0
    pages = 0
    doneText = null
    const ok = await job.run(async () => {
      const text = await build(kind)
      downloadText(`pasal-${kind}-${todayAd()}.csv`, text)
      return true
    })
    if (ok) doneText = tr('The file was downloaded.', 'फाइल डाउनलोड भयो।')
  }
</script>

<div class="page narrow">
  <div class="alert">
    <span class="ms">info</span>
    <div class="stack-sm" style="gap:4px">
      <div>{tr('These are CSV files made in your browser from your live shop data. Open them in Excel or Google Sheets.', 'ये तपाईंको पसलको ताजा डेटाबाट ब्राउजरमा बनेका CSV फाइल हुन्। Excel वा Google Sheets मा खोल्नुहोस्।')}</div>
      <div>{tr('A full database backup is made on the server, not in this app. Daily backups are not built yet.', 'पूरा डेटाबेस ब्याकअप सर्भरमा बनाइन्छ, यो एपमा होइन। दैनिक ब्याकअप अझै बनेको छैन।')}</div>
    </div>
  </div>

  {#if job.busy}
    <section class="card stack-sm">
      <span class="small">
        {#if label}
          {tr(`Loading ${label}, page ${num(page)} of ${num(pages)}`, `${label} लोड हुँदैछ, पेज ${num(page)} / ${num(pages)}`)}
        {:else}
          {tr('Starting…', 'सुरु हुँदैछ…')}
        {/if}
      </span>
      <div class="progress" style={`--w:${pct}%`}><span></span></div>
    </section>
  {/if}

  {#if job.message}
    <div class="alert bad"><span class="ms">error</span><div>{job.message}</div></div>
  {/if}
  {#if doneText}
    <div class="alert good"><span class="ms">check_circle</span><div>{doneText}</div></div>
  {/if}

  <div class="section-title"><h3>{tr('Export', 'निर्यात गर्ने')}</h3></div>
  <div class="list">
    {#each EXPORTS as x (x.kind)}
      <button class="row" disabled={job.busy} onclick={() => exportKind(x.kind)}>
        <span class="icon-tile"><span class="ms">{x.icon}</span></span>
        <div class="row-main">
          <div class="row-title">{tr(x.en, x.ne)}</div>
          <div class="row-sub">{tr(x.sub, x.subNe)}</div>
        </div>
        <span class="ms chev">file_download</span>
      </button>
    {/each}
  </div>
</div>
