<script lang="ts">
  import { api } from '../lib/api'
  import { resource } from '../lib/resource.svelte'
  import { tr, num } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { formatDate } from '../lib/bs'
  import { initials, telHref } from '../lib/util'
  import type { CreditAge } from '../lib/types'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Empty from '../components/Empty.svelte'

  const BUCKETS = [
    { key: 'd0_30', en: '0 to 30 days', ne: '0 देखि 30 दिन', color: 'var(--primary)' },
    { key: 'd31_60', en: '31 to 60 days', ne: '31 देखि 60 दिन', color: 'var(--warn)' },
    { key: 'd61_90', en: '61 to 90 days', ne: '61 देखि 90 दिन', color: 'color-mix(in oklab, var(--warn), var(--bad))' },
    { key: 'd90_plus', en: 'Over 90 days', ne: '90 दिनभन्दा बढी', color: 'var(--bad)' },
  ]

  const report = resource(() => api.get<CreditAge>('/reports/credit-age'))
  const data = $derived(report.data)
  const total = $derived(data?.total ?? 0)

  const shares = $derived(
    BUCKETS.map((b) => {
      const found = data?.buckets.find((x) => x.key === b.key)
      const amount = found?.amount ?? 0
      return { ...b, amount, bills: found?.bills ?? 0, share: total > 0 ? (amount / total) * 100 : 0 }
    }),
  )

  let picked = $state<string | null>(null)
  const pickedBucket = $derived(shares.find((b) => b.key === picked) ?? null)
  const list = $derived((data?.customers ?? []).filter((c) => !picked || c.bucket === picked))

  function toggle(key: string): void {
    picked = picked === key ? null : key
  }
</script>

<div class="page">
  {#if report.error}
    <ErrorCard error={report.error} retry={report.reload} />
  {:else if !data}
    <Skeleton card />
    <Skeleton rows={4} />
  {:else if data.customers.length === 0}
    <Empty icon="hourglass_bottom" title={tr('Nobody owes money', 'कसैको उधारो बाँकी छैन')} text={tr('Credit that is not paid shows here, oldest first.', 'नतिरेको उधारो यहाँ देखिन्छ, सबैभन्दा पुरानो पहिले।')} />
  {:else}
    <section class="hero soft">
      <div class="stat">
        <span class="stat-label">{tr('To collect', 'उठाउन बाँकी')}</span>
        <span class="stat-value xl">{rs(total)}</span>
        <span class="stat-sub">{tr(`from ${num(data.customers.length)} customers`, `${num(data.customers.length)} ग्राहकबाट`)}</span>
      </div>
    </section>

    <p class="small muted">{tr(`Money split by how old the unpaid bills are, as of ${formatDate(data.as_of)}. Tap a card to see who owes it.`, `नतिरेका बिल कति पुराना हुन् त्यसअनुसार बाँडिएको, ${formatDate(data.as_of)} सम्मको। कसले कति दिनुपर्ने हेर्न कार्डमा थिच्नुहोस्।`)}</p>

    <div class="progress" style="display:flex">
      {#each shares as b (b.key)}
        <span style="--w:{b.share}%;background:{b.color}"></span>
      {/each}
    </div>

    <div class="grid-4">
      {#each shares as b (b.key)}
        <button type="button" class="card stack-sm" aria-pressed={picked === b.key} style="text-align:left;outline:{picked === b.key ? '2px solid var(--primary)' : 'none'}" onclick={() => toggle(b.key)}>
          <span class="stat-label">{tr(b.en, b.ne)}</span>
          <span class="stat-value" class:bad={b.key === 'd90_plus'} style="font-size:20px">{rs(b.amount)}</span>
          <div class="progress" style="--w:{b.share}%"><span style="background:{b.color}"></span></div>
          <span class="tiny muted">{tr(`${num(b.bills)} bills · ${num(Math.round(b.share))}% of total`, `${num(b.bills)} बिल · कुल बाँकीको ${num(Math.round(b.share))}%`)}</span>
        </button>
      {/each}
    </div>

    <div class="hstack between">
      <span class="bold">{pickedBucket ? tr(pickedBucket.en, pickedBucket.ne) : tr('Oldest first', 'सबैभन्दा पुरानो पहिले')}</span>
      {#if pickedBucket}
        <button class="btn btn-ghost btn-sm" onclick={() => (picked = null)}><span class="ms">list</span><span>{tr('Show all', 'सबै देखाउने')}</span></button>
      {/if}
    </div>

    {#if list.length === 0}
      <Empty icon="check_circle" title={tr('No one in this group', 'यो समूहमा कोही छैन')} />
    {:else}
      <div class="stack">
        {#each list as c (c.customer_id)}
          <div class="card stack-sm">
            <div class="hstack between">
              <div class="hstack">
                <span class="avatar" class:bad={c.bucket === 'd90_plus'} class:warn={c.bucket !== 'd0_30' && c.bucket !== 'd90_plus'}>{initials(c.name ?? '?')}</span>
                <div>
                  {#if c.name}
                    <a class="bold" href={`#/customers/${c.customer_id}`}>{c.name}</a>
                  {:else}
                    <div class="bold">{tr('Deleted customer', 'हटाइएको ग्राहक')}</div>
                  {/if}
                  <div class="small muted">{tr(`Oldest bill ${num(c.oldest_days)} days ago`, `सबैभन्दा पुरानो बिल ${num(c.oldest_days)} दिन अघि`)}</div>
                </div>
              </div>
              <div class="stack-sm" style="align-items:flex-end;gap:0">
                <span class="amount warn">{rs(c.owes)}</span>
                <span class="tiny muted">{tr('To collect', 'उठाउन बाँकी')}</span>
              </div>
            </div>
            <div class="hstack" style="justify-content:flex-end;flex-wrap:wrap">
              {#if c.phone}
                <a class="btn btn-tonal btn-sm" href={telHref(c.phone)}><span class="ms">call</span><span>{tr('Call', 'फोन')}</span></a>
              {/if}
              <a class="btn btn-tonal btn-sm" href={`#/customers/${c.customer_id}/remind`}><span class="ms">notifications_active</span><span>{tr('Remind', 'सम्झाउने')}</span></a>
            </div>
          </div>
        {/each}
      </div>
    {/if}
  {/if}
</div>
