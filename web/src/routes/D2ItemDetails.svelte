<script lang="ts">
  import { api } from '../lib/api'
  import { resource, action } from '../lib/resource.svelte'
  import { tr, num } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { cart } from '../lib/cart.svelte'
  import { navigate } from '../lib/router.svelte'
  import { session } from '../lib/session.svelte'
  import { toast } from '../lib/toast.svelte'
  import { setTitle } from '../lib/shell.svelte'
  import { adOfStamp, daysUntil, formatDate } from '../lib/bs'
  import type { Category, Item, Paged, StockMovement } from '../lib/types'
  import AdjustStockForm from '../components/AdjustStockForm.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Sheet from '../components/Sheet.svelte'
  import Skeleton from '../components/Skeleton.svelte'

  let { params }: { params: Record<string, string> } = $props()
  const id = $derived(Number(params.id))

  const item = resource(() => api.get<{ data: Item }>(`/items/${id}`).then((r) => r.data))
  const cats = resource(() => api.all<Category>('/categories'))
  const moves = resource(() =>
    session.isOwner
      ? api.get<Paged<StockMovement>>(`/items/${id}/stock-movements`, { per_page: 100 })
      : Promise.resolve<Paged<StockMovement> | null>(null),
  )

  $effect(() => {
    if (item.data) setTitle(item.data.name)
  })

  const SALE_REASONS = ['sale', 'sale_return', 'sale_cancel']
  const REASON: Record<StockMovement['reason'], [string, string]> = {
    sale: ['Sale', 'बिक्री'],
    sale_return: ['Sale return', 'बिक्री फिर्ता'],
    sale_cancel: ['Sale cancelled', 'बिक्री रद्द'],
    purchase: ['Purchase', 'खरिद'],
    adjust: ['Adjustment', 'समायोजन'],
    count: ['Stock count', 'स्टक गणना'],
  }

  const vatRate = $derived(session.business?.vat_rate ?? 0)
  const priceExVat = $derived.by(() => {
    const i = item.data
    if (!i) return 0
    return i.vat_applies ? Math.round((i.sell_price * 100) / (100 + vatRate)) : i.sell_price
  })
  const profit = $derived(item.data && item.data.cost_price !== null ? priceExVat - item.data.cost_price : 0)
  const margin = $derived(priceExVat > 0 ? Math.round((profit * 1000) / priceExVat) / 10 : 0)

  const catName = $derived(cats.data?.find((c) => c.id === item.data?.category_id)?.name ?? '')
  const low = $derived(item.data?.is_low_stock ?? false)
  const stockMax = $derived(item.data ? Math.max(item.data.quantity, item.data.low_stock_at * 2, 1) : 1)
  const stockPct = $derived(item.data ? (Math.max(0, item.data.quantity) * 100) / stockMax : 0)

  const movements = $derived(moves.data?.data ?? [])
  const recent = $derived(movements.filter((m) => -daysUntil(adOfStamp(m.at)) <= 29))
  const sold = $derived(-recent.filter((m) => SALE_REASONS.includes(m.reason)).reduce((n, m) => n + m.change, 0))
  const bars = $derived.by(() => {
    const out = [0, 0, 0, 0, 0]
    for (const m of recent) {
      if (!SALE_REASONS.includes(m.reason)) continue
      const back = -daysUntil(adOfStamp(m.at))
      out[4 - Math.floor(back / 6)] += -m.change
    }
    return out.map((v) => Math.max(0, v))
  })
  const barMax = $derived(Math.max(1, ...bars))
  const preview = $derived(movements.slice(0, 5))
  const partial = $derived((moves.data?.meta.total ?? 0) > movements.length)

  let deleteOpen = $state(false)
  let adjustOpen = $state(false)
  const del = action()

  async function remove(): Promise<void> {
    const ok = await del.run(() => api.delete(`/items/${id}`))
    if (ok === undefined) return
    toast('Item deleted', 'सामान हटाइयो')
    navigate('/items', true)
  }
</script>

