<script lang="ts">
  import { api } from '../lib/api'
  import { action } from '../lib/resource.svelte'
  import { tr, num } from '../lib/i18n'
  import { fromPaisa } from '../lib/money'
  import { adOfStamp, adToBs, monthName, todayAd } from '../lib/bs'
  import { rangeFor } from '../lib/range'
  import { csvCell, downloadText } from '../lib/util'
  import type { Customer, Expense, Item, Payment, Purchase, Sale } from '../lib/types'
  import RangePicker from '../components/RangePicker.svelte'

  type Key = 'sales' | 'purchases' | 'payments' | 'expenses' | 'items' | 'customers'
  type Cell = string | number | null | undefined
  interface Table {
    file: string
    head: string[]
    rows: Cell[][]
  }

  const PER_PAGE = 50
  const SETS: { key: Key; en: string; ne: string; icon: string; dated: boolean }[] = [
    { key: 'sales', en: 'Sales', ne: 'बिक्री', icon: 'receipt_long', dated: true },
    { key: 'purchases', en: 'Purchases', ne: 'खरिद', icon: 'shopping_bag', dated: true },
    { key: 'payments', en: 'Payments', ne: 'भुक्तानी', icon: 'payments', dated: true },
    { key: 'expenses', en: 'Expenses', ne: 'खर्च', icon: 'paid', dated: true },
    { key: 'items', en: 'Items', ne: 'सामान', icon: 'inventory_2', dated: false },
    { key: 'customers', en: 'Customers', ne: 'ग्राहक', icon: 'group', dated: false },
  ]

  const first = rangeFor('month')
  let from = $state(first.from)
  let to = $state(first.to)
  let picked = $state<Record<Key, boolean>>({ sales: true, purchases: false, payments: false, expenses: false, items: false, customers: false })
  let status = $state('')
  let pct = $state(0)
  const job = action()

  const anyPicked = $derived(SETS.some((s) => picked[s.key]))

  const adDay = (v: string | null | undefined): string => (v ? (v.length > 10 ? adOfStamp(v) : v.slice(0, 10)) : '')
  const bsDay = (v: string | null | undefined): string => {
    const ad = adDay(v)
    if (!ad) return ''
    const b = adToBs(ad)
    return `${monthName(b.month, false)} ${b.day}, ${b.year}`
  }
  const rupees = (p: number | null | undefined): string => (p === null || p === undefined ? '' : fromPaisa(p))

  async function collect<T>(label: string, path: string, query: Record<string, string>, stopWhen?: (rows: T[]) => boolean): Promise<T[]> {
    const out: T[] = []
    let page = 1
    let last = 1
    do {
      const res = await api.page<T>(path, { ...query, per_page: PER_PAGE, page })
      out.push(...res.data)
      last = res.meta.last_page ?? res.meta.current_page
      status = `${label}: ${tr(`page ${num(page)} of ${num(last)}`, `पृष्ठ ${num(page)} / ${num(last)}`)}`
      pct = Math.round((page / last) * 100)
      if (stopWhen?.(res.data)) break
      page++
    } while (page <= last && page <= 200)
    return out
  }

  function toCsv(t: Table): string {
    return [t.head, ...t.rows].map((r) => r.map(csvCell).join(',')).join('\r\n')
  }

  async function build(key: Key, label: string): Promise<Table> {
    const span = `${from}-to-${to}`
    if (key === 'sales') {
      const rows = await collect<Sale>(label, '/sales', { from, to })
      return {
        file: `pasal-sales-${span}.csv`,
        head: ['Bill no', 'Date (AD)', 'Date (BS)', 'Customer', 'Sold by', 'Subtotal', 'Discount', 'VAT', 'Total', 'Returned', 'Paid', 'Balance', 'Cancelled'],
        rows: rows.map((s) => [s.bill_no ?? s.id, adDay(s.sold_at), bsDay(s.sold_at), s.customer?.name ?? '', s.sold_by ?? '', rupees(s.subtotal), rupees(s.discount), rupees(s.vat_amount), rupees(s.total), rupees(s.returned_total), rupees(s.paid), rupees(s.balance), s.cancelled_at ? 'Yes' : 'No']),
      }
    }
    if (key === 'purchases') {
      const rows = await collect<Purchase>(label, '/purchases', { from, to })
      return {
        file: `pasal-purchases-${span}.csv`,
        head: ['Bill no', 'Bill date (AD)', 'Bought on (AD)', 'Bought on (BS)', 'Supplier', 'Total', 'VAT', 'Paid', 'Balance'],
        rows: rows.map((p) => [p.bill_no ?? p.id, adDay(p.bill_date), adDay(p.bought_at), bsDay(p.bought_at), p.supplier?.name ?? '', rupees(p.total), rupees(p.vat_amount), rupees(p.paid), rupees(p.balance)]),
      }
    }
    if (key === 'payments') {
      const rows = await collect<Payment>(label, '/payments', { from, to })
      return {
        file: `pasal-payments-${span}.csv`,
        head: ['Paid on (AD)', 'Paid on (BS)', 'Direction', 'Party', 'Method', 'Amount', 'Sale ID', 'Purchase ID'],
        rows: rows.map((p) => [adDay(p.paid_at), bsDay(p.paid_at), p.direction, p.party ?? '', p.method, rupees(p.amount), p.sale_id, p.purchase_id]),
      }
    }
    if (key === 'expenses') {
      // Newest first. Stop fetching once a page reaches dates before `from`.
      const all = await collect<Expense>(label, '/expenses', {}, (rows) => rows.some((r) => adDay(r.spent_at) < from))
      const rows = all.filter((r) => adDay(r.spent_at) >= from && adDay(r.spent_at) <= to)
      return {
        file: `pasal-expenses-${span}.csv`,
        head: ['Date (AD)', 'Date (BS)', 'Title', 'Category', 'Amount'],
        rows: rows.map((e) => [adDay(e.spent_at), bsDay(e.spent_at), e.title, e.category ?? '', rupees(e.amount)]),
      }
    }
    if (key === 'items') {
      const rows = await collect<Item>(label, '/items', {})
      return {
        file: `pasal-items-${todayAd()}.csv`,
        head: ['Name', 'SKU', 'Unit', 'Sell price', 'Buying price', 'Quantity', 'Low stock at', 'VAT applies'],
        rows: rows.map((i) => [i.name, i.sku ?? '', i.unit, rupees(i.sell_price), rupees(i.cost_price), i.quantity, i.low_stock_at, i.vat_applies ? 'Yes' : 'No']),
      }
    }
    const rows = await collect<Customer>(label, '/customers', {})
    return {
      file: `pasal-customers-${todayAd()}.csv`,
      head: ['Name', 'Phone', 'Address', 'PAN', 'Credit limit', 'Owes', 'Last sale (AD)', 'Last sale (BS)'],
      rows: rows.map((c) => [c.name, c.phone ?? '', c.address ?? '', c.pan ?? '', rupees(c.credit_limit), rupees(c.owes ?? 0), adDay(c.last_sale_at), bsDay(c.last_sale_at)]),
    }
  }

  async function download(): Promise<void> {
    await job.run(async () => {
      const tables: Table[] = []
      for (const s of SETS) {
        if (!picked[s.key]) continue
        pct = 0
        tables.push(await build(s.key, tr(s.en, s.ne)))
      }
      for (const t of tables) downloadText(t.file, toCsv(t))
      status = tr('Done. The files are in your downloads.', 'सकियो। फाइलहरू डाउनलोडमा छन्।')
      pct = 100
    })
  }
