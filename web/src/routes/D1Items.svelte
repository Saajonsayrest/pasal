<script lang="ts">
  import { api } from '../lib/api'
  import { resource, action, debounce } from '../lib/resource.svelte'
  import { tr, num } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { navigate } from '../lib/router.svelte'
  import { session } from '../lib/session.svelte'
  import { todayAd } from '../lib/bs'
  import type { Category, Item, Summary } from '../lib/types'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Empty from '../components/Empty.svelte'
  import Skeleton from '../components/Skeleton.svelte'

  const VIEW_KEY = 'pasal-items-view'
  const PER_PAGE = 20

  let view = $state<'list' | 'grid'>(localStorage.getItem(VIEW_KEY) === 'grid' ? 'grid' : 'list')

  function setView(next: 'list' | 'grid'): void {
    view = next
    localStorage.setItem(VIEW_KEY, next)
  }

  let typed = $state('')
  let term = $state('')
  let categoryId = $state<number | null>(null)
  let lowOnly = $state(false)
  $effect(() => debounce(() => typed.trim(), 250, (v) => (term = v)))

  let scanCode = $state('')
  let scanNote = $state('')
  const scanning = action()

  async function scan(e: KeyboardEvent): Promise<void> {
    if (e.key !== 'Enter') return
    e.preventDefault()
    const code = scanCode.trim()
    if (!code) return
    const found = await scanning.run(() => api.page<Item>('/items', { search: code, per_page: 50 }))
    if (!found) {
      scanNote = scanning.error?.message ?? ''
      return
    }
    const hit = found.data.find((i) => i.sku !== null && i.sku.toLowerCase() === code.toLowerCase())
    if (hit) {
      scanCode = ''
      scanNote = ''
      navigate(`/items/${hit.id}`)
      return
    }
    scanNote = tr(`No item has the code ${code}`, `${code} कोड भएको सामान छैन`)
  }

  const cats = resource(() => api.all<Category>('/categories'))
  const catName = (id: number | null): string => cats.data?.find((c) => c.id === id)?.name ?? ''

  const query = $derived({
    search: term,
    category_id: categoryId,
    low_stock: lowOnly ? 1 : undefined,
    per_page: PER_PAGE,
  })
  const filtered = $derived(term !== '' || categoryId !== null || lowOnly)

  const list = resource(() => api.page<Item>('/items', { ...query, page: 1 }))
  let more = $state<Item[]>([])
  let pageNo = $state(1)
  $effect(() => {
    void query
    more = []
    pageNo = 1
  })

  const rows = $derived([...(list.data?.data ?? []), ...more])
  const total = $derived(list.data?.meta.total ?? 0)
  const hasMore = $derived(rows.length < total)

  const extend = action()
  async function loadMore(): Promise<void> {
    const before = query
    const res = await extend.run(() => api.page<Item>('/items', { ...before, page: pageNo + 1 }))
    if (!res || query !== before) return
    more = [...more, ...res.data]
    pageNo += 1
  }

  const lowCount = resource(() => api.page<Item>('/items', { low_stock: 1, per_page: 1 }))

  const today = todayAd()
  const summary = resource(() =>
    session.isOwner
      ? api.get<Summary>('/reports/summary', { from: today, to: today })
      : Promise.resolve<Summary | null>(null),
  )
</script>