<div class="page narrow">
  {#if item.error}
    <ErrorCard error={item.error} retry={item.reload} />
  {:else if item.loading && !item.data}
    <Skeleton card />
    <Skeleton rows={3} />
  {:else if item.data}
    {@const i = item.data}
    <section class="hero {low ? 'warn' : 'soft'}">
      <div class="hstack">
        {#if i.photo_url}
          <img class="photo" src={i.photo_url} alt={i.name} />
        {:else}
          <span class="icon-tile lg"><span class="ms">inventory_2</span></span>
        {/if}
        <div class="stack-sm" style="gap:2px">
          <h2>{i.name}</h2>
          <span class="small muted">{tr('Code', 'कोड')}: {i.sku ?? tr('None', 'छैन')}{catName ? ` · ${catName}` : ''}</span>
        </div>
      </div>

      <div style="margin-top:18px">
        <div class="hstack between">
          <span class="stat-label">{tr('Stock left', 'बाँकी स्टक')}</span>
          {#if low}
            <span class="badge warn"><span class="ms">warning</span><span>{tr('Low stock', 'कम स्टक')}</span></span>
          {/if}
        </div>
        <div class="stat-value xl" style="margin-top:2px">{num(i.quantity)} <span class="small">{i.unit}</span></div>
        <div class="progress {low ? 'warn' : 'good'}" style="margin-top:12px;--w:{stockPct}%"><span></span></div>
        <div class="small muted" style="margin-top:6px">{tr('Low level', 'कम स्तर')}: {num(i.low_stock_at)} {i.unit}</div>
      </div>
    </section>

    <div class="hstack wrap">
      <button
        class="btn btn-primary"
        disabled={i.quantity < 1}
        onclick={() => {
          if (!cart.add(i)) toast('This item is out of stock.', 'यो सामान स्टकमा छैन।')
          else navigate('/sell/checkout')
        }}
      >
        <span class="ms">add_shopping_cart</span><span>{tr('Sell this', 'यो बेच्ने')}</span>
      </button>
      {#if session.isOwner}
        <a class="btn btn-tonal" href="#/purchases/new"><span class="ms">shopping_bag</span><span>{tr('Buy more', 'थप खरिद')}</span></a>
        <button class="btn btn-tonal" onclick={() => (adjustOpen = true)}><span class="ms">tune</span><span>{tr('Adjust stock', 'स्टक मिलाउने')}</span></button>
        <a class="btn btn-outline" href="#/items/{id}/edit"><span class="ms">edit</span><span>{tr('Edit', 'सच्याउने')}</span></a>
        <button class="btn btn-danger" onclick={() => (deleteOpen = true)}><span class="ms">delete</span><span>{tr('Delete', 'हटाउने')}</span></button>
      {/if}
    </div>

    <section class="card">
      <div class="card-head"><h3>{tr('Prices', 'मूल्य')}</h3></div>
      <div class="kv">
        <div>
          <span class="k">{i.vat_applies ? tr('Sell price (VAT included)', 'बिक्री मूल्य (भ्याट सहित)') : tr('Sell price (no VAT)', 'बिक्री मूल्य (भ्याट छैन)')}</span>
          <span class="v">{rs(i.sell_price)}</span>
        </div>
        {#if session.isOwner}
          <div>
            <span class="k">{tr('Buying price (without VAT)', 'खरिद मूल्य (भ्याट बाहेक)')}</span>
            <span class="v">{rs(i.cost_price)}</span>
          </div>
          <div>
            <span class="k">{tr('Profit per piece', 'प्रति पिस नाफा')}</span>
            <span class="v {profit >= 0 ? 'good' : 'bad'}">{rs(profit, { paisa: true })} <span class="tiny muted">({num(margin, 1)}%)</span></span>
          </div>
        {/if}
        <div>
          <span class="k">{tr('VAT applies', 'भ्याट लाग्ने')}</span>
          <span class="v">{i.vat_applies ? tr('Yes', 'हो') : tr('No', 'होइन')}</span>
        </div>
        <div>
          <span class="k">{tr('Unit', 'एकाइ')}</span>
          <span class="v">{i.unit}</span>
        </div>
      </div>
      {#if session.isOwner}
        <p class="tiny muted" style="margin-top:8px">{tr('Sell price without VAT minus buying price', 'बिक्री मूल्य (भ्याट बाहेक) माइनस खरिद मूल्य')}</p>
      {/if}
    </section>

    {#if session.isOwner}
      <section class="card">
        <div class="card-head"><h3>{tr('Sold, last 30 days', 'पछिल्लो ३० दिनमा बिक्री')}</h3></div>
        <div class="hstack between" style="margin-bottom:6px">
          <span class="stat-label">{tr('Sold', 'बिक्री भयो')}</span>
          <span class="stat-value">{num(sold)} <span class="small">{i.unit}</span></span>
        </div>
        <div class="bars">
          {#each bars as v, n}
            <div class="bar" class:on={n === 4} style="--h:{(v * 100) / barMax}%;--i:{n}"><i></i><span>{n === 4 ? tr('This week', 'यो हप्ता') : tr(`Week ${n + 1}`, `हप्ता ${num(n + 1)}`)}</span></div>
          {/each}
        </div>
        {#if partial}
          <p class="tiny muted" style="margin-top:8px">{tr('Based on the latest 100 stock changes.', 'पछिल्लो १०० स्टक परिवर्तनमा आधारित।')}</p>
        {/if}
      </section>

      <section class="stack-sm">
        <div class="section-title">
          <h3>{tr('Stock history', 'स्टक इतिहास')}</h3>
          <a href="#/items/{id}/history">{tr('See all', 'सबै हेर्ने')}</a>
        </div>
        {#if moves.loading && !moves.data}
          <Skeleton rows={2} />
        {:else if preview.length === 0}
          <p class="small muted">{tr('No stock changes yet.', 'अहिलेसम्म स्टक परिवर्तन छैन।')}</p>
        {:else}
          <div class="list">
            {#each preview as m (m.id)}
              <a class="row" href="#/items/{id}/history">
                <span class="icon-tile {m.change < 0 ? 'warn' : 'good'}"><span class="ms">{m.change < 0 ? 'arrow_downward' : 'arrow_upward'}</span></span>
                <div class="row-main">
                  <div class="row-title">{tr(...REASON[m.reason])}{m.by ? ` · ${m.by}` : ''}</div>
                  <div class="row-sub">{formatDate(m.at)}{m.note ? ` · ${m.note}` : ''}</div>
                </div>
                <div class="row-end"><span class="amount">{m.change > 0 ? '+' : ''}{num(m.change)}</span></div>
              </a>
            {/each}
          </div>
        {/if}
      </section>
    {/if}
  {/if}
</div>

{#if item.data}
  <Sheet bind:open={deleteOpen} title={tr('Delete this item?', 'सामान हटाउने?')}>
    <p class="muted">{tr('It moves to Deleted items. Old bills keep its name.', 'यो हटाइएका सामानमा जान्छ। पुराना बिलमा नाम रहन्छ।')}</p>
    {#if del.error}
      <div class="alert bad">
        <span class="ms">error</span>
        <div class="stack-sm">
          <div>{del.error.field('quantity') ?? del.error.message}</div>
          {#if del.error.field('quantity')}
            <div class="small">{tr('Set the stock to 0 first. Use Adjust stock.', 'पहिले स्टक ० बनाउनुहोस्। स्टक मिलाउने प्रयोग गर्नुहोस्।')}</div>
          {/if}
        </div>
      </div>
    {/if}
    <div class="hstack">
      <button class="btn btn-outline btn-lg" style="flex:1" onclick={() => (deleteOpen = false)}>{tr('Cancel', 'रद्द')}</button>
      <button class="btn btn-danger btn-lg" style="flex:1" disabled={del.busy} onclick={remove}>
        <span class="ms">delete</span><span>{del.busy ? tr('Deleting…', 'हटाउँदैछ…') : tr('Delete', 'हटाउने')}</span>
      </button>
    </div>
  </Sheet>

  <Sheet bind:open={adjustOpen} title={tr('Adjust stock', 'स्टक मिलाउने')}>
    <AdjustStockForm
      item={item.data}
      onsaved={() => {
        adjustOpen = false
        item.reload()
        moves.reload()
      }}
    />
  </Sheet>
{/if}

<style>
  .photo {
    width: 56px;
    height: 56px;
    border-radius: 18px;
    object-fit: cover;
    flex: none;
  }
</style>
