<script lang="ts">
  import { api } from '../lib/api'
  import { resource, debounce, action } from '../lib/resource.svelte'
  import { tr, num } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { bsMonthRange, formatDate, formatTime, todayAd, todayBs } from '../lib/bs'
  import { initials } from '../lib/util'
  import type { Sale } from '../lib/types'
  import BsDatePicker from '../components/BsDatePicker.svelte'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Empty from '../components/Empty.svelte'

  type Period = 'all' | 'today' | 'month' | 'range'

  let period = $state<Period>('today')
  let unpaid = $state(false)
  let typed = $state('')
  let term = $state('')
  let rangeFrom = $state(todayAd())
  let rangeTo = $state(todayAd())
  let more = $state<Sale[]>([])
  let morePage = $state(1)

  $effect(() => debounce(() => typed, 250, (v) => (term = v)))

  function dates(): { from?: string; to?: string } {
    if (period === 'today') return { from: todayAd(), to: todayAd() }
    if (period === 'month') {
      const b = todayBs()
      return bsMonthRange(b.year, b.month)
    }
    if (period === 'range') return { from: rangeFrom, to: rangeTo }
    return {}
  }

  function query(page: number) {
    const d = dates()
    return { search: term, unpaid: unpaid ? 1 : undefined, from: d.from, to: d.to, page }
  }

  const list = resource(() => api.page<Sale>('/sales', query(1)))
  const next = action()

  $effect(() => {
    list.data
    more = []
    morePage = 1
  })

  const rows = $derived([...(list.data?.data ?? []), ...more])
  const count = $derived(list.data?.meta.total ?? 0)
  const net = $derived(rows.reduce((sum, s) => sum + (s.total - s.returned_total), 0))
  const hasMore = $derived(rows.length < count)

  async function loadMore(): Promise<void> {
    const page = morePage + 1
    const res = await next.run(() => api.page<Sale>('/sales', query(page)))
    if (!res) return
    more = [...more, ...res.data]
    morePage = page
  }

  function statusText(s: Sale): { text: string; cls: string } {
    if (s.cancelled_at) return { text: tr('Cancelled', 'रद्द'), cls: 'bad' }
    if (s.returned_total > 0) return { text: tr('Returned', 'फिर्ता'), cls: 'info' }
    if (s.balance > 0) return { text: `${tr('To collect', 'उठाउन बाँकी')} ${rs(s.balance)}`, cls: 'warn' }
    return { text: tr('Paid', 'तिरेको'), cls: 'good' }
  }
</script>

<div class="page">
  <section class="hero">
    <div class="stat">
      <span class="stat-label">{hasMore ? tr('Total so far', 'अहिलेसम्मको जम्मा') : tr('Total sales', 'जम्मा बिक्री')}</span>
      <span class="stat-value xl">{rs(net)}</span>
      <span class="stat-sub">{tr(`${num(count)} bills`, `${num(count)} बिल`)}</span>
    </div>
  </section>

  <label class="search">
    <span class="ms">search</span>
    <input placeholder={tr('Search bill or customer', 'बिल वा ग्राहक खोज्नुहोस्')} bind:value={typed} />
  </label>

  <div class="chips">
    <button class="chip" class:active={period === 'all'} onclick={() => (period = 'all')}>{tr('All', 'सबै')}</button>
    <button class="chip" class:active={period === 'today'} onclick={() => (period = 'today')}>{tr('Today', 'आज')}</button>
    <button class="chip" class:active={period === 'month'} onclick={() => (period = 'month')}>{tr('This month', 'यो महिना')}</button>
    <button class="chip" class:active={period === 'range'} onclick={() => (period = 'range')}>{tr('Date range', 'मिति दायरा')}</button>
    <button class="chip" class:active={unpaid} onclick={() => (unpaid = !unpaid)}>{tr('Unpaid', 'बाँकी')}</button>
  </div>

  {#if period === 'range'}
    <div class="grid-2">
      <BsDatePicker bind:value={rangeFrom} label={tr('From', 'देखि')} max={rangeTo} />
      <BsDatePicker bind:value={rangeTo} label={tr('To', 'सम्म')} min={rangeFrom} />
    </div>
  {/if}

  {#if list.error}
    <ErrorCard error={list.error} retry={list.reload} />
  {:else if list.loading && !list.data}
    <Skeleton rows={6} />
  {:else if rows.length === 0}
    <Empty icon="receipt_long" title={tr('No bills found', 'बिल भेटिएन')} text={tr('Change the filter or make a sale.', 'फिल्टर बदल्नुहोस् वा बिक्री गर्नुहोस्।')}>
      <a class="btn btn-primary" href="#/sell"><span class="ms">add_shopping_cart</span><span>{tr('New sale', 'नयाँ बिक्री')}</span></a>
    </Empty>
  {:else}
    <div class="list phone-only">
      {#each rows as s (s.id)}
        {@const st = statusText(s)}
        <a class="row" href={`#/sales/${s.id}`}>
          {#if s.customer}
            <span class="avatar">{initials(s.customer.name)}</span>
          {:else}
            <span class="avatar"><span class="ms">person</span></span>
          {/if}
          <div class="row-main">
            <div class="row-title">{s.customer?.name ?? tr('Walk-in customer', 'पसलमा आएका ग्राहक')}</div>
            <div class="row-sub">{s.bill_no ?? `#${s.id}`} · {formatTime(s.sold_at)} · {formatDate(s.sold_at)}</div>
          </div>
          <div class="row-end">
            <span class="amount">{rs(s.total)}</span>
            <span class="badge {st.cls}">{st.text}</span>
          </div>
        </a>
      {/each}
    </div>

    <div class="table-wrap wide-only">
      <table class="table">
        <thead>
          <tr>
            <th>{tr('Bill', 'बिल')}</th>
            <th>{tr('Date and time', 'मिति र समय')}</th>
            <th>{tr('Customer', 'ग्राहक')}</th>
            <th class="r">{tr('Total', 'जम्मा')}</th>
            <th class="r">{tr('Paid', 'तिरेको')}</th>
            <th class="r">{tr('Balance', 'बाँकी')}</th>
            <th>{tr('Status', 'स्थिति')}</th>
          </tr>
        </thead>
        <tbody>
          {#each rows as s (s.id)}
            {@const st = statusText(s)}
            <tr>
              <td><a class="bold" href={`#/sales/${s.id}`}>{s.bill_no ?? `#${s.id}`}</a></td>
              <td>{formatDate(s.sold_at)} <span class="tiny muted">{formatTime(s.sold_at)}</span></td>
              <td>{s.customer?.name ?? tr('Walk-in customer', 'पसलमा आएका ग्राहक')}</td>
              <td class="r">{rs(s.total)}</td>
              <td class="r">{rs(s.paid)}</td>
              <td class="r">{rs(s.balance)}</td>
              <td><span class="badge {st.cls}">{st.text}</span></td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>

    {#if hasMore}
      <button class="btn btn-tonal btn-block" disabled={next.busy} onclick={loadMore}>
        {next.busy ? tr('Loading…', 'लोड हुँदैछ…') : tr('Load more', 'अरू हेर्ने')}
      </button>
    {/if}
    {#if next.error}
      <ErrorCard error={next.error} retry={loadMore} />
    {/if}
  {/if}
</div>
