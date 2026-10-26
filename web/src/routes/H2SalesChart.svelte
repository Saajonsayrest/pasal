<script lang="ts">
  import { api } from '../lib/api'
  import { resource } from '../lib/resource.svelte'
  import { tr, digits, num } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { adToBs, formatDate, formatDateSub } from '../lib/bs'
  import { rangeFor } from '../lib/range'
  import type { DailyReport } from '../lib/types'
  import RangePicker from '../components/RangePicker.svelte'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Empty from '../components/Empty.svelte'

  type Mode = 'day' | 'week' | 'month'
  type Day = DailyReport['days'][number]
  interface Bucket {
    label: string
    from: string
    to: string
    sales: number
    bills: number
  }

  const MODE_NAMES: Record<Mode, [string, string]> = {
    day: ['Day', 'दिन'],
    week: ['Week', 'हप्ता'],
    month: ['Month', 'महिना'],
  }
  const HOUR_FROM = 6
  const HOUR_TO = 22

  const first = rangeFor('month')
  let from = $state(first.from)
  let to = $state(first.to)
  let mode = $state<Mode>('day')
  let picked = $state<number | null>(null)

  const report = resource(() => api.get<DailyReport>('/reports/daily', { from, to }))
  const data = $derived(report.data)
  const days = $derived(data?.days ?? [])

  // Up to 31 bars. A longer range groups by week, and a very long one by month.
  const options = $derived.by(() => {
    const list: Mode[] = []
    if (days.length <= 31) list.push('day')
    if (Math.ceil(days.length / 7) <= 31) list.push('week')
    list.push('month')
    return list
  })
  const active: Mode = $derived(options.includes(mode) ? mode : options[0])

  function groupKey(d: Day, i: number, m: Mode): string {
    if (m === 'day') return d.date
    if (m === 'week') return String(Math.floor(i / 7))
    const b = adToBs(d.date)
    return `${b.year}-${b.month}`
  }

  function labelOf(date: string, m: Mode): string {
    if (m === 'month') return digits(adToBs(date).month)
    return digits(Number(date.slice(8)))
  }

  const buckets = $derived.by(() => {
    const out: Bucket[] = []
    let key = ''
    days.forEach((d, i) => {
      const k = groupKey(d, i, active)
      if (out.length === 0 || k !== key) {
        out.push({ label: labelOf(d.date, active), from: d.date, to: d.date, sales: 0, bills: 0 })
        key = k
      }
      const cur = out[out.length - 1]
      cur.to = d.date
      cur.sales += d.sales
      cur.bills += d.bills
    })
    return out
  })

  const sel = $derived(picked !== null && picked < buckets.length ? picked : buckets.length - 1)
  const shown = $derived(sel >= 0 ? buckets[sel] : undefined)
  const peak = $derived(Math.max(1, ...buckets.map((b) => b.sales)))
  const barPct = (v: number, top: number) => Math.max(0, Math.min(100, (v / top) * 100))
  const avg = (sales: number, bills: number) => (bills > 0 ? Math.round(sales / bills) : 0)

  const bestDay = $derived(days.reduce<Day | null>((best, d) => (d.sales > 0 && (!best || d.sales > best.sales) ? d : best), null))

  const shownHours = $derived((data?.hours ?? []).filter((h) => h.hour >= HOUR_FROM && h.hour <= HOUR_TO))
  const hourPeak = $derived(Math.max(1, ...shownHours.map((h) => h.sales)))
  const busiest = $derived((data?.hours ?? []).reduce<{ hour: number; sales: number } | null>((best, h) => (h.sales > 0 && (!best || h.sales > best.sales) ? h : best), null))
  const outsideBills = $derived((data?.hours ?? []).filter((h) => h.hour < HOUR_FROM || h.hour > HOUR_TO).reduce((n, h) => n + h.bills, 0))

  const hourLabel = (h: number) => digits(h % 12 === 0 ? 12 : h % 12)
  function hourText(h: number): string {
    const h12 = h % 12 === 0 ? 12 : h % 12
    return tr(`${h12}${h < 12 ? 'am' : 'pm'}`, `${h < 12 ? 'बिहान' : 'बेलुका'} ${digits(h12)} बजे`)
  }

  function pick(i: number): void {
    picked = i
  }
</script>

