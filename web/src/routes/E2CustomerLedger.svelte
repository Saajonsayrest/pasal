<script lang="ts">
  import { api } from '../lib/api'
  import { resource } from '../lib/resource.svelte'
  import { tr, num, plural } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { adOfStamp, daysUntil, formatDate, formatTime, todayAd } from '../lib/bs'
  import { setTitle } from '../lib/shell.svelte'
  import { navigate } from '../lib/router.svelte'
  import { portal } from '../lib/portal'
  import { initials, telHref } from '../lib/util'
  import type { CustomerLedger } from '../lib/types'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Empty from '../components/Empty.svelte'

  let { params }: { params: Record<string, string> } = $props()

  const METHODS: Record<string, [string, string]> = {
    cash: ['Cash', 'नगद'],
    qr: ['QR', 'QR'],
    bank: ['Bank', 'बैंक'],
    esewa: ['eSewa', 'eSewa'],
    khalti: ['Khalti', 'Khalti'],
  }

  function methodLabel(method: string): string {
    const m = METHODS[method]
    return m ? tr(m[0], m[1]) : method
  }

  const ledger = resource(() => api.get<CustomerLedger>(`/customers/${params.id}/ledger`))
  const data = $derived(ledger.data)
  const customer = $derived(data?.customer)

  $effect(() => {
    if (customer) setTitle(customer.name)
  })

  type Kind = 'given' | 'received' | 'refund'
  interface Entry {
    key: string
    kind: Kind
    at: string
    day: string
    amount: number
    saleId: number | null
    bill: string | null
    returned: number
    method: string
    cancelled: boolean
  }

  const entries = $derived.by<Entry[]>(() => {
    if (!data) return []
    const billOf = new Map<number, string | null>(data.sales.map((s) => [s.id, s.bill_no]))
    const sales = data.sales.map(
      (s): Entry => ({
        key: `sale-${s.id}`,
        kind: 'given',
        at: s.sold_at,
        day: adOfStamp(s.sold_at),
        amount: s.total,
        saleId: s.id,
        bill: s.bill_no,
        returned: s.returned_total,
        method: '',
        cancelled: s.cancelled_at !== null,
      }),
    )
    const payments = data.payments
      .filter((p) => p.direction !== 'out')
      .map(
        (p): Entry => ({
          key: `pay-${p.id}`,
          kind: p.direction === 'refund' ? 'refund' : 'received',
          at: p.paid_at,
          day: adOfStamp(p.paid_at),
          amount: p.amount,
          saleId: p.sale_id,
          bill: p.sale_id !== null ? (billOf.get(p.sale_id) ?? null) : null,
          returned: 0,
          method: p.method,
          cancelled: false,
        }),
      )
    return [...sales, ...payments]
  })

  let filter = $state<'all' | 'given' | 'received'>('all')

  const shown = $derived(
    entries
      .filter((e) => filter === 'all' || (filter === 'given' ? e.kind !== 'received' : e.kind === 'received'))
      .sort((a, b) => Date.parse(b.at) - Date.parse(a.at)),
  )

  const groups = $derived.by(() => {
    const out: { day: string; items: Entry[] }[] = []
    for (const e of shown) {
      const last = out[out.length - 1]
      if (last && last.day === e.day) last.items.push(e)
      else out.push({ day: e.day, items: [e] })
    }
    return out
  })

  function dayLabel(day: string): string {
    return day === todayAd() ? `${tr('Today', 'आज')} · ${formatDate(day)}` : formatDate(day)
  }

  function titleOf(e: Entry): string {
    if (e.kind === 'given') return tr('Given on credit', 'उधारो दिइयो')
    if (e.kind === 'refund') return tr('Refunded', 'फिर्ता दिइयो')
    return `${tr('Received', 'पाइयो')} · ${methodLabel(e.method)}`
  }

  function subOf(e: Entry): string {
    const parts = [
      e.bill,
      formatTime(e.at),
      e.returned > 0 ? tr(`${rs(e.returned)} returned`, `${rs(e.returned)} फिर्ता`) : null,
      e.cancelled ? tr('Cancelled', 'रद्द') : null,
    ]
    return parts.filter(Boolean).join(' · ')
  }

  const owes = $derived(data?.owes ?? 0)
  const limit = $derived(data?.credit_limit ?? null)
  const pct = $derived(limit ? Math.max(0, Math.min(100, Math.round((owes * 100) / limit))) : 0)
  const over = $derived(limit !== null && limit > 0 && owes > limit)

  const oldest = $derived.by(() => {
    const open = (data?.sales ?? []).filter((s) => s.balance > 0 && s.cancelled_at === null)
    return open.reduce<(typeof open)[number] | undefined>((min, s) => (!min || Date.parse(s.sold_at) < Date.parse(min.sold_at) ? s : min), undefined)
  })
  const oldestDays = $derived(oldest ? Math.max(0, -daysUntil(adOfStamp(oldest.sold_at))) : 0)
</script>

