<script lang="ts">
  import { api } from '../lib/api'
  import { resource } from '../lib/resource.svelte'
  import { tr, num } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { navigate } from '../lib/router.svelte'
  import type { Category, Item } from '../lib/types'
  import AdjustStockForm from '../components/AdjustStockForm.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Skeleton from '../components/Skeleton.svelte'

  let { params }: { params: Record<string, string> } = $props()
  const id = $derived(Number(params.id))

  const item = resource(() => api.get<{ data: Item }>(`/items/${id}`).then((r) => r.data))
  const cats = resource(() => api.all<Category>('/categories'))
  const categoryName = $derived(cats.data?.find((c) => c.id === item.data?.category_id)?.name ?? '')
</script>

<div class="page narrow">
  {#if item.error}
    <ErrorCard error={item.error} retry={item.reload} />
  {:else if !item.data}
    <Skeleton card />
  {:else}
    <section class="card">
      <div class="hstack">
        <span class="icon-tile lg"><span class="ms">inventory_2</span></span>
        <div class="row-main">
          <div class="row-title">{item.data.name}</div>
          <div class="row-sub">{[item.data.sku, categoryName].filter(Boolean).join(' · ')}</div>
        </div>
        <div class="row-end">
          <span class="stat-value lg">{num(item.data.quantity)}</span>
          <span class="tiny muted">{item.data.unit}</span>
        </div>
      </div>
    </section>

    <section class="card">
      <div class="kv">
        <div><span class="k">{tr('Sell price (VAT included)', 'बिक्री मूल्य (भ्याट सहित)')}</span><span class="v">{rs(item.data.sell_price)}</span></div>
        <div><span class="k">{tr('Low stock level', 'कम स्टकको सीमा')}</span><span class="v">{num(item.data.low_stock_at)} {item.data.unit}</span></div>
      </div>
    </section>

    <section class="card">
      <AdjustStockForm item={item.data} onsaved={() => navigate(`/items/${id}`, true)} />
    </section>
  {/if}
</div>
