<script lang="ts">
  import { api } from '../lib/api'
  import { resource } from '../lib/resource.svelte'
  import { tr, num } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { adOfStamp, daysUntil, formatDate } from '../lib/bs'
  import { initials, telHref } from '../lib/util'
  import { setTitle } from '../lib/shell.svelte'
  import type { SupplierLedger } from '../lib/types'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Empty from '../components/Empty.svelte'

  let { params }: { params: Record<string, string> } = $props()

  const ledger = resource(() => api.get<SupplierLedger>(`/suppliers/${params.id}/ledger`))
  const d = $derived(ledger.data)

  $effect(() => {
    if (d) setTitle(d.supplier.name)
  })

  const time = (iso: string): number => Date.parse(iso.replace(/(\.\d{3})\d+/, '$1'))

  type Entry = {
    key: string
    at: string
    kind: 'bought' | 'paid'
    id: number | null
    bill: string | null
    amount: number
    balance: number
    method: string
  }

  function methodText(m: string): string {
    if (m === 'cash') return tr('cash', 'नगद')
    if (m === 'bank') return tr('bank', 'बैंक')
    if (m === 'cheque') return tr('cheque', 'चेक')
    return m || tr('not set', 'छैन')
  }

  const timeline = $derived.by<Entry[]>(() => {
    if (!d) return []
    const bills = new Map(d.purchases.map((p) => [p.id, p.bill_no]))
    const bought: Entry[] = d.purchases.map((p) => ({
      key: `b${p.id}`,
      at: p.bought_at,
      kind: 'bought',
      id: p.id,
      bill: p.bill_no,
      amount: p.total,
      balance: p.balance,
      method: '',
    }))
    const paid: Entry[] = d.payments.map((p) => ({
      key: `p${p.id}`,
      at: p.paid_at,
      kind: 'paid',
      id: p.purchase_id,
      bill: p.purchase_id ? (bills.get(p.purchase_id) ?? null) : null,
      amount: p.amount,
      balance: 0,
      method: p.method,
    }))
    return [...bought, ...paid].sort((a, b) => time(b.at) - time(a.at))
  })

  const days = $derived.by(() => {
    const out: { day: string; items: Entry[] }[] = []
    for (const e of timeline) {
      const day = adOfStamp(e.at)
      const last = out.at(-1)
      if (last && last.day === day) last.items.push(e)
      else out.push({ day, items: [e] })
    }
    return out
  })

  const oldest = $derived.by(() => {
    if (!d) return null
    const open = d.purchases.filter((p) => p.balance > 0)
    if (open.length === 0) return null
    return open.reduce((a, b) => (time(b.bought_at) < time(a.bought_at) ? b : a))
  })
  const oldestAge = $derived(oldest ? Math.max(0, -daysUntil(adOfStamp(oldest.bought_at))) : 0)
</script>

