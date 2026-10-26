<script lang="ts">
  import { api } from '../lib/api'
  import { resource } from '../lib/resource.svelte'
  import { session } from '../lib/session.svelte'
  import { tr, num } from '../lib/i18n'
  import { rs } from '../lib/money'
  import type { Item } from '../lib/types'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'

  type Size = 'small' | 'large'

  const items = resource(() => api.all<Item>('/items'))
  let size = $state<Size>('small')
  let search = $state('')
  let copies = $state<Record<string, number>>({})

  const visible = $derived.by(() => {
    const q = search.trim().toLowerCase()
    return (items.data ?? []).filter((i) => !q || i.name.toLowerCase().includes(q) || (i.sku ?? '').toLowerCase().includes(q))
  })

  const chosen = $derived((items.data ?? []).filter((i) => copies[String(i.id)] !== undefined))
  const labels = $derived(chosen.flatMap((item) => Array.from({ length: copies[String(item.id)] }, () => item)))

  function toggle(item: Item): void {
    const key = String(item.id)
    const next = { ...copies }
    if (next[key] === undefined) next[key] = 1
    else delete next[key]
    copies = next
  }

  function setCopies(item: Item, n: number): void {
    copies = { ...copies, [String(item.id)]: Math.min(99, Math.max(1, n)) }
  }
</script>

<div class="page narrow">
  {#if items.error}
    <ErrorCard error={items.error} retry={items.reload} />
  {:else if items.loading && !items.data}
    <Skeleton rows={5} />
  {:else}
    <div class="no-print stack">
      <span class="small muted">{tr('Label size', 'लेबलको साइज')}</span>
      <div class="seg block">
        <button class:active={size === 'small'} onclick={() => (size = 'small')}>{tr('Small · 38 × 25 mm', 'सानो · ३८ × २५ मिमि')}</button>
        <button class:active={size === 'large'} onclick={() => (size = 'large')}>{tr('Large · 50 × 30 mm', 'ठूलो · ५० × ३० मिमि')}</button>
      </div>
      <label class="search">
        <span class="ms">search</span>
        <input placeholder={tr('Search item name or code', 'सामानको नाम वा कोड खोज्नुहोस्')} bind:value={search} />
      </label>
    </div>

    <div class="section-title no-print"><h3>{tr('Items to print', 'लेबल छाप्ने सामान')}</h3></div>
    <div class="list no-print">
      {#each visible as item (item.id)}
        {@const n = copies[String(item.id)]}
        <div class="row">
          <input type="checkbox" checked={n !== undefined} onchange={() => toggle(item)} aria-label={item.name} style="width:20px;height:20px;accent-color:var(--primary);flex:none" />
          <div class="row-main">
            <div class="row-title">{item.name}</div>
            <div class="row-sub">{rs(item.sell_price)}{item.sku ? ` · ${item.sku}` : ''}</div>
          </div>
          {#if n !== undefined}
            <div class="stepper">
              <button type="button" aria-label={tr('Fewer copies', 'कम प्रति')} onclick={() => setCopies(item, n - 1)}><span class="ms">remove</span></button>
              <span class="val">{num(n)}</span>
              <button type="button" aria-label={tr('More copies', 'थप प्रति')} onclick={() => setCopies(item, n + 1)}><span class="ms">add</span></button>
            </div>
          {/if}
        </div>
      {:else}
        <div class="row"><span class="muted">{tr('No items match', 'मेल खाने सामान भेटिएन')}</span></div>
      {/each}
    </div>

    <div class="section-title"><h3>{tr('Label preview', 'लेबल नमुना')}</h3></div>
    {#if labels.length === 0}
      <div class="card no-print"><p class="muted">{tr('Tick items above to make labels.', 'लेबल बनाउन माथि सामान छान्नुहोस्।')}</p></div>
    {:else}
      <div class="sticker-grid {size}">
        {#each labels as item, i (i)}
          <div class="sticker">
            <span class="sticker-shop">{session.business?.name ?? 'PASAL'}</span>
            <span class="sticker-name">{item.name}</span>
            {#if item.sku}<span class="sticker-sku">{item.sku}</span>{/if}
            <span class="sticker-price">{rs(item.sell_price)}</span>
          </div>
        {/each}
      </div>
    {/if}

    <div class="bottom-bar no-print">
      <div class="stack-sm" style="flex:1;gap:0"><span class="small muted">{tr(`${num(labels.length)} labels`, `${num(labels.length)} लेबल`)}</span></div>
      <button class="btn btn-primary btn-lg" disabled={labels.length === 0} onclick={() => window.print()}>
        <span class="ms">print</span><span>{tr('Print', 'प्रिन्ट गर्ने')}</span>
      </button>
    </div>
  {/if}
</div>

<style>
  .sticker-grid {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
  }
  .sticker {
    width: 38mm;
    height: 25mm;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 0.6mm;
    padding: 1.5mm;
    overflow: hidden;
    text-align: center;
    color: #000;
    background: #fff;
    border: 1px dashed #bbb;
    border-radius: 4px;
  }
  .sticker-grid.large .sticker {
    width: 50mm;
    height: 30mm;
  }
  .sticker-shop {
    font-size: 6pt;
    color: #444;
    max-width: 100%;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .sticker-name {
    font-size: 8.5pt;
    font-weight: 600;
    line-height: 1.15;
    max-width: 100%;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .sticker-sku {
    font-size: 14pt;
    font-weight: 800;
    letter-spacing: 0.06em;
    line-height: 1;
    max-width: 100%;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .sticker-price {
    font-size: 9pt;
    font-weight: 700;
  }
  @media print {
    .sticker {
      border: none;
      break-inside: avoid;
    }
    .sticker-grid {
      gap: 0;
    }
  }
</style>
