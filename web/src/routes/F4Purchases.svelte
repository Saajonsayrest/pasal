<script lang="ts">
  import { api, ApiError } from '../lib/api'
  import { resource, debounce } from '../lib/resource.svelte'
  import { tr, num, plural } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { bsMonthRange, formatDate, todayBs } from '../lib/bs'
  import { initials } from '../lib/util'
  import type { Meta, Purchase, Supplier } from '../lib/types'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Empty from '../components/Empty.svelte'

  type Filter = 'all' | 'unpaid' | 'month'

  const thisMonth = todayBs()
  const monthRange = bsMonthRange(thisMonth.year, thisMonth.month)

  let filter = $state<Filter>('all')
  let typed = $state('')
  let term = $state('')
  let supplierId = $state('')

  $effect(() => debounce(() => typed, 250, (v) => (term = v)))

  const suppliers = resource(() => api.all<Supplier>('/suppliers', {}, 50))

  const summary = resource(async () => {
    const [monthRows, openRows] = await Promise.all([
      api.all<Purchase>('/purchases', monthRange),
      api.all<Purchase>('/purchases', { unpaid: true }),
    ])
    return {
      monthTotal: monthRows.reduce((sum, p) => sum + p.total, 0),
      monthCount: monthRows.length,
      owed: openRows.reduce((sum, p) => sum + p.balance, 0),
      openCount: openRows.length,
    }
  })

  let rows = $state<Purchase[]>([])
  let meta = $state<Meta | null>(null)
  let loading = $state(true)
  let moreBusy = $state(false)
  let error = $state<ApiError | null>(null)
  let run = 0

  function fetchPage(page: number) {
    return api.page<Purchase>('/purchases', {
      search: term,
      unpaid: filter === 'unpaid' || undefined,
      supplier_id: supplierId,
      from: filter === 'month' ? monthRange.from : undefined,
      to: filter === 'month' ? monthRange.to : undefined,
      page,
      per_page: 20,
    })
  }

  async function load(page: number): Promise<void> {
    const id = ++run
    if (page === 1) loading = true
    try {
      const res = await fetchPage(page)
      if (id !== run) return
      rows = page === 1 ? res.data : [...rows, ...res.data]
      meta = res.meta
      error = null
    } catch (e) {
      if (id === run) error = e instanceof ApiError ? e : new ApiError(0, (e as Error).message)
    } finally {
      if (id === run) {
        loading = false
        moreBusy = false
      }
    }
  }

  $effect(() => {
    void term
    void filter
    void supplierId
    void load(1)
  })

  function loadMore(): void {
    if (!meta) return
    moreBusy = true
    void load(meta.current_page + 1)
  }

  const hasMore = $derived(!!meta && meta.current_page < (meta.last_page ?? 1))
</script>