<div class="page">
  <div class="hstack wrap">
    <label class="search">
      <span class="ms">search</span>
      <input placeholder={tr('Search item name or code', 'सामानको नाम वा कोड खोज्नुहोस्')} bind:value={typed} />
    </label>
    <label class="search scan">
      <span class="ms">barcode_scanner</span>
      <input placeholder={tr('Scan or type a code', 'कोड स्क्यान वा लेख्नुहोस्')} bind:value={scanCode} onkeydown={scan} />
    </label>
  </div>
  {#if scanNote}
    <p class="small bad">{scanNote}</p>
  {/if}

  <div class="chips">
    <button class="chip" class:active={!lowOnly && categoryId === null} onclick={() => { lowOnly = false; categoryId = null }}>{tr('All', 'सबै')}</button>
    <button class="chip" class:active={lowOnly} onclick={() => (lowOnly = !lowOnly)}>
      <span class="ms">warning</span><span>{tr('Low stock', 'कम स्टक')}</span><span class="count">{num(lowCount.data?.meta.total ?? 0)}</span>
    </button>
    {#each cats.data ?? [] as c (c.id)}
      <button class="chip" class:active={categoryId === c.id} onclick={() => (categoryId = categoryId === c.id ? null : c.id)}>{c.name}</button>
    {/each}
  </div>

  <div class="grid-2">
    <div class="card stat">
      <span class="stat-label">{filtered ? tr('Found', 'भेटियो') : tr('Items', 'सामान')}</span>
      <span class="stat-value">{num(total)}</span>
      <span class="stat-sub">{num(lowCount.data?.meta.total ?? 0)} {tr('low on stock', 'कम स्टकमा')}</span>
    </div>
    {#if session.isOwner}
      <div class="card stat">
        <span class="stat-label">{tr('Stock value', 'स्टकको मूल्य')}</span>
        <span class="stat-value">{summary.data ? rs(summary.data.stock_value) : '…'}</span>
        <span class="stat-sub">{tr('At buying price', 'खरिद मूल्यमा')}</span>
      </div>
    {/if}
  </div>

  <div class="seg" style="align-self:flex-start">
    <button class:active={view === 'list'} onclick={() => setView('list')}><span class="ms">view_list</span><span>{tr('List', 'सूची')}</span></button>
    <button class:active={view === 'grid'} onclick={() => setView('grid')}><span class="ms">grid_view</span><span>{tr('Grid', 'ग्रिड')}</span></button>
  </div>

  {#if list.error}
    <ErrorCard error={list.error} retry={list.reload} />
  {:else if list.loading && !list.data}
    <Skeleton rows={6} />
  {:else if rows.length === 0}
    <Empty
      icon="inventory_2"
      title={filtered ? tr('No items found', 'सामान भेटिएन') : tr('No items yet', 'अझै सामान छैन')}
      text={filtered ? tr('Try another word or chip.', 'अर्को शब्द वा चिप प्रयोग गर्नुहोस्।') : session.isOwner ? tr('Add your first item to start selling.', 'बेच्न पहिलो सामान थप्नुहोस्।') : tr('The owner has not added items yet.', 'मालिकले अझै सामान थपेका छैनन्।')}
    >
      {#if session.isOwner && !filtered}
        <a class="btn btn-primary" href="#/items/new"><span class="ms">add</span><span>{tr('Add item', 'सामान थप्ने')}</span></a>
      {/if}
    </Empty>
  {:else if view === 'grid'}
    <div class="item-grid">
      {#each rows as it (it.id)}
        <a class="item-tile" class:low={it.is_low_stock} href={`#/items/${it.id}`}>
          {#if it.photo_url}
            <img class="thumb-lg" src={it.photo_url} alt="" />
          {:else}
            <span class="ms tile-icon">inventory_2</span>
          {/if}
          <span class="name">{it.name}</span>
          <span class="stock"><span>{num(it.quantity)}</span> <span>{it.unit}</span></span>
          <span class="price">{rs(it.sell_price)}</span>
        </a>
      {/each}
    </div>
  {:else}
    <div class="list phone-only">
      {#each rows as it (it.id)}
        <a class="row" href={`#/items/${it.id}`}>
          {#if it.photo_url}
            <img class="thumb" src={it.photo_url} alt="" />
          {:else}
            <span class="icon-tile"><span class="ms">inventory_2</span></span>
          {/if}
          <div class="row-main">
            <div class="row-title">{it.name}</div>
            <div class="row-sub">{num(it.quantity)} {it.unit}{catName(it.category_id) ? ` · ${catName(it.category_id)}` : ''}</div>
          </div>
          <div class="row-end">
            <span class="amount">{rs(it.sell_price)}</span>
            {#if it.is_low_stock}
              <span class="badge warn"><span class="ms">warning</span><span>{tr('Low', 'कम')}</span></span>
            {/if}
          </div>
        </a>
      {/each}
    </div>

    <div class="table-wrap wide-only">
      <table class="table">
        <thead>
          <tr>
            <th>{tr('Name', 'नाम')}</th>
            <th>{tr('Code', 'कोड')}</th>
            <th>{tr('Category', 'वर्ग')}</th>
            <th class="r">{tr('Stock', 'स्टक')}</th>
            <th class="r">{tr('Sell price', 'बिक्री मूल्य')}</th>
            {#if session.isOwner}<th class="r">{tr('Buying price', 'खरिद मूल्य')}</th>{/if}
            <th>{tr('Status', 'अवस्था')}</th>
          </tr>
        </thead>
        <tbody>
          {#each rows as it (it.id)}
            <tr>
              <td><a class="bold" href={`#/items/${it.id}`}>{it.name}</a></td>
              <td>{it.sku ?? ''}</td>
              <td>{catName(it.category_id)}</td>
              <td class="r">{num(it.quantity)} {it.unit}</td>
              <td class="r">{rs(it.sell_price)}</td>
              {#if session.isOwner}<td class="r">{rs(it.cost_price)}</td>{/if}
              <td>
                {#if it.is_low_stock}
                  <span class="badge warn"><span class="ms">warning</span><span>{tr('Low', 'कम')}</span></span>
                {:else}
                  <span class="badge good">{tr('OK', 'ठिक छ')}</span>
                {/if}
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>

    {#if hasMore}
      <button class="btn btn-tonal btn-block" disabled={extend.busy} onclick={loadMore}>
        {extend.busy ? tr('Loading…', 'लोड हुँदैछ…') : tr('Load more', 'थप लोड गर्ने')}
      </button>
    {/if}
    {#if extend.error}
      <div class="alert bad"><span class="ms">error</span><div>{extend.error.message}</div></div>
    {/if}
  {/if}

  {#if session.isOwner}
    <div class="hstack wrap">
      <a class="btn btn-ghost btn-sm" href="#/items/deleted"><span class="ms">delete_sweep</span><span>{tr('Deleted items', 'हटाइएका सामान')}</span></a>
      <a class="btn btn-ghost btn-sm" href="#/categories"><span class="ms">category</span><span>{tr('Categories', 'वर्गहरू')}</span></a>
    </div>
    <a class="fab" href="#/items/new"><span class="ms">add</span><span>{tr('Add item', 'सामान थप्ने')}</span></a>
  {/if}
</div>

<style>
  .scan {
    flex: 0 1 260px;
  }
  .thumb,
  .thumb-lg {
    width: 44px;
    height: 44px;
    border-radius: 14px;
    object-fit: cover;
    flex: none;
  }
  .thumb-lg {
    width: 52px;
    height: 52px;
  }
  .tile-icon {
    font-size: 28px;
    margin-bottom: 4px;
  }
</style>
