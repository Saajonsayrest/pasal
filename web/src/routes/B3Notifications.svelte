<script lang="ts">
  import { api } from '../lib/api'
  import { resource } from '../lib/resource.svelte'
  import { session } from '../lib/session.svelte'
  import { tr } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { adOfStamp, formatDate, formatTime, monthTitle, todayAd } from '../lib/bs'
  import { dueText, nextVat } from '../lib/home'
  import { portal } from '../lib/portal'
  import { toast } from '../lib/toast.svelte'
  import type { AppNotification, VatPreview } from '../lib/types'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Empty from '../components/Empty.svelte'

  type Filter = 'all' | 'stock' | 'money' | 'vat'
  type Kind = AppNotification['type'] | 'vat_due'

  interface Row {
    key: string
    kind: Kind
    title: string
    body: string
    href: string
    icon: string
    tone: string
    at: string
    time: string
  }

  const SEEN_KEY = 'pasal-notif-seen'
  const FILTER_KINDS: Record<Filter, Kind[]> = {
    all: [],
    stock: ['low_stock'],
    money: ['credit_overdue'],
    vat: ['vat_unfiled', 'vat_due'],
  }

  const today = todayAd()
  const startOfToday = `${today}T00:00:00+05:45`
  const due = nextVat()

  const list = resource(() => api.get<{ data: AppNotification[] }>('/notifications'))
  const preview = resource(async () =>
    session.isOwner && due.daysLeft <= 10
      ? api.get<VatPreview>('/vat/preview', { from: due.from, to: due.to, opening_carry: 0 })
      : null,
  )

  function readSeen(): number {
    try {
      return Date.parse(localStorage.getItem(SEEN_KEY) ?? '') || 0
    } catch {
      return 0
    }
  }

  let seen = $state(readSeen())
  let filter = $state<Filter>('all')

  function hrefFor(kind: AppNotification['type']): string {
    if (kind === 'low_stock') return '#/low-stock'
    if (kind === 'credit_overdue') return session.isOwner ? '#/reports/credit-age' : '#/customers'
    if (kind === 'vat_unfiled') return '#/vat/filings'
    return '#/settings/staff'
  }

  function iconFor(kind: Kind): string {
    if (kind === 'low_stock') return 'production_quantity_limits'
    if (kind === 'credit_overdue') return 'schedule'
    if (kind === 'vat_unfiled' || kind === 'vat_due') return 'receipt_long'
    return 'badge'
  }

  function toneFor(kind: Kind): string {
    if (kind === 'low_stock') return 'warn'
    if (kind === 'credit_overdue') return 'bad'
    if (kind === 'vat_unfiled' || kind === 'vat_due') return 'info'
    return ''
  }

  const rows = $derived.by<Row[]>(() => {
    const out: Row[] = []
    const p = preview.data
    if (session.isOwner && due.daysLeft <= 10) {
      out.push({
        key: 'vat-due',
        kind: 'vat_due',
        title: `${monthTitle(due.year, due.month)} ${tr('VAT', 'भ्याट')} ${dueText(due.daysLeft)}`,
        body: p ? tr(`About ${rs(p.payable)} to pay`, `अनुमानित ${rs(p.payable)} तिर्नुपर्ने`) : formatDate(due.due),
        href: '#/vat',
        icon: iconFor('vat_due'),
        tone: toneFor('vat_due'),
        at: startOfToday,
        time: '',
      })
    }
    const notes = list.data?.data ?? []
    notes.forEach((n, i) => {
      out.push({
        key: `${i}-${n.type}`,
        kind: n.type,
        title: n.title,
        body: n.body,
        href: hrefFor(n.type),
        icon: iconFor(n.type),
        tone: toneFor(n.type),
        at: n.at,
        time: adOfStamp(n.at) === today ? formatTime(n.at) : formatDate(n.at),
      })
    })
    return out
  })

  const shown = $derived(filter === 'all' ? rows : rows.filter((r) => FILTER_KINDS[filter].includes(r.kind)))
  const todayRows = $derived(shown.filter((r) => adOfStamp(r.at) === today))
  const earlierRows = $derived(shown.filter((r) => adOfStamp(r.at) !== today))

  function isUnread(at: string): boolean {
    return Date.parse(at) > seen
  }

  function markAllRead(): void {
    const now = new Date().toISOString()
    try {
      localStorage.setItem(SEEN_KEY, now)
    } catch {
      // Storage can be blocked. The rows stay bold until the page is closed.
    }
    seen = Date.parse(now)
    toast('All marked as read', 'सबै पढिएको चिन्ह लगाइयो')
  }
</script>

<div class="page">
  <div use:portal={'#topbar-actions'} class="contents">
    <button class="btn btn-tonal btn-sm" type="button" onclick={markAllRead}><span class="ms">done_all</span><span>{tr('Mark all as read', 'सबै पढिएको चिन्ह')}</span></button>
  </div>

  <div class="chips">
    {#each [['all', 'All', 'सबै'], ['stock', 'Stock', 'स्टक'], ['money', 'Money', 'पैसा'], ['vat', 'VAT', 'भ्याट']] as [key, en, ne]}
      <button class="chip" class:active={filter === key} type="button" onclick={() => (filter = key as Filter)}>{tr(en, ne)}</button>
    {/each}
  </div>

  {#if list.error}
    <ErrorCard error={list.error} retry={list.reload} />
  {:else if list.loading && !list.data}
    <Skeleton rows={4} />
  {:else if shown.length === 0}
    <Empty icon="notifications_none" title={tr('No notifications', 'कुनै सूचना छैन')} text={tr('Nothing needs your attention right now.', 'अहिले ध्यान दिनुपर्ने केही छैन।')} />
  {:else}
    <div class="list">
      {#if todayRows.length}
        <div class="list-head">{tr('Today', 'आज')}</div>
        {#each todayRows as r (r.key)}
          {@render item(r)}
        {/each}
      {/if}
      {#if earlierRows.length}
        <div class="list-head">{tr('Earlier', 'अघिल्ला')}</div>
        {#each earlierRows as r (r.key)}
          {@render item(r)}
        {/each}
      {/if}
    </div>
  {/if}
</div>

{#snippet item(r: Row)}
  <a class="row" href={r.href}>
    <span class="icon-tile {r.tone}"><span class="ms">{r.icon}</span></span>
    <div class="row-main">
      <div class="row-title" class:bold={isUnread(r.at)}>{r.title}</div>
      <div class="row-sub">{r.body}</div>
    </div>
    <div class="row-end">
      {#if isUnread(r.at)}<span class="dot good" aria-label={tr('Not read yet', 'नपढिएको')}></span>{/if}
      <span class="tiny muted">{r.time}</span>
    </div>
  </a>
{/snippet}
