<script lang="ts">
  import { api, ApiError } from '../lib/api'
  import { resource } from '../lib/resource.svelte'
  import { tr } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { toast } from '../lib/toast.svelte'
  import type { Category, Item } from '../lib/types'
  import Empty from '../components/Empty.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Skeleton from '../components/Skeleton.svelte'

  const list = resource(() => api.page<Item>('/items', { trashed: 'only', per_page: 50 }))
  const cats = resource(() => api.all<Category>('/categories'))
  const catName = (id: number | null): string => cats.data?.find((c) => c.id === id)?.name ?? ''

  let busy = $state<number | null>(null)
  let rowErr = $state<Record<number, string>>({})

  async function restore(it: Item): Promise<void> {
    busy = it.id
    rowErr = { ...rowErr, [it.id]: '' }
    try {
      await api.post(`/items/${it.id}/restore`)
      toast(`Restored: ${it.name}`, `फिर्ता ल्याइयो: ${it.name}`)
      list.reload()
    } catch (e) {
      const message = e instanceof ApiError ? (e.field('name') ?? e.message) : tr('Could not restore. Try again.', 'फिर्ता ल्याउन सकिएन। फेरि प्रयास गर्नुहोस्।')
      rowErr = { ...rowErr, [it.id]: message }
    } finally {
      busy = null
    }
  }
</script>

<div class="page narrow">
  <div class="alert info">
    <span class="ms">info</span>
    <div>{tr('Deleted items stay in old bills. Restoring brings back their history.', 'हटाइएका सामान पुराना बिलमा रहन्छन्। फिर्ता ल्याउँदा तिनको इतिहास पनि आउँछ।')}</div>
  </div>

  {#if list.error}
    <ErrorCard error={list.error} retry={list.reload} />
  {:else if list.loading && !list.data}
    <Skeleton rows={3} />
  {:else if !list.data || list.data.data.length === 0}
    <Empty icon="delete_sweep" title={tr('No deleted items', 'हटाइएका सामान छैनन्')} text={tr('Items you delete will show here. You can bring them back.', 'हटाएका सामान यहाँ देखिन्छन्। तिनलाई फिर्ता ल्याउन सकिन्छ।')} />
  {:else}
    <div class="list">
      {#each list.data.data as it (it.id)}
        <div class="row">
          {#if it.photo_url}
            <img class="thumb" src={it.photo_url} alt="" />
          {:else}
            <span class="icon-tile"><span class="ms">inventory_2</span></span>
          {/if}
          <div class="row-main">
            <div class="row-title">{it.name}</div>
            <div class="row-sub">{[catName(it.category_id), rs(it.sell_price)].filter(Boolean).join(' · ')}</div>
            {#if rowErr[it.id]}
              <div class="field-error" style="margin-top:6px"><span class="ms" style="font-size:16px">error</span><span>{rowErr[it.id]}</span></div>
            {/if}
          </div>
          <button class="btn btn-tonal btn-sm" disabled={busy === it.id} onclick={() => restore(it)}>
            <span class="ms">restore</span><span>{tr('Restore', 'फिर्ता ल्याउने')}</span>
          </button>
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .thumb {
    width: 44px;
    height: 44px;
    border-radius: 14px;
    object-fit: cover;
    flex: none;
  }
</style>
