<script lang="ts">
  import { api } from '../lib/api'
  import { resource } from '../lib/resource.svelte'
  import { tr, num } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { rangeFor } from '../lib/range'
  import type { ItemsReport } from '../lib/types'
  import RangePicker from '../components/RangePicker.svelte'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Empty from '../components/Empty.svelte'

  type Tab = 'top' | 'slow'
  type Sort = 'money' | 'quantity'

  const first = rangeFor('month')
  let from = $state(first.from)
  let to = $state(first.to)
  let tab = $state<Tab>('top')
  let sort = $state<Sort>('money')

  const report = resource(() => api.get<ItemsReport>('/reports/items', { from, to, limit: 20 }))
  const data = $derived(report.data)

  const top = $derived.by(() => {
    const rows = [...(data?.top ?? [])]
    rows.sort((a, b) => (sort === 'money' ? b.revenue - a.revenue : b.quantity - a.quantity))
    return rows
  })
  const topPeak = $derived(Math.max(1, ...top.map((r) => (sort === 'money' ? r.revenue : r.quantity))))
  const topTotal = $derived((data?.top ?? []).reduce((n, r) => n + r.revenue, 0))

  const slow = $derived(data?.slow ?? [])
  const stuck = $derived(slow.reduce((n, r) => n + r.stock_value, 0))
</script>

<div class="page">
  <RangePicker bind:from bind:to />

  <div class="seg block">
    <button class:active={tab === 'top'} onclick={() => (tab = 'top')}>{tr('Top sellers', 'धेरै बिक्ने')}</button>
    <button class:active={tab === 'slow'} onclick={() => (tab = 'slow')}>{tr('Slow items', 'कम बिक्ने')}</button>
  </div>

  {#if report.error}
    <ErrorCard error={report.error} retry={report.reload} />
  {:else if !data}
    <Skeleton card />
    <Skeleton rows={4} />
  {:else if tab === 'top'}
    <div class="chips">
      <button class="chip" class:active={sort === 'money'} onclick={() => (sort = 'money')}>{tr('By money', 'रकमअनुसार')}</button>
      <button class="chip" class:active={sort === 'quantity'} onclick={() => (sort = 'quantity')}>{tr('By quantity', 'संख्याअनुसार')}</button>
    </div>

    {#if top.length === 0}
      <Empty icon="trending_up" title={tr('No sales in these dates', 'यो मितिमा बिक्री छैन')} text={tr('Pick other dates above.', 'माथि अर्को मिति छान्नुहोस्।')} />
    {:else}
      <section class="card">
        <div class="stat">
          <span class="stat-label">{tr(`Top ${num(top.length)} items sold`, `शीर्ष ${num(top.length)} सामानको बिक्री`)}</span>
          <span class="stat-value">{rs(topTotal)}</span>
          <span class="stat-sub">{tr('Sales from these items in the dates you picked', 'छानेका मितिमा यी सामानको बिक्री')}</span>
        </div>
      </section>

      <div class="list">
        {#each top as r, i (r.item_id)}
          <div class="row">
            <span class="bold num" style="width:16px">{num(i + 1)}</span>
            <div class="row-main">
              <div class="row-title">{r.name}</div>
              <div class="row-sub">{tr(`${num(r.quantity)} ${r.unit} sold`, `${num(r.quantity)} ${r.unit} बिक्यो`)}</div>
              <div class="progress" style="--w:{Math.max(0, ((sort === 'money' ? r.revenue : r.quantity) / topPeak) * 100)}%;margin-top:8px"><span></span></div>
            </div>
            <div class="row-end"><span class="amount">{rs(r.revenue)}</span></div>
          </div>
        {/each}
      </div>
    {/if}
  {:else}
    {#if slow.length === 0}
      <Empty icon="inventory_2" title={tr('No stock to check', 'जाँच गर्ने स्टक छैन')} text={tr('Items in stock show here.', 'स्टकमा भएका सामान यहाँ देखिन्छन्।')} />
    {:else}
      <section class="card">
        <div class="stat">
          <span class="stat-label">{tr('Stock value stuck', 'अड्किएको स्टकको मूल्य')}</span>
          <span class="stat-value">{rs(stuck)}</span>
          <span class="stat-sub">{tr(`${num(slow.length)} items in stock that sold the least`, `कम बिक्ने ${num(slow.length)} सामान स्टकमा छन्`)}</span>
        </div>
      </section>

      <div class="list">
        {#each slow as r (r.item_id)}
          <div class="row">
            <span class="icon-tile"><span class="ms">inventory_2</span></span>
            <div class="row-main">
              <div class="row-title">{r.name}</div>
              <div class="row-sub">{tr(`${num(r.in_stock)} ${r.unit} left · ${num(r.sold)} sold`, `${num(r.in_stock)} ${r.unit} बाँकी · ${num(r.sold)} बिक्यो`)}</div>
            </div>
            <div class="row-end">
              <span class="amount">{rs(r.stock_value)}</span>
              {#if r.sold === 0}<span class="badge warn">{tr('Not sold', 'बिक्री भएन')}</span>{/if}
            </div>
          </div>
        {/each}
      </div>
    {/if}
  {/if}
</div>