<div class="page">
  <RangePicker bind:from bind:to />

  {#if report.error}
    <ErrorCard error={report.error} retry={report.reload} />
  {:else if !data}
    <Skeleton card />
    <Skeleton card />
  {:else if data.bills === 0}
    <Empty icon="bar_chart" title={tr('No sales in these dates', 'यो मितिमा बिक्री छैन')} text={tr('Pick other dates above.', 'माथि अर्को मिति छान्नुहोस्।')} />
  {:else}
    <section class="card">
      <div class="card-head">
        <h3>{active === 'day' ? tr('Sales per day', 'दिनअनुसार बिक्री') : active === 'week' ? tr('Sales per week', 'हप्ताअनुसार बिक्री') : tr('Sales per month', 'महिनाअनुसार बिक्री')}</h3>
        <span class="small muted">{tr(`${num(data.bills)} bills`, `${num(data.bills)} बिल`)}</span>
      </div>

      {#if options.length > 1}
        <div class="seg block" style="margin-bottom:12px">
          {#each options as m (m)}
            <button class:active={active === m} onclick={() => { mode = m; picked = null }}>{tr(...MODE_NAMES[m])}</button>
          {/each}
        </div>
      {/if}

      <div class="hstack between" style="margin-bottom:10px">
        <span class="stat-value">{rs(data.total)}</span>
        <span class="small muted">{tr('Total', 'जम्मा')}</span>
      </div>

      <div class="bars">
        {#each buckets as b, i (i)}
          <div
            class="bar"
            class:on={i === sel}
            role="button"
            tabindex="0"
            aria-label={b.label}
            onclick={() => pick(i)}
            onkeydown={(e) => { if (e.key === 'Enter') pick(i) }}
            style="--h:{barPct(b.sales, peak)}%;--i:{Math.min(i, 14)}"
          >
            <i></i><span>{b.label}</span>
          </div>
        {/each}
      </div>
      <p class="tiny muted" style="margin-top:8px">{active === 'month' ? tr('Numbers are Nepali months (1 to 12). Tap a bar.', 'अंक नेपाली महिना हुन् (१ देखि १२)। बारमा थिच्नुहोस्।') : tr('Numbers are days of the month (AD). Tap a bar.', 'अंक महिनाका दिन हुन् (AD)। बारमा थिच्नुहोस्।')}</p>

      {#if shown}
        <div class="kv" style="margin-top:8px">
          <div>
            <span class="k">{active === 'day' ? tr('Day', 'दिन') : tr('Period', 'अवधि')}</span>
            <span class="v">{shown.from === shown.to ? formatDate(shown.from) : tr(`${formatDate(shown.from)} to ${formatDate(shown.to)}`, `${formatDate(shown.from)} देखि ${formatDate(shown.to)} सम्म`)}</span>
          </div>
          <div><span class="k">{tr('Total', 'जम्मा')}</span><span class="v">{rs(shown.sales)}</span></div>
          <div><span class="k">{tr('Bills', 'बिल')}</span><span class="v">{num(shown.bills)}</span></div>
          <div><span class="k">{tr('Average per bill', 'औसत बिल')}</span><span class="v">{rs(avg(shown.sales, shown.bills))}</span></div>
        </div>
      {/if}
    </section>

    {#if bestDay}
      <section class="card">
        <div class="hstack">
          <span class="icon-tile good"><span class="ms">emoji_events</span></span>
          <div class="row-main">
            <div class="row-title">{tr('Best day', 'सबैभन्दा राम्रो दिन')}</div>
            <div class="row-sub">{formatDate(bestDay.date)} · {formatDateSub(bestDay.date)}</div>
          </div>
          <span class="amount">{rs(bestDay.sales)}</span>
        </div>
      </section>
    {/if}

    <section class="card">
      <div class="card-head">
        <h3>{tr('Best hours', 'सबैभन्दा बढी बिक्री हुने समय')}</h3>
        <span class="small muted">{tr('6am to 10pm', 'बिहान ६ देखि राति १० सम्म')}</span>
      </div>
      <div class="bars" style="height:120px">
        {#each shownHours as h, i (h.hour)}
          <div class="bar" class:on={busiest?.hour === h.hour} style="--h:{barPct(h.sales, hourPeak)}%;--i:{i}">
            <i></i><span>{hourLabel(h.hour)}</span>
          </div>
        {/each}
      </div>
      {#if busiest}
        <p class="small" style="margin-top:10px">{tr(`Busiest: ${hourText(busiest.hour)}`, `सबैभन्दा व्यस्त: ${hourText(busiest.hour)}`)}</p>
      {/if}
      {#if outsideBills > 0}
        <p class="tiny muted" style="margin-top:4px">{tr(`Bills outside 6am to 10pm: ${num(outsideBills)}. They are not in the bars.`, `बिहान ६ अघि वा राति १० पछिका बिल: ${num(outsideBills)}। ती बारमा छैनन्।`)}</p>
      {/if}
    </section>
  {/if}
</div>
