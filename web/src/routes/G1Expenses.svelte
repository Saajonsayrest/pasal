<script lang="ts">
  import { api } from '../lib/api'
  import { resource } from '../lib/resource.svelte'
  import { tr, num, plural } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { bsMonthRange, todayAd, todayBs, adOfStamp, monthTitle, formatDate } from '../lib/bs'
  import type { Expense } from '../lib/types'
  import MonthNav from '../components/MonthNav.svelte'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Empty from '../components/Empty.svelte'

  const CATS = [
    { key: 'bills', en: 'Bills', ne: 'बिल', icon: 'bolt' },
    { key: 'rent', en: 'Rent', ne: 'भाडा', icon: 'home' },
    { key: 'salary', en: 'Salary', ne: 'तलब', icon: 'payments' },
    { key: 'transport', en: 'Transport', ne: 'यातायात', icon: 'directions_bus' },
    { key: 'repair', en: 'Repair', ne: 'मर्मत', icon: 'build' },
    { key: 'tea and snacks', en: 'Tea and snacks', ne: 'चिया र खाजा', icon: 'local_cafe' },
    { key: 'other', en: 'Other', ne: 'अन्य', icon: 'more_horiz' },
  ]
  const COLORS = ['var(--primary)', 'var(--info)', 'var(--warn)', 'var(--good)', 'var(--muted)']

  const now = todayBs()
  let year = $state(now.year)
  let month = $state(now.month)
  let picked = $state('all')

  const adDay = (stamp: string) => (stamp.length > 10 ? adOfStamp(stamp) : stamp)
  const catKey = (c: string | null) => (c ?? '').trim().toLowerCase()
  const catIcon = (key: string) => CATS.find((c) => c.key === key)?.icon ?? 'more_horiz'
  function catName(key: string): string {
    const known = CATS.find((c) => c.key === key)
    if (known) return tr(known.en, known.ne)
    return key || tr('No category', 'वर्ग छैन')
  }

  // Expenses come newest first. Read pages until the rows are older than the month, then keep this month only.
  async function loadMonth(from: string, to: string): Promise<Expense[]> {
    const rows: Expense[] = []
    for (let page = 1; page <= 200; page++) {
      const res = await api.page<Expense>('/expenses', { per_page: 50, page })
      rows.push(...res.data)
      const oldest = res.data.at(-1)
      if (!oldest || adDay(oldest.spent_at) < from) break
      if (res.meta.current_page >= (res.meta.last_page ?? 1)) break
    }
    return rows.filter((e) => adDay(e.spent_at) >= from && adDay(e.spent_at) <= to)
  }

  const list = resource(() => {
    const range = bsMonthRange(year, month)
    return loadMonth(range.from, range.to)
  })

  const rows = $derived(list.data ?? [])
  const total = $derived(rows.reduce((sum, e) => sum + e.amount, 0))

  const cats = $derived.by(() => {
    const map = new Map<string, { key: string; total: number }>()
    for (const e of rows) {
      const key = catKey(e.category)
      const c = map.get(key) ?? { key, total: 0 }
      c.total += e.amount
      map.set(key, c)
    }
    return [...map.values()].sort((a, b) => b.total - a.total)
  })
  const activePick = $derived(cats.some((c) => c.key === picked) ? picked : 'all')
  const top = $derived(cats[0])
  const topShare = $derived(top && total > 0 ? Math.round((top.total * 100) / total) : 0)

  const shown = $derived(activePick === 'all' ? rows : rows.filter((e) => catKey(e.category) === activePick))
  const shownTotal = $derived(shown.reduce((sum, e) => sum + e.amount, 0))

  const groups = $derived.by(() => {
    const out: { day: string; rows: Expense[] }[] = []
    for (const e of shown) {
      const day = adDay(e.spent_at)
      const last = out.at(-1)
      if (last && last.day === day) last.rows.push(e)
      else out.push({ day, rows: [e] })
    }
    return out
  })

  const dayLabel = (day: string) => (day === todayAd() ? `${tr('Today', 'आज')} · ${formatDate(day)}` : formatDate(day))
