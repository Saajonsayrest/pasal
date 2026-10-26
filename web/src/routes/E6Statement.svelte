<script lang="ts">
  import { api } from '../lib/api'
  import { resource } from '../lib/resource.svelte'
  import { session } from '../lib/session.svelte'
  import { tr } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { adOfStamp, bsMonthRange, bsToAd, formatDate, formatDateSub, shiftMonth, todayAd, todayBs } from '../lib/bs'
  import { whatsappHref } from '../lib/util'
  import type { CustomerLedger } from '../lib/types'
  import BsDatePicker from '../components/BsDatePicker.svelte'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'

  let { params }: { params: Record<string, string> } = $props()

  const METHODS: Record<string, [string, string]> = {
    cash: ['Cash', 'नगद'],
    qr: ['QR', 'QR'],
    bank: ['Bank', 'बैंक'],
    esewa: ['eSewa', 'eSewa'],
    khalti: ['Khalti', 'Khalti'],
  }

  type Preset = 'month' | 'last' | 'three' | 'year' | 'all'
  const PRESETS: { key: Preset; en: string; ne: string }[] = [
    { key: 'month', en: 'This month', ne: 'यो महिना' },
    { key: 'last', en: 'Last month', ne: 'अघिल्लो महिना' },
    { key: 'three', en: 'Last 3 months', ne: 'पछिल्ला ३ महिना' },
    { key: 'year', en: 'This year', ne: 'यो वर्ष' },
    { key: 'all', en: 'All', ne: 'सबै' },
  ]

  const res = resource(() => api.get<CustomerLedger>(`/customers/${params.id}/ledger`))
  const data = $derived(res.data)
  const customer = $derived(data?.customer)
  const phone = $derived(customer?.phone?.trim() ?? '')
  const shop = $derived(session.business?.name ?? 'PASAL')

  type Kind = 'given' | 'received' | 'refund'
  interface Event {
    key: string
    at: string
    day: string
    kind: Kind
    amount: number
    /** Change to what the customer owes: + for more owed, - for money in. */
    delta: number
    detail: string
  }

  const events = $derived.by<Event[]>(() => {
    if (!data) return []
    const billOf = new Map<number, string | null>(data.sales.map((s) => [s.id, s.bill_no]))
    const out: Event[] = []
    for (const s of data.sales) {
      const net = s.total - s.returned_total
      const b = s.bill_no ?? ''
      out.push({
        key: `sale-${s.id}`,
        at: s.sold_at,
        day: adOfStamp(s.sold_at),
        kind: 'given',
        amount: net,
        delta: net,
        detail: s.cancelled_at !== null ? tr(`Cancelled sale ${b}`, `${b} रद्द`) : tr(`Sale ${b}`.trim(), `बिक्री ${b}`.trim()),
      })
    }
    for (const p of data.payments) {
      if (p.direction === 'out') continue
      const b = p.sale_id !== null ? (billOf.get(p.sale_id) ?? '') : ''
      const m = METHODS[p.method] ? tr(METHODS[p.method][0], METHODS[p.method][1]) : p.method
      if (p.direction === 'refund') {
        out.push({ key: `pay-${p.id}`, at: p.paid_at, day: adOfStamp(p.paid_at), kind: 'refund', amount: p.amount, delta: p.amount, detail: tr(`Refunded ${b}`.trim(), `${b} फिर्ता`.trim()) })
      } else {
        out.push({
          key: `pay-${p.id}`,
          at: p.paid_at,
          day: adOfStamp(p.paid_at),
          kind: 'received',
          amount: p.amount,
          delta: -p.amount,
          detail: tr(`Paid ${m}${b ? ` for ${b}` : ''}`, `${m} बाट ${b ? `${b} को ` : ''}भुक्तानी`),
        })
      }
    }
    return out
  })

  const earliest = $derived(events.length ? events.reduce((min, e) => (e.day < min ? e.day : min), events[0].day) : todayAd())
  const today = todayAd()
  const bs = todayBs()

  function presetRange(key: Preset): { from: string; to: string } {
    if (key === 'month') return { from: bsMonthRange(bs.year, bs.month).from, to: today }
    if (key === 'last') {
      const m = shiftMonth(bs.year, bs.month, -1)
      return bsMonthRange(m.year, m.month)
    }
    if (key === 'three') {
      const m = shiftMonth(bs.year, bs.month, -2)
      return { from: bsMonthRange(m.year, m.month).from, to: today }
    }
    if (key === 'year') return { from: bsToAd(bs.year, 1, 1), to: today }
    return { from: earliest, to: today }
  }

  let from = $state(presetRange('month').from)
  let to = $state(today)

  const activePreset = $derived(PRESETS.find((p) => {
    const r = presetRange(p.key)
    return r.from === from && r.to === to
  })?.key ?? null)

  function setPreset(key: Preset): void {
    const r = presetRange(key)
    from = r.from
    to = r.to
  }

  const inRange = (day: string): boolean => day >= from && day <= to
  const opening = $derived(events.filter((e) => e.day < from).reduce((sum, e) => sum + e.delta, 0))
  const inPeriod = $derived(events.filter((e) => inRange(e.day)).sort((a, b) => Date.parse(a.at) - Date.parse(b.at)))
  const rows = $derived.by(() => {
    let balance = opening
    return inPeriod.map((e) => {
      balance += e.delta
      return { ...e, balance }
    })
  })
  const closing = $derived(rows.length ? rows[rows.length - 1].balance : opening)
  const totalGiven = $derived(inPeriod.filter((e) => e.kind !== 'received').reduce((sum, e) => sum + e.amount, 0))
  const totalReceived = $derived(inPeriod.filter((e) => e.kind === 'received').reduce((sum, e) => sum + e.amount, 0))

  const truncated = $derived(data ? data.sales.length >= 200 || data.payments.length >= 200 : false)
  const name = $derived(customer?.name ?? '')
  const badRange = $derived(from > to)

  const shareText = $derived(
    tr(
      `Statement from ${shop} for ${name}, ${formatDate(from)} to ${formatDate(to)}. Balance: ${rs(closing)}.`,
      `${shop} बाट ${name} को हिसाब विवरण, ${formatDate(from)} देखि ${formatDate(to)} सम्म। बाँकी: ${rs(closing)}।`,
    ),
  )
