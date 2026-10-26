<script lang="ts">
  import { api } from '../lib/api'
  import { resource, debounce } from '../lib/resource.svelte'
  import { tr, num } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { initials } from '../lib/util'
  import { daysUntil, adOfStamp } from '../lib/bs'
  import type { Customer, Paged } from '../lib/types'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Empty from '../components/Empty.svelte'

  type Filter = 'all' | 'owes' | 'over_limit' | 'paid_up'
  type Sort = 'owed' | 'name' | 'oldest'

  let typed = $state('')
  let term = $state('')
  let filter = $state<Filter>('all')
  let sort = $state<Sort>('owed')

  $effect(() => debounce(() => typed, 250, (v) => (term = v)))

  type Summary = { owed_total: number; owing_customers: number }
  const list = resource(() =>
    api.get<Paged<Customer> & { summary: Summary }>('/customers', {
      search: term,
      sort,
      owes: filter === 'owes',
      over_limit: filter === 'over_limit',
      paid_up: filter === 'paid_up',
    }),
  )

  function lastBill(c: Customer & { last_sale_at?: string | null }): string {
    if (!c.last_sale_at) return tr('No bills yet', 'बिल छैन')
    const days = -daysUntil(adOfStamp(c.last_sale_at))
    if (days <= 0) return tr('last bill today', 'अन्तिम बिल आज')
    if (days === 1) return tr('last bill yesterday', 'अन्तिम बिल हिजो')
    return tr(`last bill ${days} days ago`, `अन्तिम बिल ${num(days)} दिन अघि`)
  }

  type Row = Customer & { owes?: number; last_sale_at?: string | null }
  const rows = $derived((list.data?.data ?? []) as Row[])
</script>

<div class="page">
  <section class="hero warn">
    <div class="stat">
      <span class="stat-label">{tr('To collect', 'उठाउन बाँकी')}</span>
      <span class="stat-value xl warn">{rs(list.data?.summary.owed_total ?? 0)}</span>
      <span class="stat-sub">{tr(`from ${list.data?.summary.owing_customers ?? 0} customers`, `${num(list.data?.summary.owing_customers ?? 0)} ग्राहकबाट`)}</span>
    </div>
  </section>

  <label class="search">
    <span class="ms">search</span>
    <input placeholder={tr('Search name or phone', 'नाम वा फोन खोज्नुहोस्')} bind:value={typed} />
  </label>

  <div class="chips">
    {#each [['all', 'All', 'सबै'], ['owes', 'Owes money', 'बाँकी छ'], ['over_limit', 'Over limit', 'सीमा नाघेको'], ['paid_up', 'Paid up', 'सबै चुक्ता']] as [key, en, ne]}
      <button class="chip" class:active={filter === key} onclick={() => (filter = key as Filter)}>{tr(en, ne)}</button>
    {/each}
  </div>

  <div class="hstack between">
    <span class="small muted">{tr('Sort', 'क्रम')}</span>
    <div class="seg">
      <button class:active={sort === 'owed'} onclick={() => (sort = 'owed')}>{tr('Most owed', 'सबैभन्दा बढी बाँकी')}</button>
      <button class:active={sort === 'name'} onclick={() => (sort = 'name')}>{tr('Name', 'नाम')}</button>
      <button class:active={sort === 'oldest'} onclick={() => (sort = 'oldest')}>{tr('Oldest', 'सबैभन्दा पुरानो')}</button>
    </div>
  </div>

  {#if list.error}
    <ErrorCard error={list.error} retry={list.reload} />
  {:else if list.loading && !list.data}
    <Skeleton rows={6} />
  {:else if rows.length === 0}
    <Empty icon="group" title={tr('No customers found', 'ग्राहक भेटिएन')} text={tr('Add your first customer to start keeping credit (udhar).', 'उधारो राख्न पहिलो ग्राहक थप्नुहोस्।')}>
      <a class="btn btn-primary" href="#/customers/new"><span class="ms">person_add</span><span>{tr('Add customer', 'ग्राहक थप्ने')}</span></a>
    </Empty>
  {:else}
    <div class="list phone-only">
      {#each rows as c (c.id)}
        <a class="row" href={`#/customers/${c.id}`}>
          <span class="avatar" class:warn={(c.owes ?? 0) > 0} class:good={(c.owes ?? 0) <= 0}>{initials(c.name)}</span>
          <div class="row-main">
            <div class="row-title">{c.name}</div>
            <div class="row-sub">{c.phone ?? ''}{c.phone ? ' · ' : ''}{lastBill(c)}</div>
          </div>
          <div class="row-end">
            {#if (c.owes ?? 0) > 0}
              <span class="amount warn">{rs(c.owes)}</span><span class="tiny muted">{tr('To collect', 'उठाउन बाँकी')}</span>
            {:else}
              <span class="amount muted">{rs(0)}</span><span class="badge good">{tr('Paid up', 'सबै चुक्ता')}</span>
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
            <th>{tr('Customer', 'ग्राहक')}</th>
            <th>{tr('Phone', 'फोन')}</th>
            <th>{tr('Last bill', 'अन्तिम बिल')}</th>
            <th class="r">{tr('To collect', 'उठाउन बाँकी')}</th>
          </tr>
        </thead>
        <tbody>
          {#each rows as c (c.id)}
            <tr>
              <td><a class="bold" href={`#/customers/${c.id}`}>{c.name}</a></td>
              <td>{c.phone ?? ''}</td>
              <td>{lastBill(c)}</td>
              <td class="r">
                {#if (c.owes ?? 0) > 0}<span class="amount warn">{rs(c.owes)}</span>{:else}<span class="badge good">{tr('Paid up', 'सबै चुक्ता')}</span>{/if}
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}

  <a class="fab" href="#/customers/new"><span class="ms">person_add</span><span>{tr('Add customer', 'ग्राहक थप्ने')}</span></a>
</div>