</script>

<div class="page">
  <MonthNav bind:year bind:month />

  {#if list.error}
    <ErrorCard error={list.error} retry={list.reload} />
  {:else if list.loading && !list.data}
    <Skeleton card />
    <Skeleton rows={4} />
  {:else}
    <section class="hero soft">
      <div class="stat">
        <span class="stat-label">{tr(`${monthTitle(year, month)} expenses`, `${monthTitle(year, month)} को खर्च`)}</span>
        <span class="stat-value xl">{rs(total)}</span>
        <span class="stat-sub">{num(rows.length)} {plural(rows.length, 'entry', 'entries', 'खर्च')}</span>
      </div>
    </section>

    {#if cats.length > 0}
      <section class="card">
        <div class="card-head"><h3>{tr('Where it went', 'खर्च कहाँ गयो')}</h3></div>
        <div class="hstack wrap" style="gap:18px">
          <div class="donut" style={`--a:${topShare}`}>
            <div class="stack-sm" style="gap:0;text-align:center">
              <span class="tiny muted">{top ? catName(top.key) : ''}</span>
              <span>{num(topShare)}%</span>
            </div>
          </div>
          <div class="legend">
            {#each cats as c, i (c.key)}
              <div><i style={`--c:${COLORS[i % COLORS.length]}`}></i>{catName(c.key)} · {rs(c.total)}</div>
            {/each}
          </div>
        </div>
      </section>

      <div class="chips">
        <button class="chip" class:active={activePick === 'all'} onclick={() => (picked = 'all')}>{tr('All', 'सबै')}</button>
        {#each cats as c (c.key)}
          <button class="chip" class:active={activePick === c.key} onclick={() => (picked = c.key)}>
            <span class="ms">{catIcon(c.key)}</span><span>{catName(c.key)}</span>
          </button>
        {/each}
      </div>
    {/if}

    {#if shown.length === 0}
      <Empty icon="receipt_long" title={tr('No expenses this month', 'यो महिनामा खर्च छैन')} text={tr('Add what you spent, like rent or electricity.', 'भाडा वा बिजुली जस्ता खर्च थप्नुहोस्।')}>
        <a class="btn btn-primary" href="#/expenses/new"><span class="ms">add</span><span>{tr('Add expense', 'खर्च थप्ने')}</span></a>
      </Empty>
    {:else}
      {#if activePick !== 'all'}
        <p class="small muted">{catName(activePick)}: {rs(shownTotal)}</p>
      {/if}

      <div class="list phone-only">
        {#each groups as g (g.day)}
          <div class="list-head">{dayLabel(g.day)}</div>
          {#each g.rows as e (e.id)}
            <div class="row">
              <span class="icon-tile"><span class="ms">{catIcon(catKey(e.category))}</span></span>
              <div class="row-main">
                <div class="row-title">{e.title}</div>
                <div class="row-sub">{catName(catKey(e.category))}</div>
              </div>
              <span class="amount">{rs(e.amount)}</span>
            </div>
          {/each}
        {/each}
      </div>

      <div class="table-wrap wide-only">
        <table class="table">
          <thead>
            <tr>
              <th>{tr('Date', 'मिति')}</th>
              <th>{tr('What it was for', 'किनका लागि')}</th>
              <th>{tr('Category', 'वर्ग')}</th>
              <th class="r">{tr('Amount', 'रकम')}</th>
            </tr>
          </thead>
          <tbody>
            {#each shown as e (e.id)}
              <tr>
                <td>{formatDate(adDay(e.spent_at))}</td>
                <td>{e.title}</td>
                <td>{catName(catKey(e.category))}</td>
                <td class="r">{rs(e.amount)}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {/if}
  {/if}

  <a class="fab" href="#/expenses/new"><span class="ms">add</span><span>{tr('Add expense', 'खर्च थप्ने')}</span></a>
</div>