</script>

<div class="page narrow">
  <div class="section-title"><h3>{tr('Date range', 'मिति दायरा')}</h3></div>
  <RangePicker bind:from bind:to />

  <div class="section-title"><h3>{tr('Choose lists', 'सूची छान्नुहोस्')}</h3></div>
  <div class="list">
    {#each SETS as s (s.key)}
      <label class="row">
        <span class="icon-tile"><span class="ms">{s.icon}</span></span>
        <div class="row-main">
          <div class="row-title">{tr(s.en, s.ne)}</div>
          {#if !s.dated}<div class="row-sub">{tr('Whole list, not by date', 'सबै सूची, मितिअनुसार होइन')}</div>{/if}
        </div>
        <span class="switch"><input type="checkbox" bind:checked={picked[s.key]} /><span></span></span>
      </label>
    {/each}
  </div>

  {#if job.message}
    <div class="alert bad"><span class="ms">error</span><div>{job.message}</div></div>
  {/if}

  {#if job.busy}
    <div class="stack-sm">
      <span class="small">{status}</span>
      <div class="progress" style="--w:{pct}%"><span></span></div>
    </div>
  {:else if status}
    <span class="small muted">{status}</span>
  {/if}

  <div class="alert">
    <span class="ms">info</span>
    <div>{tr('Excel and PDF are not built yet. Each list you pick downloads as its own CSV file. Open it in Excel or Google Sheets. Items and customers always give the whole list.', 'एक्सेल र PDF अहिले बनेको छैन। छानिएको हरेक सूची आफ्नै CSV फाइलमा डाउनलोड हुन्छ। यसलाई एक्सेल वा गुगल सिटमा खोल्नुहोस्। सामान र ग्राहक सधैँ पूरा सूची हुन्।')}</div>
  </div>

  <div class="bottom-bar">
    <button class="btn btn-primary btn-lg btn-block" disabled={job.busy || !anyPicked || !from || !to} onclick={download}>
      <span class="ms">download</span><span>{job.busy ? tr('Downloading…', 'डाउनलोड हुँदैछ…') : tr('Download CSV', 'CSV डाउनलोड गर्नुहोस्')}</span>
    </button>
  </div>
</div>