<div class="page narrow">
  {#if ledger.error}
    <ErrorCard error={ledger.error} retry={ledger.reload} />
  {:else if d}
    <section class="hero soft">
      <div class="hstack between" style="align-items:flex-start">
        <div class="stat">
          <span class="stat-label">{tr('We owe', 'हामीले तिर्न बाँकी')}</span>
          <span class="stat-value xl">{rs(d.we_owe)}</span>
          <span class="stat-sub">
            {oldest
              ? tr(`Oldest open bill is ${num(oldestAge)} days old`, `सबैभन्दा पुरानो खुला बिल ${num(oldestAge)} दिन अघिको`)
              : tr('No open bills', 'कुनै बिल बाँकी छैन')}
          </span>
        </div>
        <span class="avatar info" style="width:52px;height:52px;font-size:18px">{initials(d.supplier.name)}</span>
      </div>
    </section>

    <div class="quick-actions">
      {#if d.supplier.phone}
        <a href={telHref(d.supplier.phone)}><span class="qa-icon"><span class="ms">call</span></span><span>{tr('Call', 'फोन')}</span></a>
      {:else}
        <button type="button" disabled><span class="qa-icon"><span class="ms">call</span></span><span>{tr('Call', 'फोन')}</span></button>
      {/if}
      <a href={`#/purchases/new?supplier=${d.supplier.id}`}><span class="qa-icon"><span class="ms">shopping_bag</span></span><span>{tr('New purchase', 'नयाँ खरिद')}</span></a>
      <a href={`#/suppliers/${d.supplier.id}/pay`}><span class="qa-icon"><span class="ms">call_made</span></span><span>{tr('Pay supplier', 'डिलरलाई भुक्तानी')}</span></a>
      <a href={`#/suppliers/${d.supplier.id}/edit`}><span class="qa-icon"><span class="ms">edit</span></span><span>{tr('Edit', 'सच्याउने')}</span></a>
    </div>

    <div class="grid-2">
      <div class="card tonal stat">
        <span class="stat-label">{tr('Total bought', 'जम्मा खरिद')}</span>
        <span class="bold num">{rs(d.total_purchases)}</span>
      </div>
      <div class="card tonal stat">
        <span class="stat-label">{tr('Total paid', 'जम्मा तिरेको')}</span>
        <span class="bold num good">{rs(d.total_paid)}</span>
      </div>
    </div>

    {#if timeline.length === 0}
      <Empty icon="receipt_long" title={tr('No purchases yet', 'अहिलेसम्म खरिद छैन')} text={tr('Buy stock from this supplier to start the ledger.', 'यो डिलरबाट सामान किनेर खाता सुरु गर्नुहोस्।')}>
        <a class="btn btn-primary" href={`#/purchases/new?supplier=${d.supplier.id}`}><span class="ms">shopping_bag</span><span>{tr('New purchase', 'नयाँ खरिद')}</span></a>
      </Empty>
    {:else}
      <div class="ledger">
        {#each days as group (group.day)}
          <span class="date-sep">{formatDate(group.day)}</span>
          {#each group.items as e (e.key)}
            {#if e.kind === 'bought'}
              <a class="entry given" href={`#/purchases/${e.id}`}>
                <div class="e-top">
                  <span class="ms" style="font-size:16px">arrow_upward</span>
                  <span>{e.bill ? tr(`Bought (bill ${e.bill})`, `खरिद (बिल ${e.bill})`) : tr('Bought', 'खरिद')}</span>
                </div>
                <div class="e-amt">{rs(e.amount)}</div>
                <div class="e-sub">
                  {e.balance > 0 ? tr(`Still to pay ${rs(e.balance)}`, `बाँकी ${rs(e.balance)}`) : tr('Paid in full', 'पूरा तिरेको')}
                </div>
              </a>
            {:else if e.id !== null}
              <a class="entry received" href={`#/purchases/${e.id}`}>
                <div class="e-top">
                  <span class="ms" style="font-size:16px">arrow_downward</span>
                  <span>{tr(`Paid · ${methodText(e.method)}`, `भुक्तानी · ${methodText(e.method)}`)}</span>
                </div>
                <div class="e-amt">{rs(e.amount)}</div>
                {#if e.bill}<div class="e-sub">{tr(`For ${e.bill}`, `${e.bill} को लागि`)}</div>{/if}
              </a>
            {:else}
              <div class="entry received">
                <div class="e-top">
                  <span class="ms" style="font-size:16px">arrow_downward</span>
                  <span>{tr(`Paid · ${methodText(e.method)}`, `भुक्तानी · ${methodText(e.method)}`)}</span>
                </div>
                <div class="e-amt">{rs(e.amount)}</div>
              </div>
            {/if}
          {/each}
        {/each}
      </div>
    {/if}
  {:else}
    <Skeleton card />
    <Skeleton rows={4} />
  {/if}
</div>

<style>
  a.entry {
    color: inherit;
    text-decoration: none;
  }
</style>
