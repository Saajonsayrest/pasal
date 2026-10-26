<script lang="ts">
  import { api } from '../lib/api'
  import { resource, action } from '../lib/resource.svelte'
  import { tr, num } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { periodLabel, todayBs } from '../lib/bs'
  import type { VatFiling } from '../lib/types'
  import { FILING_STATUS, dueInDays, errorText, filingStatus, periodTitle, remainingToPay } from '../lib/vat'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Empty from '../components/Empty.svelte'

  const PER_PAGE = 20

  type Filter = 'all' | 'not_filed' | 'filed'
  let filter = $state<Filter>('all')

  const list = resource(() => api.page<VatFiling>('/vat/filings', { per_page: PER_PAGE }))
  let extra = $state<VatFiling[]>([])
  let extraPage = $state(1)
  const more = action()

  const rows = $derived([...(list.data?.data ?? []), ...extra])
  const hasMore = $derived(list.data !== undefined && extraPage < (list.data.meta.last_page ?? 1))
  const shown = $derived(rows.filter((f) => filter === 'all' || (filter === 'filed' ? !!f.filed_on : !f.filed_on)))

  const unpaid = $derived(rows.filter((f) => remainingToPay(f) > 0))
  const stillToPay = $derived(unpaid.reduce((sum, f) => sum + remainingToPay(f), 0))
  // Rows are newest first, so the last unpaid row is the oldest one.
  const oldestUnpaid = $derived(unpaid.length ? unpaid[unpaid.length - 1] : null)

  const thisLabel = periodLabel(todayBs().year, todayBs().month)
  const thisSaved = $derived(rows.some((f) => f.period === thisLabel))

  function dueText(days: number): string {
    if (days < 0) return tr(`${num(-days)} days past due`, `${num(-days)} दिन नाघेको`)
    return tr(`due in ${num(days)} days`, `${num(days)} दिनमा तिर्नुपर्ने`)
  }

  function retry(): void {
    extra = []
    extraPage = 1
    void list.reload()
  }

  async function loadMore(): Promise<void> {
    const next = extraPage + 1
    const res = await more.run(() => api.page<VatFiling>('/vat/filings', { per_page: PER_PAGE, page: next }))
    if (!res) return
    extra = [...extra, ...res.data]
    extraPage = next
  }
</script>

<div class="page">
  {#if list.error}
    <ErrorCard error={list.error} retry={retry} />
  {:else if list.loading && !list.data}
    <Skeleton rows={5} />
  {:else if rows.length === 0}
    <Empty icon="receipt_long" title={tr('No VAT filings yet', 'अहिलेसम्म भ्याट फाइलिङ छैन')} text={tr('Save a month from the VAT screen. It will show here.', 'भ्याट पृष्ठबाट महिना सेभ गर्नुहोस्। यहाँ देखिनेछ।')}>
      <a class="btn btn-primary" href="#/vat"><span class="ms">receipt_long</span><span>{tr('Go to VAT this month', 'यो महिनाको भ्याट')}</span></a>
    </Empty>
  {:else}
    <section class="hero warn">
      <div class="stat">
        <span class="stat-label">{tr('Still to pay', 'अझै तिर्नुपर्ने')}</span>
        <span class="stat-value lg">{rs(stillToPay, { paisa: true })}</span>
        {#if oldestUnpaid}
          <span class="stat-sub">{periodTitle(oldestUnpaid.period)} · {dueText(dueInDays(oldestUnpaid.period_to))}</span>
        {:else}
          <span class="stat-sub">{tr('Nothing left to pay', 'तिर्नु बाँकी छैन')}</span>
        {/if}
        {#if hasMore}<span class="stat-sub">{tr('Counts the filings loaded so far', 'हालसम्म देखिएका फाइलिङ मात्र गनिएको')}</span>{/if}
      </div>
    </section>

    <div class="chips">
      <button class="chip" class:active={filter === 'all'} onclick={() => (filter = 'all')}>{tr('All', 'सबै')}</button>
      <button class="chip" class:active={filter === 'not_filed'} onclick={() => (filter = 'not_filed')}>{tr('Not filed', 'फाइल नभएको')}</button>
      <button class="chip" class:active={filter === 'filed'} onclick={() => (filter = 'filed')}>{tr('Filed', 'फाइल भएको')}</button>
    </div>

    {#if !thisSaved && list.data}
      <p class="small muted">{tr(`${periodTitle(thisLabel)} is not saved yet.`, `${periodTitle(thisLabel)} अहिलेसम्म सेभ भएको छैन।`)}</p>
    {/if}

    {#if shown.length === 0}
      <p class="small muted">{tr('No filings in this group yet.', 'यो समूहमा अहिलेसम्म फाइलिङ छैन।')}</p>
    {/if}

    <div class="list">
      {#each shown as f (f.id)}
        {@const s = FILING_STATUS[filingStatus(f)]}
        <a class="row" href={`#/vat/filings/${f.id}`}>
          <span class="icon-tile {s.cls}"><span class="ms">{s.icon}</span></span>
          <div class="row-main">
            <div class="row-title">{periodTitle(f.period)}</div>
            <div class="row-sub">
              {#if f.source === 'manual'}
                <span class="badge info">{tr('Typed in', 'हातले भरेको')}</span>
              {:else}
                {tr('Made from our bills', 'हाम्रा बिलबाट बनेको')}
              {/if}
            </div>
          </div>
          <div class="row-end">
            <span class="amount">{rs(f.payable, { paisa: true })}</span>
            <span class="badge {s.cls}">{tr(s.en, s.ne)}</span>
          </div>
          <span class="ms chev">chevron_right</span>
        </a>
      {/each}
    </div>

    {#if more.error}
      <div class="alert bad"><span class="ms">error</span><div>{errorText(more.error)}</div></div>
    {/if}
    {#if hasMore}
      <div class="hstack" style="justify-content:center">
        <button class="btn btn-tonal" onclick={loadMore} disabled={more.busy}>
          {more.busy ? tr('Loading…', 'लोड हुँदैछ…') : tr('Load more', 'अरू हेर्ने')}
        </button>
      </div>
    {/if}
  {/if}

  <a class="fab" href="#/vat/old-return"><span class="ms">add</span><span>{tr('Add old return', 'पुरानो रिटर्न थप्ने')}</span></a>
</div>