{#if data}
  <div use:portal={'#topbar-actions'} class="contents">
    <a class="btn btn-icon" href={`#/customers/${params.id}/edit`} aria-label={tr('Edit customer', 'ग्राहक सच्याउने')}><span class="ms">edit</span></a>
  </div>
{/if}

<div class="page narrow">
  {#if ledger.error}
    <ErrorCard error={ledger.error} retry={ledger.reload} />
  {:else if ledger.loading && !data}
    <Skeleton card />
    <Skeleton rows={4} />
  {:else if data && customer}
    <section class="hero warn">
      <div class="hstack between" style="align-items:flex-start">
        <div class="stat">
          <span class="stat-label">{tr('To collect', 'उठाउन बाँकी')}</span>
          <span class="stat-value xl warn">{rs(owes)}</span>
          {#if oldest}
            <span class="stat-sub">
              {oldestDays === 0
                ? tr('Oldest bill is from today', 'सबैभन्दा पुरानो बिल आजको हो')
                : tr(
                    `Oldest bill is ${num(oldestDays)} ${plural(oldestDays, 'day', 'days')} old`,
                    `सबैभन्दा पुरानो बिल ${num(oldestDays)} दिन अघिको`,
                  )}
            </span>
          {/if}
        </div>
        <span class="avatar warn" style="width:52px;height:52px;font-size:18px">{initials(customer.name)}</span>
      </div>

      {#if limit === 0}
        <div class="hstack between small" style="margin-top:14px">
          <span class="muted">{tr('Credit limit', 'उधारो सीमा')}</span>
          <span class="bold">{tr('Cash only', 'नगद मात्र')}</span>
        </div>
      {:else if limit !== null}
        <div style="margin-top:14px">
          <div class="hstack between small">
            <span class="muted">{tr('Credit limit', 'उधारो सीमा')}</span>
            <span class="bold">{rs(owes)} / {rs(limit)}</span>
          </div>
          <div class="progress {over ? 'bad' : 'warn'}" style="margin-top:6px;--w:{pct}%"><span></span></div>
        </div>
      {/if}
    </section>

    {#if over && limit !== null}
      <div class="alert bad">
        <span class="ms">warning</span>
        <div>{tr(`Over the credit limit by ${rs(owes - limit)}.`, `उधारो सीमाभन्दा ${rs(owes - limit)} बढी छ।`)}</div>
      </div>
    {/if}

    <div class="quick-actions">
      {#if customer.phone}
        <a href={telHref(customer.phone)}><span class="qa-icon"><span class="ms">call</span></span><span>{tr('Call', 'फोन')}</span></a>
      {:else}
        <button disabled><span class="qa-icon"><span class="ms">call</span></span><span>{tr('Call', 'फोन')}</span></button>
      {/if}
      <a href={`#/customers/${params.id}/remind`}><span class="qa-icon"><span class="ms">notifications_active</span></span><span>{tr('Remind', 'सम्झाउने')}</span></a>
      <a href={`#/customers/${params.id}/statement`}><span class="qa-icon"><span class="ms">picture_as_pdf</span></span><span>{tr('Statement', 'विवरण')}</span></a>
      <a href="#/sell"><span class="qa-icon"><span class="ms">add_shopping_cart</span></span><span>{tr('Credit sale', 'उधारो बिक्री')}</span></a>
    </div>

    <div class="grid-2">
      <div class="card tonal stat"><span class="stat-label">{tr('Total bought', 'जम्मा किनेको')}</span><span class="bold num">{rs(data.total_sales)}</span></div>
      <div class="card tonal stat"><span class="stat-label">{tr('Total paid', 'जम्मा तिरेको')}</span><span class="bold num good">{rs(data.total_paid)}</span></div>
      <div class="card tonal stat wide-only"><span class="stat-label">{tr('Phone', 'फोन')}</span><span class="bold num">{customer.phone ?? '-'}</span></div>
    </div>

    <div class="seg block">
      <button class:active={filter === 'all'} onclick={() => (filter = 'all')}>{tr('All', 'सबै')}</button>
      <button class:active={filter === 'given'} onclick={() => (filter = 'given')}>{tr('Given', 'दिइएको')}</button>
      <button class:active={filter === 'received'} onclick={() => (filter = 'received')}>{tr('Received', 'पाइएको')}</button>
    </div>

    {#if entries.length === 0}
      <Empty icon="receipt_long" title={tr('No bills or payments yet', 'अहिलेसम्म बिल वा भुक्तानी छैन')} text={tr('Sell on credit to this customer and it shows here.', 'यो ग्राहकलाई उधारो बिक्री गर्दा यहाँ देखिन्छ।')} />
    {:else if groups.length === 0}
      <p class="muted center">{tr('Nothing in this filter.', 'यो छनोटमा केही छैन।')}</p>
    {:else}
      <div class="ledger">
        {#each groups as group (group.day)}
          <span class="date-sep">{dayLabel(group.day)}</span>
          {#each group.items as e (e.key)}
            {#if e.saleId !== null}
              <a class="entry {e.kind}" href={`#/sales/${e.saleId}`}>
                <div class="e-top"><span class="ms" style="font-size:16px">{e.kind === 'given' ? 'arrow_upward' : e.kind === 'received' ? 'arrow_downward' : 'undo'}</span><span>{titleOf(e)}</span></div>
                <div class="e-amt">{rs(e.amount)}</div>
                <div class="e-sub">{subOf(e)}</div>
              </a>
            {:else}
              <div class="entry {e.kind}">
                <div class="e-top"><span class="ms" style="font-size:16px">{e.kind === 'given' ? 'arrow_upward' : e.kind === 'received' ? 'arrow_downward' : 'undo'}</span><span>{titleOf(e)}</span></div>
                <div class="e-amt">{rs(e.amount)}</div>
                <div class="e-sub">{subOf(e)}</div>
              </div>
            {/if}
          {/each}
        {/each}
      </div>
    {/if}

    <div class="bottom-bar">
      <a class="btn btn-outline btn-lg" href={`#/customers/${params.id}/remind`} style="flex:1"><span class="ms">chat</span><span>{tr('Remind', 'सम्झाउने')}</span></a>
      <button class="btn btn-good btn-lg" style="flex:1.4" disabled={owes <= 0} onclick={() => navigate(`/customers/${params.id}/payment`)}>
        <span class="ms">call_received</span><span>{tr('Take payment', 'भुक्तानी लिने')}</span>
      </button>
    </div>
  {/if}
</div>