<div class="page">
  {#if summary.error}
    <ErrorCard error={summary.error} retry={summary.reload} />
  {:else if summary.loading && !summary.data}
    <div class="grid-2"><Skeleton card /><Skeleton card /></div>
  {:else if summary.data}
    <div class="grid-2">
      <div class="card">
        <div class="stat">
          <span class="stat-label">{tr("This month's purchases", 'यो महिनाको खरिद')}</span>
          <span class="stat-value">{rs(summary.data.monthTotal)}</span>
          <span class="stat-sub">{num(summary.data.monthCount)} {plural(summary.data.monthCount, 'bill', 'bills', 'बिल')}</span>
        </div>
      </div>
      <div class="card">
        <div class="stat">
          <span class="stat-label">{tr('Still to pay', 'अझै तिर्नुपर्ने')}</span>
          <span class="stat-value warn">{rs(summary.data.owed)}</span>
          <span class="stat-sub">{tr(`on ${num(summary.data.openCount)} bills`, `${num(summary.data.openCount)} बिलमा`)}</span>
        </div>
      </div>
    </div>
  {/if}

  <div class="chips">
    <button class="chip" class:active={filter === 'all'} onclick={() => (filter = 'all')}>{tr('All', 'सबै')}</button>
    <button class="chip" class:active={filter === 'unpaid'} onclick={() => (filter = 'unpaid')}>{tr('Unpaid', 'बाँकी')}</button>
    <button class="chip" class:active={filter === 'month'} onclick={() => (filter = 'month')}>{tr('This month', 'यो महिना')}</button>
  </div>

  <div class="grid-2">
    <label class="search">
      <span class="ms">search</span>
      <input placeholder={tr('Search bill or supplier', 'बिल वा डिलर खोज्नुहोस्')} bind:value={typed} />
    </label>
    <label class="field">
      <span class="label">{tr('Supplier', 'डिलर')}</span>
      <select bind:value={supplierId} disabled={!suppliers.data}>
        <option value="">{tr('All suppliers', 'सबै डिलर')}</option>
        {#each suppliers.data ?? [] as s (s.id)}
          <option value={String(s.id)}>{s.name}</option>
        {/each}
      </select>
    </label>
  </div>

  {#if error && rows.length === 0}
    <ErrorCard {error} retry={() => load(1)} />
  {:else if loading && rows.length === 0}
    <Skeleton rows={6} />
  {:else if rows.length === 0}
    <Empty
      icon="shopping_bag"
      title={term || filter !== 'all' || supplierId ? tr('No purchases found', 'खरिद भेटिएन') : tr('No purchases yet', 'अहिलेसम्म खरिद छैन')}
      text={tr('Record a bill when stock comes in from a supplier.', 'डिलरबाट सामान आउँदा बिल लेख्नुहोस्।')}
    >
      <a class="btn btn-primary" href="#/purchases/new"><span class="ms">add</span><span>{tr('New purchase', 'नयाँ खरिद')}</span></a>
    </Empty>
  {:else}
    {#if error}
      <ErrorCard {error} retry={() => load(1)} />
    {/if}

    <div class="list phone-only">
      {#each rows as p (p.id)}
        <a class="row" href={`#/purchases/${p.id}`}>
          <span class="avatar" class:info={p.balance > 0} class:good={p.balance <= 0}>{initials(p.supplier?.name ?? '?')}</span>
          <div class="row-main">
            <div class="row-title">{p.supplier?.name ?? tr('Deleted supplier', 'हटाइएको डिलर')}</div>
            <div class="row-sub">{p.bill_no ?? tr('No bill number', 'बिल नम्बर छैन')} · {formatDate(p.bill_date ?? p.bought_at)}</div>
          </div>
          <div class="row-end">
            <span class="amount">{rs(p.total)}</span>
            {#if p.balance > 0}
              <span class="badge warn">{tr('We owe', 'हामीले तिर्ने')} {rs(p.balance)}</span>
            {:else}
              <span class="badge good">{tr('Paid', 'तिरेको')}</span>
            {/if}
          </div>
          <span class="ms chev">chevron_right</span>
        </a>
      {/each}
    </div>

    <div class="table-wrap wide-only">
      <table class="table">
        <thead>
          <tr>
            <th>{tr('Bill', 'बिल')}</th>
            <th>{tr('Supplier', 'डिलर')}</th>
            <th>{tr('Date', 'मिति')}</th>
            <th class="r">{tr('Total', 'जम्मा')}</th>
            <th class="r">{tr('Still to pay', 'बाँकी')}</th>
            <th>{tr('Status', 'स्थिति')}</th>
          </tr>
        </thead>
        <tbody>
          {#each rows as p (p.id)}
            <tr>
              <td><a class="bold" href={`#/purchases/${p.id}`}>{p.bill_no ?? tr('No bill number', 'बिल नम्बर छैन')}</a></td>
              <td>{p.supplier?.name ?? tr('Deleted supplier', 'हटाइएको डिलर')}</td>
              <td>{formatDate(p.bill_date ?? p.bought_at)}</td>
              <td class="r">{rs(p.total)}</td>
              <td class="r">{rs(p.balance)}</td>
              <td>
                {#if p.balance > 0}<span class="badge warn">{tr('We owe', 'हामीले तिर्ने')}</span>{:else}<span class="badge good">{tr('Paid', 'तिरेको')}</span>{/if}
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>

    {#if hasMore}
      <button class="btn btn-tonal btn-block" type="button" disabled={moreBusy} onclick={loadMore}>
        {moreBusy ? tr('Loading…', 'लोड हुँदैछ…') : tr('Load more', 'अरु हेर्ने')}
      </button>
    {/if}
  {/if}

  <a class="fab" href="#/purchases/new"><span class="ms">add</span><span>{tr('New purchase', 'नयाँ खरिद')}</span></a>
</div>
