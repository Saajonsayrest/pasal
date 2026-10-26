<script lang="ts">
  import { api } from '../lib/api'
  import { resource, action } from '../lib/resource.svelte'
  import { tr, num, digits } from '../lib/i18n'
  import { adOfStamp, bsMonthRange, formatDate, formatDateSub, periodLabel, todayBs } from '../lib/bs'
  import { csvCell, downloadText } from '../lib/util'
  import type { Purchase, Sale } from '../lib/types'
  import { errorText, plainAmount } from '../lib/vat'
  import MonthNav from '../components/MonthNav.svelte'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Empty from '../components/Empty.svelte'

  type Tab = 'sales' | 'purchase'
  let tab = $state<Tab>('sales')
  let year = $state(todayBs().year)
  let month = $state(todayBs().month)
  const range = $derived(bsMonthRange(year, month))
  const label = $derived(periodLabel(year, month))
  const PER_PAGE = 50

  const sales = resource(() => api.page<Sale>('/sales', { from: range.from, to: range.to, per_page: PER_PAGE }))
  const purchases = resource(() => api.page<Purchase>('/purchases', { from: range.from, to: range.to, per_page: PER_PAGE }))

  let salesExtra = $state<Sale[]>([])
  let salesPage = $state(1)
  let purchaseExtra = $state<Purchase[]>([])
  let purchasePage = $state(1)
  const moreSales = action()
  const morePurchases = action()

  $effect(() => {
    void range.from
    salesExtra = []
    salesPage = 1
    purchaseExtra = []
    purchasePage = 1
  })

  async function loadMoreSales(): Promise<void> {
    const { from, to } = range
    const next = salesPage + 1
    const res = await moreSales.run(() => api.page<Sale>('/sales', { from, to, per_page: PER_PAGE, page: next }))
    if (!res || from !== range.from) return
    salesExtra = [...salesExtra, ...res.data]
    salesPage = next
  }

  async function loadMorePurchases(): Promise<void> {
    const { from, to } = range
    const next = purchasePage + 1
    const res = await morePurchases.run(() => api.page<Purchase>('/purchases', { from, to, per_page: PER_PAGE, page: next }))
    if (!res || from !== range.from) return
    purchaseExtra = [...purchaseExtra, ...res.data]
    purchasePage = next
  }

  const salesRows = $derived([...(sales.data?.data ?? []), ...salesExtra])
  const salesTotal = $derived(sales.data?.meta.total ?? 0)
  const salesHasMore = $derived(sales.data !== undefined && salesPage < (sales.data.meta.last_page ?? 1))
  const salesSum = $derived(
    salesRows.reduce(
      (t, s) => ({
        taxable: t.taxable + s.taxable_amount,
        vat: t.vat + s.vat_amount,
        exempt: t.exempt + s.exempt_amount,
        total: t.total + s.total,
      }),
      { taxable: 0, vat: 0, exempt: 0, total: 0 },
    ),
  )

  const purchaseRows = $derived([...(purchases.data?.data ?? []), ...purchaseExtra])
  const purchaseTotal = $derived(purchases.data?.meta.total ?? 0)
  const purchaseHasMore = $derived(purchases.data !== undefined && purchasePage < (purchases.data.meta.last_page ?? 1))
  const purchaseSum = $derived(
    purchaseRows.reduce(
      (t, p) => ({
        taxable: t.taxable + (p.total - p.vat_amount),
        vat: t.vat + p.vat_amount,
        total: t.total + p.total,
      }),
      { taxable: 0, vat: 0, total: 0 },
    ),
  )

  const amt = (paisa: number): string => digits(plainAmount(paisa))
  const walkIn = () => tr('Walk-in customer', 'पसलमा आएका ग्राहक')

  const csv = action()

  function csvText(header: string[], lines: (string | number)[][]): string {
    return [header, ...lines].map((cells) => cells.map(csvCell).join(',')).join('\r\n')
  }

  async function downloadCsv(): Promise<void> {
    const { from, to } = range
    await csv.run(async () => {
      if (tab === 'sales') {
        const all = await api.all<Sale>('/sales', { from, to })
        const text = csvText(
          ['Date', 'Bill no', 'Buyer', 'Buyer PAN', 'Taxable', 'VAT', 'Exempt', 'Total', 'Cancelled'],
          all.map((s) => [
            adOfStamp(s.sold_at),
            s.bill_no ?? '',
            s.customer?.name ?? 'Walk-in customer',
            s.customer?.pan ?? '',
            plainAmount(s.taxable_amount, false),
            plainAmount(s.vat_amount, false),
            plainAmount(s.exempt_amount, false),
            plainAmount(s.total, false),
            s.cancelled_at ? 'Yes' : 'No',
          ]),
        )
        downloadText(`sales-book-${label}.csv`, text)
      } else {
        const all = await api.all<Purchase>('/purchases', { from, to })
        const text = csvText(
          ['Date', 'Bill no', 'Seller', 'Seller PAN', 'Taxable', 'VAT', 'Total'],
          all.map((p) => [
            p.bill_date ?? adOfStamp(p.bought_at),
            p.bill_no ?? '',
            p.supplier?.name ?? '',
            p.supplier?.pan ?? '',
            plainAmount(p.total - p.vat_amount, false),
            plainAmount(p.vat_amount, false),
            plainAmount(p.total, false),
          ]),
        )
        downloadText(`purchase-book-${label}.csv`, text)
      }
    })
  }
