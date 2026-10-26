<script lang="ts">
  import { api } from '../lib/api'
  import { resource } from '../lib/resource.svelte'
  import { navigate } from '../lib/router.svelte'
  import { session } from '../lib/session.svelte'
  import { tr, num } from '../lib/i18n'
  import { rs } from '../lib/money'
  import type { Category, Item } from '../lib/types'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Empty from '../components/Empty.svelte'

  type Group = { key: string; name: string; icon: string; items: Item[] }

  const low = resource(async () => {
    const [items, cats] = await Promise.all([api.all<Item>('/items', { low_stock: 1 }), api.all<Category>('/categories')])
    return { items, cats }
  })

  let edits = $state<Record<string, string>>({})
  let picked = $state<Record<string, boolean>>({})

  const all = $derived(low.data?.items ?? [])

  const groups = $derived.by(() => {
    const cats = new Map<number, Category>((low.data?.cats ?? []).map((c) => [c.id, c]))
    const byKey = new Map<string, Group>()
    for (const item of all) {
      const key = item.category_id === null ? 'none' : String(item.category_id)
      let group = byKey.get(key)
      if (!group) {
        const cat = item.category_id === null ? undefined : cats.get(item.category_id)
        group = { key, name: cat?.name ?? tr('No category', 'बिना वर्ग'), icon: cat?.icon ?? 'inventory_2', items: [] }
        byKey.set(key, group)
      }
      group.items.push(item)
    }
    return [...byKey.values()].sort((a, b) => a.name.localeCompare(b.name))
  })

  function suggest(item: Item): number {
    return Math.max(1, item.low_stock_at * 2 - item.quantity)
  }

  function isPicked(item: Item): boolean {
    return picked[String(item.id)] ?? true
  }

  function orderOf(item: Item): number | null {
    const raw = (edits[String(item.id)] ?? String(suggest(item))).trim()
    return /^\d+$/.test(raw) && Number(raw) >= 1 ? Number(raw) : null
  }

  function barWidth(item: Item): number {
    if (item.low_stock_at <= 0) return 0
    return Math.min(100, Math.max(0, Math.round((item.quantity / item.low_stock_at) * 100)))
  }

  const ticked = $derived(all.filter((i) => isPicked(i) && orderOf(i) !== null))
  const costTotal = $derived(ticked.reduce((sum, i) => sum + (orderOf(i) ?? 0) * (i.cost_price ?? 0), 0))

  function buy(group: Group): void {
    const pairs = group.items.filter((i) => isPicked(i) && orderOf(i) !== null).map((i) => `${i.id}:${orderOf(i)}`)
    if (pairs.length > 0) navigate(`/purchases/new?items=${pairs.join(',')}`)
  }
</script>

<div class="page">
  {#if low.error}
    <ErrorCard error={low.error} retry={low.reload} />
  {:else if low.loading && !low.data}
    <Skeleton rows={4} />
  {:else if all.length === 0}
    <Empty icon="check_circle" title={tr('Nothing is low right now', 'अहिले कम स्टकको सामान छैन')} text={tr('Items show here when stock falls to the low level.', 'स्टक कम तहमा झर्दा सामान यहाँ देखिन्छ।')} />
  {:else}
    <section class="hero warn">
      <div class="stat">
        <span class="stat-label">{tr('Low stock items', 'कम स्टकका सामान')}</span>
        <span class="stat-value xl warn">{num(all.length)}</span>
        <span class="stat-sub">{tr(`${num(groups.length)} categories`, `${num(groups.length)} वर्गबाट`)}</span>
      </div>
      {#if session.isOwner}
        <div class="hstack between" style="margin-top:14px">
          <span class="small">{tr('Buying cost of ticked items', 'चिनिएका सामानको खरिद मूल्य')}</span>
          <span class="bold">{rs(costTotal)}</span>
        </div>
      {/if}
    </section>

    <p class="small muted">{tr('Grouped by category. Items are not linked to a supplier yet.', 'वर्ग अनुसार समूहमा। सामान अहिले डिलरसँग जोडिएको छैन।')}</p>

    {#each groups as group (group.key)}
      <div class="list">
        <div class="list-head">{group.name} · {tr(`${num(group.items.length)} items`, `${num(group.items.length)} सामान`)}</div>
        {#each group.items as item (item.id)}
          {@const n = orderOf(item)}
          <div class="row">
            <input
              type="checkbox"
              checked={isPicked(item)}
              onchange={(e) => (picked = { ...picked, [String(item.id)]: e.currentTarget.checked })}
              aria-label={item.name}
              style="width:20px;height:20px;accent-color:var(--primary);flex:none"
            />
            <span class="icon-tile"><span class="ms">{group.icon}</span></span>
            <div class="row-main">
              <div class="row-title">{item.name}</div>
              <div class="row-sub">{tr(`Stock ${num(item.quantity)} · low level ${num(item.low_stock_at)}`, `स्टक ${num(item.quantity)} · कम तह ${num(item.low_stock_at)}`)}</div>
              <div class="progress warn" style="--w:{barWidth(item)}%;margin-top:8px"><span></span></div>
            </div>
            <div class="row-end">
              <span class="tiny muted">{tr('Order', 'अर्डर')}</span>
              <input
                class="input count"
                type="number"
                inputmode="numeric"
                min="1"
                step="1"
                aria-label={tr(`Order quantity for ${item.name}`, `${item.name} को अर्डर संख्या`)}
                value={edits[String(item.id)] ?? String(suggest(item))}
                oninput={(e) => (edits = { ...edits, [String(item.id)]: e.currentTarget.value })}
              />
              {#if n === null}<span class="tiny bad">{tr('1 or more', '१ वा माथि')}</span>{/if}
            </div>
          </div>
        {/each}
      </div>
      <button class="btn btn-primary btn-block" disabled={!group.items.some((i) => isPicked(i) && orderOf(i) !== null)} onclick={() => buy(group)}>
        <span class="ms">shopping_bag</span><span>{tr('Make purchase', 'खरिद गर्ने')}</span>
      </button>
    {/each}
  {/if}
</div>

<style>
  .count {
    width: 88px;
    min-height: 44px;
    text-align: center;
    font-weight: 700;
    flex: none;
  }
</style>