</script>

<div class="page narrow">
  {#if res.error}
    <ErrorCard error={res.error} retry={res.reload} />
  {:else if res.loading && !data}
    <Skeleton card />
    <Skeleton rows={4} />
  {:else if data}
    <div class="chips no-print">
      {#each PRESETS as p}
        <button class="chip" class:active={activePreset === p.key} onclick={() => setPreset(p.key)}>{tr(p.en, p.ne)}</button>
      {/each}
    </div>

    <div class="grid-2 no-print">
      <BsDatePicker bind:value={from} label={tr('From', 'देखि')} max={to} />
      <BsDatePicker bind:value={to} label={tr('To', 'सम्म')} min={from} />
    </div>

    {#if badRange}
      <div class="alert bad no-print"><span class="ms">error</span><div>{tr('The start date is after the end date.', 'सुरु मिति अन्तिम मितिभन्दा पछि छ।')}</div></div>
    {/if}

    <section class="card" style="padding:20px">
      <div class="hstack between" style="align-items:flex-start">
        <div class="stack-sm" style="gap:2px">
          <span class="bold">{shop}</span>
          {#if session.business?.pan}
            <span class="tiny muted">PAN {session.business.pan}</span>
          {/if}
          {#if session.business?.address || session.business?.phone}
            <span class="tiny muted">{[session.business?.address, session.business?.phone].filter(Boolean).join(' · ')}</span>
          {/if}
        </div>
        <span class="badge primary">{tr('Statement', 'हिसाब विवरण')}</span>
      </div>
      <div class="divider"></div>
      <div class="stack-sm" style="gap:2px">
        <span class="small muted">{tr('Customer', 'ग्राहक')}</span>
        <span><span class="bold">{name}</span> {#if phone}<span class="small muted">{phone}</span>{/if}</span>
        {#if customer?.pan}<span class="small muted">PAN {customer.pan}</span>{/if}
        <span class="small muted">
          {tr(`${formatDate(from)} to ${formatDate(to)}`, `${formatDate(from)} देखि ${formatDate(to)} सम्म`)}
        </span>
      </div>
    </section>

    {#if truncated}
      <div class="alert warn no-print">
        <span class="ms">warning</span>
        <div>{tr('This shows only the latest 200 bills or payments. Older records may be missing, so the opening balance may be wrong.', 'यहाँ पछिल्ला २०० बिल वा भुक्तानी मात्र देखिन्छ। पुराना रेकर्ड नहुन सक्छ, त्यसैले शुरु बाँकी गलत हुन सक्छ।')}</div>
      </div>
    {/if}

    <div class="table-wrap">
      <table class="table">
        <thead>
          <tr>
            <th>{tr('Date', 'मिति')}</th>
            <th>{tr('Details', 'विवरण')}</th>
            <th class="r">{tr('Given', 'दिइएको')}</th>
            <th class="r">{tr('Received', 'पाइएको')}</th>
            <th class="r">{tr('Balance', 'बाँकी')}</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td colspan="4">{tr('Opening balance', 'शुरु बाँकी')} ({formatDate(from)})</td>
            <td class="r"><span class="amount">{rs(opening)}</span></td>
          </tr>
          {#each rows as r (r.key)}
            <tr>
              <td>
                {formatDate(r.day)}<br /><span class="tiny muted">{formatDateSub(r.day)}</span>
              </td>
              <td>{r.detail}</td>
              <td class="r">{r.kind === 'received' ? '–' : rs(r.amount)}</td>
              <td class="r">{r.kind === 'received' ? rs(r.amount) : '–'}</td>
              <td class="r"><span class="amount">{rs(r.balance)}</span></td>
            </tr>
          {:else}
            <tr>
              <td colspan="5" class="center muted">{tr('No bills or payments in this period.', 'यो अवधिमा बिल वा भुक्तानी छैन।')}</td>
            </tr>
          {/each}
          <tr>
            <td colspan="2" class="bold">{tr('Total', 'जम्मा')}</td>
            <td class="r"><span class="amount warn">{rs(totalGiven)}</span></td>
            <td class="r"><span class="amount good">{rs(totalReceived)}</span></td>
            <td class="r"></td>
          </tr>
          <tr>
            <td colspan="4" class="bold">{tr('Closing balance', 'बन्द बाँकी')}</td>
            <td class="r"><span class="amount warn">{rs(closing)}</span></td>
          </tr>
        </tbody>
      </table>
    </div>
    <p class="tiny muted">{tr('Returns are taken off on the day of the bill.', 'फिर्ता बिलको मितिमा घटाइन्छ।')}</p>

    <div class="bottom-bar no-print">
      <button class="btn btn-outline btn-lg" style="flex:1" onclick={() => window.print()}>
        <span class="ms">picture_as_pdf</span><span>{tr('Print / Save as PDF', 'प्रिन्ट / PDF सेभ')}</span>
      </button>
      <a
        class="btn btn-good btn-lg"
        style="flex:1"
        target="_blank"
        rel="noopener"
        href={phone ? whatsappHref(phone, shareText) : `https://wa.me/?text=${encodeURIComponent(shareText)}`}
      >
        <span class="ms">chat</span><span>{tr('Share on WhatsApp', 'व्हाट्सएपमा साझा')}</span>
      </a>
    </div>
  {/if}
</div>
