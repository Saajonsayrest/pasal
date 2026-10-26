<script lang="ts">
  import { api } from '../lib/api'
  import { resource, debounce } from '../lib/resource.svelte'
  import { tr, num } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { formatDate } from '../lib/bs'
  import { initials } from '../lib/util'
  import type { Paged, Supplier } from '../lib/types'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Empty from '../components/Empty.svelte'

  type Result = Paged<Supplier> & { summary: { owed_total: number } }

  let typed = $state('')
  let term = $state('')
  let owedOnly = $state(false)

  $effect(() => debounce(() => typed, 250, (v) => (term = v)))

  const list = resource(() => api.get<Result>('/suppliers', { search: term, owed: owedOnly, per_page: 50 }))
  const rows = $derived(list.data?.data ?? [])
  const total = $derived(list.data?.meta.total ?? 0)

  function owes(s: Supplier): boolean {
    return (s.we_owe ?? 0) > 0
  }

  function lastPurchase(s: Supplier): string {
    if (!s.last_purchase_at) return tr('No purchases yet', 'खरिद छैन')
    const day = formatDate(s.last_purchase_at)
    return tr(`Last purchase: ${day}`, `अन्तिम खरिद: ${day}`)
  }
</script>

<div class="page">
  <section class="hero soft">
    <div class="stat">
      <span class="stat-label">{tr('We owe', 'हामीले तिर्न बाँकी')}</span>
      <span class="stat-value xl">{rs(list.data?.summary.owed_total ?? 0)}</span>
      <span class="stat-sub">{tr('Across all suppliers', 'सबै डिलरमा')}</span>
    </div>
  </section>

  <label class="search">
    <span class="ms">search</span>
    <input placeholder={tr('Search supplier name or phone', 'डिलरको नाम वा फोन खोज्नुहोस्')} bind:value={typed} />
  </label>

  <div class="chips">
    <button class="chip" class:active={!owedOnly} onclick={() => (owedOnly = false)}>{tr('All', 'सबै')}</button>
    <button class="chip" class:active={owedOnly} onclick={() => (owedOnly = true)}>{tr('We owe', 'हामीले तिर्ने')}</button>
  </div>

  {#if list.error}
    <ErrorCard error={list.error} retry={list.reload} />
  {:else if list.loading && !list.data}
    <Skeleton rows={5} />
  {:else if rows.length === 0}
    <Empty
      icon="storefront"
      title={term || owedOnly ? tr('No suppliers found', 'डिलर भेटिएन') : tr('No suppliers yet', 'अहिलेसम्म डिलर छैन')}
      text={tr('Add the shops and dealers you buy stock from.', 'सामान किन्ने पसल वा डिलर थप्नुहोस्।')}
    >
      <a class="btn btn-primary" href="#/suppliers/new"><span class="ms">add</span><span>{tr('Add supplier', 'डिलर थप्ने')}</span></a>
    </Empty>
  {:else}
    <div class="list phone-only">
      {#each rows as s (s.id)}
        <a class="row" href={`#/suppliers/${s.id}`}>
          <span class="avatar" class:info={owes(s)} class:good={!owes(s)}>{initials(s.name)}</span>
          <div class="row-main">
            <div class="row-title">{s.name}</div>
            <div class="row-sub">{s.phone ?? ''}{s.phone ? ' · ' : ''}{lastPurchase(s)}</div>
          </div>
          <div class="row-end">
            {#if owes(s)}
              <span class="amount warn">{rs(s.we_owe)}</span><span class="tiny warn">{tr('We owe', 'हामीले तिर्ने')}</span>
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
            <th>{tr('Supplier', 'डिलर')}</th>
            <th>{tr('Phone', 'फोन')}</th>
            <th>{tr('Last purchase', 'अन्तिम खरिद')}</th>
            <th class="r">{tr('We owe', 'हामीले तिर्ने')}</th>
          </tr>
        </thead>
        <tbody>
          {#each rows as s (s.id)}
            <tr>
              <td><a class="bold" href={`#/suppliers/${s.id}`}>{s.name}</a></td>
              <td>{s.phone ?? ''}</td>
              <td>{s.last_purchase_at ? formatDate(s.last_purchase_at) : tr('No purchases yet', 'खरिद छैन')}</td>
              <td class="r">
                {#if owes(s)}<span class="amount warn">{rs(s.we_owe)}</span>{:else}<span class="badge good">{tr('Paid up', 'सबै चुक्ता')}</span>{/if}
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>

    {#if total > rows.length}
      <p class="small muted center">
        {tr(`Showing ${num(rows.length)} of ${num(total)}. Search to find the others.`, `${num(total)} मध्ये ${num(rows.length)} देखाइएको। बाँकी खोज्न नाम लेख्नुहोस्।`)}
      </p>
    {/if}
  {/if}

  <a class="fab" href="#/suppliers/new"><span class="ms">add</span><span>{tr('Add supplier', 'डिलर थप्ने')}</span></a>
</div>
