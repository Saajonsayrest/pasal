<script lang="ts">
  import { api } from '../lib/api'
  import { resource } from '../lib/resource.svelte'
  import { tr, num } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { bsMonthRange, todayAd, todayBs, formatDate, formatTime } from '../lib/bs'
  import type { Payment } from '../lib/types'
  import BsDatePicker from '../components/BsDatePicker.svelte'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Empty from '../components/Empty.svelte'

  type Direction = '' | 'in' | 'out' | 'refund'
  const DIRECTIONS: { value: Direction; en: string; ne: string; icon: string }[] = [
    { value: '', en: 'All', ne: 'सबै', icon: '' },
    { value: 'in', en: 'In', ne: 'पाएको', icon: 'arrow_downward' },
    { value: 'out', en: 'Out', ne: 'तिरेको', icon: 'arrow_upward' },
    { value: 'refund', en: 'Refund', ne: 'फिर्ता', icon: 'undo' },
  ]
  const DIR: Record<Payment['direction'], { en: string; ne: string; icon: string; tone: string }> = {
    in: { en: 'Received', ne: 'पाएको', icon: 'arrow_downward', tone: 'good' },
    out: { en: 'Paid out', ne: 'तिरेको', icon: 'arrow_upward', tone: 'info' },
    refund: { en: 'Refund', ne: 'फिर्ता', icon: 'undo', tone: 'warn' },
  }
  const METHODS: [string, string, string][] = [
    ['', 'All methods', 'सबै तरिका'],
    ['cash', 'Cash', 'नगद'],
    ['qr', 'QR', 'QR'],
    ['bank', 'Bank', 'बैंक'],
    ['card', 'Card', 'कार्ड'],
    ['esewa', 'eSewa', 'eSewa'],
    ['khalti', 'Khalti', 'Khalti'],
  ]
  const methodName = (m: string) => {
    const found = METHODS.find((x) => x[0] === m)
    return found ? tr(found[1], found[2]) : m
  }
  const PER_PAGE = 30

  const now = todayBs()
  const start = bsMonthRange(now.year, now.month).from
  let direction = $state<Direction>('')
  let method = $state('')
  let from = $state(start)
  let to = $state(todayAd())

  let extra = $state<Payment[]>([])
  let page = $state(1)
  let moreBusy = $state(false)
  let moreError = $state<string | null>(null)
  let runKey = ''

  function filters() {
    return { direction: direction || undefined, method: method || undefined, from, to }
  }

  const list = resource(() => {
    const f = filters()
    runKey = JSON.stringify(f)
    extra = []
    page = 1
    moreError = null
    return api.page<Payment>('/payments', { ...f, per_page: PER_PAGE, page: 1 })
  })

  async function loadMore(): Promise<void> {
    const f = filters()
    const key = JSON.stringify(f)
    const next = page + 1
    moreBusy = true
    moreError = null
    try {
      const res = await api.page<Payment>('/payments', { ...f, per_page: PER_PAGE, page: next })
      if (key !== runKey) return
      extra = [...extra, ...res.data]
      page = next
    } catch (e) {
      if (key === runKey) moreError = (e as Error).message
    } finally {
      if (key === runKey) moreBusy = false
    }
  }

  const rows = $derived([...(list.data?.data ?? []), ...extra])
  const total = $derived(list.data?.meta.total ?? 0)
  const hasMore = $derived(rows.length < total)

  const sumOf = (d: Payment['direction']) => rows.reduce((s, p) => (p.direction === d ? s + p.amount : s), 0)
  const received = $derived(sumOf('in'))
  const paidOut = $derived(sumOf('out'))
  const refunded = $derived(sumOf('refund'))

  const linkOf = (p: Payment): string | null => (p.sale_id ? `#/sales/${p.sale_id}` : p.purchase_id ? `#/purchases/${p.purchase_id}` : null)
  const billOf = (p: Payment): string => {
    if (p.sale_id) return `${tr('Sale', 'बिक्री')} #${num(p.sale_id)}`
    if (p.purchase_id) return `${tr('Purchase', 'खरिद')} #${num(p.purchase_id)}`
    return ''
  }
</script>

