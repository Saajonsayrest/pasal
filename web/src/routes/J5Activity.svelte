<script lang="ts">
  import { api } from '../lib/api'
  import { resource } from '../lib/resource.svelte'
  import { tr, num, digits } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { adOfStamp, formatDate, formatTime, todayAd } from '../lib/bs'
  import type { ActivityEntry, User } from '../lib/types'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Empty from '../components/Empty.svelte'

  type Group = 'all' | 'sales' | 'purchases' | 'money' | 'stock' | 'vat'
  const GROUPS: { key: Group; en: string; ne: string; kinds: string[] }[] = [
    { key: 'all', en: 'All', ne: 'सबै', kinds: [] },
    { key: 'sales', en: 'Sales', ne: 'बिक्री', kinds: ['sale', 'return', 'cancel'] },
    { key: 'purchases', en: 'Purchases', ne: 'खरिद', kinds: ['purchase'] },
    { key: 'money', en: 'Money', ne: 'पैसा', kinds: ['payment_in', 'payment_out', 'refund', 'expense'] },
    { key: 'stock', en: 'Stock', ne: 'स्टक', kinds: ['stock_adjust', 'stock_count'] },
    { key: 'vat', en: 'VAT', ne: 'भ्याट', kinds: ['vat_filing'] },
  ]
  const KIND: Record<string, { icon: string; tone: string; en: string; ne: string }> = {
    sale: { icon: 'receipt_long', tone: '', en: 'Sale', ne: 'बिक्री' },
    return: { icon: 'keyboard_return', tone: 'warn', en: 'Return', ne: 'फिर्ता' },
    cancel: { icon: 'cancel', tone: 'bad', en: 'Cancelled sale', ne: 'रद्द बिक्री' },
    purchase: { icon: 'local_shipping', tone: 'info', en: 'Purchase', ne: 'खरिद' },
    payment_in: { icon: 'arrow_downward', tone: 'good', en: 'Money in', ne: 'पैसा आयो' },
    payment_out: { icon: 'arrow_upward', tone: 'info', en: 'Money out', ne: 'पैसा गयो' },
    refund: { icon: 'undo', tone: 'warn', en: 'Refund', ne: 'फिर्ता' },
    expense: { icon: 'receipt', tone: 'bad', en: 'Expense', ne: 'खर्च' },
    stock_adjust: { icon: 'tune', tone: '', en: 'Stock change', ne: 'स्टक परिवर्तन' },
    stock_count: { icon: 'checklist', tone: '', en: 'Stock count', ne: 'स्टक गणना' },
    vat_filing: { icon: 'account_balance', tone: '', en: 'VAT filing', ne: 'भ्याट फाइलिङ' },
  }
  const kindMeta = (kind: string) => KIND[kind] ?? { icon: 'info', tone: '', en: kind, ne: kind }
  const PER_PAGE = 30

  const people = resource(() => api.all<User>('/users'))

  let person = $state('')
  let group = $state<Group>('all')
  let extra = $state<ActivityEntry[]>([])
  let page = $state(1)
  let moreBusy = $state(false)
  let moreError = $state<string | null>(null)
  let runKey = ''

  const list = resource(() => {
    const key = person
    runKey = key
    extra = []
    page = 1
    moreError = null
    return api.page<ActivityEntry>('/activity', { per_page: PER_PAGE, page: 1, user_id: person || undefined })
  })

  async function loadMore(): Promise<void> {
    const key = person
    const next = page + 1
    moreBusy = true
    moreError = null
    try {
      const res = await api.page<ActivityEntry>('/activity', { per_page: PER_PAGE, page: next, user_id: key || undefined })
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
  const shown = $derived.by(() => {
    const g = GROUPS.find((x) => x.key === group)
    if (!g || g.kinds.length === 0) return rows
    return rows.filter((e) => g.kinds.includes(e.kind))
  })

  const groups = $derived.by(() => {
    const out: { day: string; rows: ActivityEntry[] }[] = []
    for (const e of shown) {
      const day = adOfStamp(e.at)
      const last = out.at(-1)
      if (last && last.day === day) last.rows.push(e)
      else out.push({ day, rows: [e] })
    }
    return out
  })

  const dayLabel = (day: string) => (day === todayAd() ? `${tr('Today', 'आज')} · ${formatDate(day)}` : formatDate(day))

  const qty = (n: number) => `${n > 0 ? '+' : ''}${num(n)}`

  function sentence(e: ActivityEntry): string {
    const who = e.by ?? tr('Someone', 'कसैले')
    const label = e.label ?? '-'
    const amt = rs(e.amount)
    switch (e.kind) {
      case 'sale':
        return tr(`${who} made sale ${label} for ${amt}`, `${who} ले बिक्री ${digits(label)} बनाए, ${amt}`)
      case 'return':
        return tr(`${who} returned goods from sale ${label}, ${amt}`, `${who} ले बिक्री ${digits(label)} को सामान फिर्ता लिए, ${amt}`)
      case 'cancel':
        return tr(`${who} cancelled sale ${label}, ${amt}`, `${who} ले बिक्री ${digits(label)} रद्द गरे, ${amt}`)
      case 'purchase':
        return tr(`${who} recorded purchase ${label} for ${amt}`, `${who} ले खरिद ${digits(label)} थपे, ${amt}`)
      case 'payment_in':
        return tr(`${who} got ${amt} from ${label}`, `${who} ले ${label} बाट ${amt} पाए`)
      case 'payment_out':
        return tr(`${who} paid ${amt} to ${label}`, `${who} ले ${label} लाई ${amt} तिरे`)
      case 'refund':
        return tr(`${who} refunded ${amt} to ${label}`, `${who} ले ${label} लाई ${amt} फिर्ता गरे`)
      case 'expense':
        return tr(`${who} added expense ${label}, ${amt}`, `${who} ले खर्च ${label} थप्यो, ${amt}`)
      case 'stock_adjust':
        return tr(`${who} adjusted stock of ${label} by ${qty(e.amount)}`, `${who} ले ${label} को स्टक ${qty(e.amount)} मिलाए`)
      case 'stock_count':
        return tr(`${who} counted stock of ${label}, change ${qty(e.amount)}`, `${who} ले ${label} को स्टक गन्यो, फरक ${qty(e.amount)}`)
      case 'vat_filing':
        return tr(`${who} filed VAT for ${digits(label)}, ${amt} payable`, `${who} ले ${digits(label)} को भ्याट फाइल गरे, ${amt} तिर्नुपर्ने`)
      default:
        return `${who} ${e.kind} ${label}`
    }
  }

  function linkOf(e: ActivityEntry): string | null {
    if (['sale', 'return', 'cancel'].includes(e.kind)) return `#/sales/${e.ref_id}`
    if (e.kind === 'purchase') return `#/purchases/${e.ref_id}`
    return null
  }
</script>

<div class="page">
  {#if people.data}
    <div class="chips">
      <button class="chip" class:active={person === ''} onclick={() => (person = '')}>{tr('Everyone', 'सबै')}</button>
      {#each people.data as u (u.id)}
        <button class="chip" class:active={person === String(u.id)} onclick={() => (person = String(u.id))}>{u.name}</button>
      {/each}
    </div>
  {/if}

  <div class="chips">
    {#each GROUPS as g (g.key)}
      <button class="chip" class:active={group === g.key} onclick={() => (group = g.key)}>{tr(g.en, g.ne)}</button>
    {/each}
  </div>

  {#if list.error}
    <ErrorCard error={list.error} retry={list.reload} />
  {:else if list.loading && !list.data}
    <Skeleton rows={6} />
  {:else if shown.length === 0}
    <Empty icon="history" title={tr('Nothing here yet', 'अहिले केही छैन')} text={tr('Sales, stock changes and payments show here as they happen.', 'बिक्री, स्टक परिवर्तन र भुक्तानी भए यहाँ देखिन्छ।')} />
  {:else}
    <div class="list">
      {#each groups as g (g.day)}
        <div class="list-head">{dayLabel(g.day)}</div>
        {#each g.rows as e (`${e.kind}-${e.ref_id}-${e.at}`)}
          {@const href = linkOf(e)}
          {@const k = kindMeta(e.kind)}
          <svelte:element this={href ? 'a' : 'div'} class="row" href={href ?? undefined}>
            <span class="icon-tile {k.tone}"><span class="ms">{k.icon}</span></span>
            <div class="row-main">
              <div class="row-title" style="white-space:normal">{sentence(e)}</div>
              <div class="row-sub">{tr(k.en, k.ne)} · {formatDate(e.at)}</div>
            </div>
            <div class="row-end"><span class="tiny muted">{formatTime(e.at)}</span></div>
            {#if href}<span class="ms chev">chevron_right</span>{/if}
          </svelte:element>
        {/each}
      {/each}
    </div>

    <p class="small muted" style="text-align:center">
      {tr(`Showing ${num(rows.length)} of ${num(total)} events`, `${num(total)} मध्ये ${num(rows.length)} देखाइँदै`)}
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
</div>
