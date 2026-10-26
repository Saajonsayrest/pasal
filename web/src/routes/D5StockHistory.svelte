<script lang="ts">
  import { api, ApiError } from '../lib/api'
  import { action } from '../lib/resource.svelte'
  import { match, route } from '../lib/router.svelte'
  import { setTitle } from '../lib/shell.svelte'
  import { tr, num } from '../lib/i18n'
  import { formatDate, formatTime } from '../lib/bs'
  import type { Meta, StockMovement } from '../lib/types'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Empty from '../components/Empty.svelte'

  type Filter = 'all' | 'sales' | 'purchases' | 'adjust' | 'returns'
  type History = {
    item: { id: number; name: string; quantity: number }
    data: StockMovement[]
    links: { next: string | null; prev: string | null }
    meta: Meta
  }

  const groups: Record<Exclude<Filter, 'all'>, StockMovement['reason'][]> = {
    sales: ['sale'],
    purchases: ['purchase'],
    adjust: ['adjust', 'count'],
    returns: ['sale_return', 'sale_cancel'],
  }

  const itemId = $derived(match('/items/:id/history', route.path)?.id ?? '')
  let filter = $state<Filter>('all')
  let item = $state<History['item'] | null>(null)
  let rows = $state<StockMovement[]>([])
  let page = $state(1)
  let hasMore = $state(false)
  let loading = $state(true)
  let error = $state<ApiError | null>(null)
  let run = 0
  const more = action()

  const shown = $derived.by(() => {
    if (filter === 'all') return rows
    const wanted = groups[filter]
    return rows.filter((m) => wanted.includes(m.reason))
  })

  async function loadFirst(id: string): Promise<void> {
    const token = ++run
    loading = true
    error = null
    rows = []
    try {
      const res = await api.get<History>(`/items/${id}/stock-movements`)
      if (token !== run) return
      item = res.item
      rows = res.data
      page = 1
      hasMore = !!res.links?.next
      setTitle(res.item.name)
    } catch (e) {
      if (token === run) error = e instanceof ApiError ? e : new ApiError(0, (e as Error).message)
    } finally {
      if (token === run) loading = false
    }
  }

  $effect(() => {
    void loadFirst(itemId)
  })

  async function loadMore(): Promise<void> {
    const id = itemId
    const token = run
    const next = page + 1
    await more.run(async () => {
      const res = await api.get<History>(`/items/${id}/stock-movements`, { page: next })
      if (token !== run) return
      rows = [...rows, ...res.data]
      page = next
      hasMore = !!res.links?.next
    })
  }

  function reasonLabel(reason: StockMovement['reason']): string {
    switch (reason) {
      case 'sale':
        return tr('Sale', 'बिक्री')
      case 'sale_return':
        return tr('Sale return', 'बिक्री फिर्ता')
      case 'sale_cancel':
        return tr('Sale cancelled', 'बिक्री रद्द')
      case 'purchase':
        return tr('Purchase', 'खरिद')
      case 'adjust':
        return tr('Adjusted by hand', 'हातले समायोजन')
      case 'count':
        return tr('Stock count', 'स्टक गणना')
    }
  }

  function billHref(m: StockMovement): string | null {
    if (!m.ref_id) return null
    if (m.ref_type === 'sale') return `#/sales/${m.ref_id}`
    if (m.ref_type === 'purchase') return `#/purchases/${m.ref_id}`
    return null
  }
</script>

{#snippet line(m: StockMovement)}
  <span class="icon-tile {m.change > 0 ? 'good' : 'warn'}"><span class="ms">{m.change > 0 ? 'arrow_upward' : 'arrow_downward'}</span></span>
  <div class="row-main">
    <div class="row-title">{reasonLabel(m.reason)}</div>
    <div class="row-sub">{m.by ? `${m.by} · ` : ''}{formatDate(m.at)} {formatTime(m.at)}</div>
    {#if m.note}<div class="row-sub">{m.note}</div>{/if}
  </div>
  <div class="row-end">
    <span class="amount {m.change > 0 ? 'good' : 'warn'}">{m.change > 0 ? '+' : '-'}{num(Math.abs(m.change))}</span>
    <span class="tiny muted">{m.change > 0 ? tr('Added', 'थपियो') : tr('Taken out', 'निकालियो')}</span>
  </div>
  {#if billHref(m)}<span class="ms chev">chevron_right</span>{/if}
{/snippet}

<div class="page narrow">
  {#if error}
    <ErrorCard {error} retry={() => loadFirst(itemId)} />
  {:else if loading && !item}
    <Skeleton rows={5} />
  {:else if item}
    <div class="hstack">
      <span class="icon-tile"><span class="ms">inventory_2</span></span>
      <div class="row-main">
        <div class="row-title">{item.name}</div>
        <div class="row-sub">{tr(`Stock now ${num(item.quantity)}`, `अहिले स्टक ${num(item.quantity)}`)}</div>
      </div>
    </div>

    <div class="chips">
      {#each [['all', 'All', 'सबै'], ['sales', 'Sales', 'बिक्री'], ['purchases', 'Purchases', 'खरिद'], ['adjust', 'Adjustments', 'समायोजन'], ['returns', 'Returns', 'फिर्ता']] as [key, en, ne]}
        <button class="chip" class:active={filter === key} onclick={() => (filter = key as Filter)}>{tr(en, ne)}</button>
      {/each}
    </div>

    {#if shown.length === 0}
      <Empty icon="history" title={tr('No stock changes yet', 'अहिलेसम्म स्टक परिवर्तन छैन')} text={tr('Sales, purchases and stock counts show here.', 'बिक्री, खरिद र स्टक गणना यहाँ देखिन्छ।')} />
    {:else}
      <div class="list">
        {#each shown as m (m.id)}
          {#if billHref(m)}
            <a class="row" href={billHref(m) ?? undefined}>{@render line(m)}</a>
          {:else}
            <div class="row">{@render line(m)}</div>
          {/if}
        {/each}
      </div>
    {/if}

    {#if more.message}
      <div class="alert bad"><span class="ms">error</span><div>{more.message}</div></div>
    {/if}
    {#if hasMore}
      <button class="btn btn-tonal btn-block" disabled={more.busy} onclick={loadMore}>
        <span class="ms">expand_more</span><span>{more.busy ? tr('Loading…', 'लोड हुँदैछ…') : tr('Load more', 'अरू हेर्ने')}</span>
      </button>
    {/if}
  {/if}
</div>