<div class="page">
  <div class="chips">
    {#each DIRECTIONS as d (d.value)}
      <button class="chip" class:active={direction === d.value} onclick={() => (direction = d.value)}>
        {#if d.icon}<span class="ms">{d.icon}</span>{/if}<span>{tr(d.en, d.ne)}</span>
      </button>
    {/each}
  </div>

  <div class="chips">
    {#each METHODS as m (m[0])}
      <button class="chip" class:active={method === m[0]} onclick={() => (method = m[0])}>{tr(m[1], m[2])}</button>
    {/each}
  </div>

  <div class="grid-2">
    <BsDatePicker bind:value={from} label={tr('From', 'देखि')} max={to} />
    <BsDatePicker bind:value={to} label={tr('To', 'सम्म')} min={from} max={todayAd()} />
  </div>

  {#if list.error}
    <ErrorCard error={list.error} retry={list.reload} />
  {:else if list.loading && !list.data}
    <Skeleton rows={6} />
  {:else}
    <div class="grid-3">
      <div class="card stat">
        <span class="stat-icon good"><span class="ms">arrow_downward</span></span>
        <span class="stat-label">{tr('Received', 'पाएको')}</span>
        <span class="stat-value good">{rs(received)}</span>
      </div>
      <div class="card stat">
        <span class="stat-icon info"><span class="ms">arrow_upward</span></span>
        <span class="stat-label">{tr('Paid out', 'तिरेको')}</span>
        <span class="stat-value">{rs(paidOut)}</span>
      </div>
      <div class="card stat">
        <span class="stat-icon warn"><span class="ms">undo</span></span>
        <span class="stat-label">{tr('Refunds', 'फिर्ता')}</span>
        <span class="stat-value warn">{rs(refunded)}</span>
      </div>
    </div>
    <p class="tiny muted">{tr('Totals of the rows loaded so far', 'अहिलेसम्म लोड भएका रोको जोड')}</p>

    {#if rows.length === 0}
      <Empty icon="payments" title={tr('No payments found', 'भुक्तानी भेटिएन')} text={tr('Try another date range or a different filter.', 'अर्को मिति दायरा वा फिल्टर प्रयास गर्नुहोस्।')} />
    {:else}
      <div class="list phone-only">
        {#each rows as p (p.id)}
          {@const href = linkOf(p)}
          {@const d = DIR[p.direction]}
          <svelte:element this={href ? 'a' : 'div'} class="row" href={href ?? undefined}>
            <span class="icon-tile {d.tone}"><span class="ms">{d.icon}</span></span>
            <div class="row-main">
              <div class="row-title">{p.party ?? tr('No name', 'नाम छैन')}</div>
              <div class="row-sub">{tr(d.en, d.ne)} · {billOf(p)} · {formatDate(p.paid_at)}</div>
            </div>
            <div class="row-end">
              <span class="amount">{rs(p.amount)}</span>
              <span class="badge">{methodName(p.method)}</span>
            </div>
            {#if href}<span class="ms chev">chevron_right</span>{/if}
          </svelte:element>
        {/each}
      </div>

      <div class="table-wrap wide-only">
        <table class="table">
          <thead>
            <tr>
              <th>{tr('Date', 'मिति')}</th>
              <th>{tr('Time', 'समय')}</th>
              <th>{tr('Type', 'प्रकार')}</th>
              <th>{tr('Name', 'नाम')}</th>
              <th>{tr('Bill', 'बिल')}</th>
              <th>{tr('Method', 'तरिका')}</th>
              <th class="r">{tr('Amount', 'रकम')}</th>
            </tr>
          </thead>
          <tbody>
            {#each rows as p (p.id)}
              {@const href = linkOf(p)}
              {@const d = DIR[p.direction]}
              <tr>
                <td>{formatDate(p.paid_at)}</td>
                <td>{formatTime(p.paid_at)}</td>
                <td><span class="badge {d.tone}"><span class="ms">{d.icon}</span><span>{tr(d.en, d.ne)}</span></span></td>
                <td>{p.party ?? ''}</td>
                <td>{#if href}<a href={href}>{billOf(p)}</a>{/if}</td>
                <td>{methodName(p.method)}</td>
                <td class="r">{rs(p.amount)}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>

      <p class="small muted" style="text-align:center">
        {tr(`Showing ${num(rows.length)} of ${num(total)} payments`, `${num(total)} मध्ये ${num(rows.length)} देखाइँदै`)}
      </p>

      {#if moreError}
        <div class="alert bad"><span class="ms">error</span><div>{moreError}</div></div>
      {/if}
      {#if hasMore}
        <button class="btn btn-tonal btn-block" disabled={moreBusy} onclick={loadMore}>
          {moreBusy ? tr('Loading…', 'लोड हुँदैछ…') : tr('Load more', 'थप लोड गर्ने')}
        </button>
      {/if}
    {/if}
  {/if}
</div>