</script>

<div class="page">
  <MonthNav bind:year bind:month />

  <div class="seg block">
    <button class:active={tab === 'sales'} onclick={() => (tab = 'sales')}>{tr('Sales book', 'बिक्री खाता')}</button>
    <button class:active={tab === 'purchase'} onclick={() => (tab = 'purchase')}>{tr('Purchase book', 'खरिद खाता')}</button>
  </div>

  {#if tab === 'sales'}
    {#if sales.error}
      <ErrorCard error={sales.error} retry={sales.reload} />
    {:else if sales.loading && !sales.data}
      <Skeleton rows={6} />
    {:else if salesRows.length === 0}
      <Empty icon="receipt_long" title={tr('No sales bills this month', 'यो महिनामा बिक्री बिल छैन')} />
    {:else}
      <p class="small muted">{tr(`Showing ${salesRows.length} of ${salesTotal} sales bills`, `${num(salesTotal)} मध्ये ${num(salesRows.length)} बिक्री बिल देखाइएको`)}</p>

      <div class="table-wrap wide-only">
        <table class="table">
          <thead>
            <tr>
              <th>{tr('Date', 'मिति')}</th>
              <th>{tr('Bill no', 'बिल नम्बर')}</th>
              <th>{tr('Buyer', 'ग्राहक')}</th>
              <th>{tr('PAN', 'प्यान')}</th>
              <th class="r">{tr('Taxable', 'करयोग्य')}</th>
              <th class="r">{tr('VAT', 'भ्याट')}</th>
              <th class="r">{tr('Exempt', 'करमुक्त')}</th>
              <th class="r">{tr('Total', 'जम्मा')}</th>
            </tr>
          </thead>
          <tbody>
            {#each salesRows as s (s.id)}
              <tr>
                <td><div>{formatDate(s.sold_at)}</div><div class="tiny muted">{formatDateSub(s.sold_at)}</div></td>
                <td>{digits(s.bill_no ?? '-')}</td>
                <td>
                  {s.customer?.name ?? walkIn()}
                  {#if s.cancelled_at}<span class="badge bad">{tr('Cancelled', 'रद्द भएको')}</span>{/if}
                </td>
                <td>{digits(s.customer?.pan ?? '-')}</td>
                <td class="r">{amt(s.taxable_amount)}</td>
                <td class="r">{amt(s.vat_amount)}</td>
                <td class="r">{amt(s.exempt_amount)}</td>
                <td class="r">{amt(s.total)}</td>
              </tr>
            {/each}
            <tr>
              <td colspan="4" class="bold">{tr('Total shown', 'देखाइएका बिलको जम्मा')}</td>
              <td class="r bold">{amt(salesSum.taxable)}</td>
              <td class="r bold">{amt(salesSum.vat)}</td>
              <td class="r bold">{amt(salesSum.exempt)}</td>
              <td class="r bold">{amt(salesSum.total)}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="list phone-only">
        {#each salesRows as s (s.id)}
          <div class="row">
            <div class="row-main">
              <div class="row-title">
                <span>{digits(s.bill_no ?? '-')}</span> · {s.customer?.name ?? walkIn()}
                {#if s.cancelled_at}<span class="badge bad">{tr('Cancelled', 'रद्द भएको')}</span>{/if}
              </div>
              <div class="row-sub">{formatDate(s.sold_at)}</div>
            </div>
            <div class="row-end">
              <span class="amount">{amt(s.total)}</span>
              <span class="tiny muted"><span>{tr('VAT', 'भ्याट')}</span> {amt(s.vat_amount)}</span>
            </div>
          </div>
        {/each}
      </div>

      <p class="tiny muted">{tr(
        'Cancelled sales stay in this book. Returns and cancels count on the day they happened in the VAT numbers, so the totals here can differ.',
        'रद्द भएका बिक्री यस खातामा रहन्छन्। फिर्ता र रद्दको भ्याट अंकमा त्यो दिन गनिन्छ, त्यसैले यहाँको जम्मा फरक हुन सक्छ।',
      )}</p>

      {#if moreSales.error}
        <div class="alert bad"><span class="ms">error</span><div>{errorText(moreSales.error)}</div></div>
      {/if}
      {#if salesHasMore}
        <div class="hstack" style="justify-content:center">
          <button class="btn btn-tonal" onclick={loadMoreSales} disabled={moreSales.busy}>
            {moreSales.busy ? tr('Loading…', 'लोड हुँदैछ…') : tr('Load more', 'अरू हेर्ने')}
          </button>
        </div>
      {/if}
    {/if}
  {:else}
    {#if purchases.error}
      <ErrorCard error={purchases.error} retry={purchases.reload} />
    {:else if purchases.loading && !purchases.data}
      <Skeleton rows={6} />
    {:else if purchaseRows.length === 0}
      <Empty icon="receipt_long" title={tr('No purchase bills this month', 'यो महिनामा खरिद बिल छैन')} />
    {:else}
      <p class="small muted">{tr(`Showing ${purchaseRows.length} of ${purchaseTotal} purchase bills`, `${num(purchaseTotal)} मध्ये ${num(purchaseRows.length)} खरिद बिल देखाइएको`)}</p>

      <div class="table-wrap wide-only">
        <table class="table">
          <thead>
            <tr>
              <th>{tr('Date', 'मिति')}</th>
              <th>{tr('Bill no', 'बिल नम्बर')}</th>
              <th>{tr('Seller', 'डिलर')}</th>
              <th>{tr('PAN', 'प्यान')}</th>
              <th class="r">{tr('Taxable', 'करयोग्य')}</th>
              <th class="r">{tr('VAT', 'भ्याट')}</th>
              <th class="r">{tr('Total', 'जम्मा')}</th>
            </tr>
          </thead>
          <tbody>
            {#each purchaseRows as p (p.id)}
              <tr>
                <td><div>{formatDate(p.bill_date ?? p.bought_at)}</div><div class="tiny muted">{formatDateSub(p.bill_date ?? p.bought_at)}</div></td>
                <td>{digits(p.bill_no ?? '-')}</td>
                <td>{p.supplier?.name ?? '-'}</td>
                <td>{digits(p.supplier?.pan ?? '-')}</td>
                <td class="r">{amt(p.total - p.vat_amount)}</td>
                <td class="r">{amt(p.vat_amount)}</td>
                <td class="r">{amt(p.total)}</td>
              </tr>
            {/each}
            <tr>
              <td colspan="4" class="bold">{tr('Total shown', 'देखाइएका बिलको जम्मा')}</td>
              <td class="r bold">{amt(purchaseSum.taxable)}</td>
              <td class="r bold">{amt(purchaseSum.vat)}</td>
              <td class="r bold">{amt(purchaseSum.total)}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="list phone-only">
        {#each purchaseRows as p (p.id)}
          <div class="row">
            <div class="row-main">
              <div class="row-title"><span>{digits(p.bill_no ?? '-')}</span> · {p.supplier?.name ?? '-'}</div>
              <div class="row-sub">{formatDate(p.bill_date ?? p.bought_at)}</div>
            </div>
            <div class="row-end">
              <span class="amount">{amt(p.total)}</span>
              <span class="tiny muted"><span>{tr('VAT', 'भ्याट')}</span> {amt(p.vat_amount)}</span>
            </div>
          </div>
        {/each}
      </div>

      {#if morePurchases.error}
        <div class="alert bad"><span class="ms">error</span><div>{errorText(morePurchases.error)}</div></div>
      {/if}
      {#if purchaseHasMore}
        <div class="hstack" style="justify-content:center">
          <button class="btn btn-tonal" onclick={loadMorePurchases} disabled={morePurchases.busy}>
            {morePurchases.busy ? tr('Loading…', 'लोड हुँदैछ…') : tr('Load more', 'अरू हेर्ने')}
          </button>
        </div>
      {/if}
    {/if}
  {/if}

  {#if csv.error}
    <div class="alert bad"><span class="ms">error</span><div>{errorText(csv.error)}</div></div>
  {/if}

  <div class="bottom-bar">
    <button class="btn btn-primary btn-lg btn-block" onclick={downloadCsv} disabled={csv.busy}>
      <span class="ms">download</span><span>{csv.busy ? tr('Preparing…', 'तयार हुँदैछ…') : tr('Download CSV', 'CSV डाउनलोड गर्ने')}</span>
    </button>
  </div>
</div>
