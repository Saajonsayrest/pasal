<script lang="ts">
  import { api } from '../lib/api'
  import { resource } from '../lib/resource.svelte'
  import { session } from '../lib/session.svelte'
  import { tr, num } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { addDaysAd, bsMonthRange, formatDate, formatDateSub, formatTime, monthTitle, todayAd, todayBs, weekday } from '../lib/bs'
  import { dueText, loadOrder, loneCards, nextVat, saveOrder, shortWeekday, type CardKey } from '../lib/home'
  import { portal } from '../lib/portal'
  import { setTitle } from '../lib/shell.svelte'
  import { initials } from '../lib/util'
  import type { CashBook, Customer, CustomerSummary, DailyReport, Item, Paged, Sale, Summary, Supplier, VatPreview } from '../lib/types'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Empty from '../components/Empty.svelte'

  const today = todayAd()
  const bsNow = todayBs()
  const monthFrom = bsMonthRange(bsNow.year, bsNow.month).from
  const weekFrom = addDaysAd(today, -13)
  const vat = nextVat()
  const first = session.user?.name.split(' ')[0] ?? ''
  $effect(() => setTitle(tr(`Namaste, ${first}`, `नमस्ते, ${first}`)))

  const sales = resource(() => api.get<DailyReport>('/reports/daily', { from: today, to: today }))
  const cash = resource(() => api.get<CashBook>('/cash-book', { from: today, to: today, per_page: 1 }))
  const collect = resource(() => api.get<Paged<Customer> & { summary: CustomerSummary }>('/customers', { per_page: 1 }))
  const owe = resource(() => api.get<Paged<Supplier> & { summary: { owed_total: number } }>('/suppliers', { per_page: 1 }))
  const low = resource(() => api.page<Item>('/items', { low_stock: 1, per_page: 1 }))
  const week = resource(() => api.get<DailyReport>('/reports/daily', { from: weekFrom, to: today }))
  const profit = resource(() => api.get<Summary>('/reports/summary', { from: monthFrom, to: today }))
  const vatPreview = resource(() => api.get<VatPreview>('/vat/preview', { from: vat.from, to: vat.to, opening_carry: 0 }))
  const recent = resource(() => api.page<Sale>('/sales', { per_page: 3 }))

  const days = $derived(week.data?.days ?? [])
  const last7 = $derived(days.slice(-7))
  const lastTotal = $derived(last7.reduce((sum, d) => sum + d.sales, 0))
  const prevTotal = $derived(days.slice(0, -7).reduce((sum, d) => sum + d.sales, 0))
  const change = $derived(prevTotal > 0 ? Math.round(((lastTotal - prevTotal) * 100) / prevTotal) : null)
  const peak = $derived(Math.max(1, ...last7.map((d) => d.sales)))

  const share = $derived(
    profit.data && profit.data.sales_total > 0
      ? Math.min(100, Math.max(0, Math.round((profit.data.profit * 100) / profit.data.sales_total)))
      : 0,
  )

  let order = $state<CardKey[]>(loadOrder())
  let editing = $state(false)
  const FULL: CardKey[] = ['sales', 'week']
  const lone = $derived(loneCards(order, FULL)) // a card left alone on its row takes the whole row

  function move(index: number, by: number): void {
    const target = index + by
    if (target < 0 || target >= order.length) return
    const next = [...order]
    const moved = next[index]
    next[index] = next[target]
    next[target] = moved
    order = next
    saveOrder(order)
  }

  function guard(e: MouseEvent): void {
    if (editing) e.preventDefault()
  }
</script>

<div class="page">
  <div use:portal={'#topbar-actions'} class="contents">
    <a class="btn btn-icon" href="#/notifications" aria-label={tr('Notifications', 'सूचनाहरू')}><span class="ms">notifications</span></a>
    <a class="btn btn-icon phone-only" href="#/profile" aria-label={tr('Profile', 'प्रोफाइल')}><span class="avatar" style="width:34px;height:34px;font-size:13px">{initials(session.user?.name ?? '')}</span></a>
  </div>

  <p class="muted small" style="margin:0 4px">{weekday(today)}, {formatDate(today)} · {formatDateSub(today)}</p>

  <section class="quick-actions">
    <a href="#/sell"><span class="qa-icon"><span class="ms">add_shopping_cart</span></span><span>{tr('New sale', 'नयाँ बिक्री')}</span></a>
    <a href="#/items/new"><span class="qa-icon"><span class="ms">add_box</span></span><span>{tr('Add item', 'सामान थप्ने')}</span></a>
    <a href="#/customers"><span class="qa-icon"><span class="ms">call_received</span></span><span>{tr('Take payment', 'पैसा लिने')}</span></a>
    <a href="#/expenses/new"><span class="qa-icon"><span class="ms">payments</span></span><span>{tr('Add expense', 'खर्च थप्ने')}</span></a>
  </section>

  <div class="hstack between">
    <span class="small muted">{tr('Your cards', 'तपाईंका कार्ड')}</span>
    <button class="btn btn-tonal btn-sm" type="button" onclick={() => (editing = !editing)}>
      <span class="ms">{editing ? 'check' : 'edit'}</span><span>{editing ? tr('Done', 'भयो') : tr('Edit', 'सम्पादन')}</span>
    </button>
  </div>

  <div class="grid-2 wide-2">
    {#each order as key, i (key)}
      <div class="grid-cell" style:grid-column={FULL.includes(key) || lone.has(key) ? '1 / -1' : null}>
        {#if editing}
          <div class="hstack" style="justify-content:flex-end;gap:6px;margin-bottom:6px">
            <button class="btn btn-icon btn-sm" type="button" aria-label={tr('Move up', 'माथि सार्ने')} disabled={i === 0} onclick={() => move(i, -1)}><span class="ms">arrow_upward</span></button>
            <button class="btn btn-icon btn-sm" type="button" aria-label={tr('Move down', 'तल सार्ने')} disabled={i === order.length - 1} onclick={() => move(i, 1)}><span class="ms">arrow_downward</span></button>
          </div>
        {/if}

        {#if key === 'sales'}
          <section class="hero">
            {#if sales.error}
              <ErrorCard error={sales.error} retry={sales.reload} />
            {:else if sales.loading && !sales.data}
              <Skeleton card />
            {:else}
              <div class="hstack between">
                <div class="stat">
                  <span class="stat-label">{tr("Today's sales", 'आजको बिक्री')}</span>
                  <span class="stat-value xl">{rs(sales.data?.total)}</span>
                </div>
                <span class="badge" style="background:rgb(255 255 255 / .18);color:#fff">{num(sales.data?.bills ?? 0)} {tr('bills', 'बिल')}</span>
              </div>
            {/if}
          </section>
        {:else if key === 'cash'}
          {#if cash.error}
            <div class="card"><ErrorCard error={cash.error} retry={cash.reload} /></div>
          {:else if cash.loading && !cash.data}
            <div class="card"><Skeleton card /></div>
          {:else}
            <a class="card" href="#/cash-book" onclick={guard}>
              <div class="stat-icon good"><span class="ms">account_balance_wallet</span></div>
              <div class="stat">
                <span class="stat-label">{tr('Money received today', 'आज प्राप्त रकम')}</span>
                <span class="stat-value">{rs(cash.data?.money_in)}</span>
              </div>
            </a>
          {/if}
        {:else if key === 'collect'}
          {#if collect.error}
            <div class="card"><ErrorCard error={collect.error} retry={collect.reload} /></div>
          {:else if collect.loading && !collect.data}
            <div class="card"><Skeleton card /></div>
          {:else}
            <a class="card" href="#/customers" onclick={guard}>
              <div class="stat-icon warn"><span class="ms">call_received</span></div>
              <div class="stat">
                <span class="stat-label">{tr('To collect', 'उठाउन बाँकी')}</span>
                <span class="stat-value">{rs(collect.data?.summary.owed_total)}</span>
                <span class="stat-sub">{tr(`from ${num(collect.data?.summary.owing_customers ?? 0)} customers`, `${num(collect.data?.summary.owing_customers ?? 0)} ग्राहकबाट`)}</span>
              </div>
            </a>
          {/if}
        {:else if key === 'owe'}
          {#if owe.error}
            <div class="card"><ErrorCard error={owe.error} retry={owe.reload} /></div>
          {:else if owe.loading && !owe.data}
            <div class="card"><Skeleton card /></div>
          {:else}
            <a class="card" href="#/suppliers" onclick={guard}>
              <div class="stat-icon info"><span class="ms">call_made</span></div>
              <div class="stat">
                <span class="stat-label">{tr('We owe', 'हामीले तिर्न बाँकी')}</span>
                <span class="stat-value">{rs(owe.data?.summary.owed_total)}</span>
                <span class="stat-sub">{tr('to suppliers', 'डिलरलाई')}</span>
              </div>
            </a>
          {/if}
        {:else if key === 'low'}
          {#if low.error}
            <div class="card"><ErrorCard error={low.error} retry={low.reload} /></div>
          {:else if low.loading && !low.data}
            <div class="card"><Skeleton card /></div>
          {:else}
            <a class="card" href="#/low-stock" onclick={guard}>
              <div class="stat-icon warn"><span class="ms">production_quantity_limits</span></div>
              <div class="stat">
                <span class="stat-label">{tr('Items low on stock', 'कम स्टकका सामान')}</span>
                <span class="stat-value">{num(low.data?.meta.total ?? 0)}</span>
              </div>
            </a>
          {/if}
        {:else if key === 'vat'}
          <a class="card" href="#/vat" onclick={guard}>
            <div class="stat-icon info"><span class="ms">receipt_long</span></div>
            <div class="stat">
              <span class="stat-label">{tr(`${monthTitle(vat.year, vat.month)} VAT to pay`, `${monthTitle(vat.year, vat.month)} भ्याट तिर्नुपर्ने`)}</span>
              <span class="stat-value">{vatPreview.data ? rs(vatPreview.data.payable) : vatPreview.error ? '-' : '…'}</span>
              <span class="stat-sub">{formatDate(vat.due)} · {dueText(vat.daysLeft)}</span>
              {#if vatPreview.error}<span class="tiny bad">{vatPreview.error.message}</span>{/if}
            </div>
          </a>
        {:else if key === 'week'}
          <section class="card">
            <div class="card-head">
              <h3>{tr('Last 7 days', 'पछिल्लो ७ दिन')}</h3>
              <a href="#/reports/sales">{tr('See all', 'सबै हेर्ने')}</a>
            </div>
            {#if week.error}
              <ErrorCard error={week.error} retry={week.reload} />
            {:else if week.loading && !week.data}
              <Skeleton card />
            {:else}
              <div class="hstack between" style="margin-bottom:6px">
                <span class="stat-value">{rs(lastTotal)}</span>
                {#if change !== null}
                  <span class="badge {change >= 0 ? 'good' : 'bad'}"><span class="ms">{change >= 0 ? 'arrow_upward' : 'arrow_downward'}</span>{num(Math.abs(change))}%</span>
                {/if}
              </div>
              <div class="bars">
                {#each last7 as d, n (d.date)}
                  <div class="bar" class:on={n === last7.length - 1} style="--h:{Math.round((d.sales * 100) / peak)}%;--i:{n}">
                    <i></i><span>{n === last7.length - 1 ? tr('Today', 'आज') : shortWeekday(d.date)}</span>
                  </div>
                {/each}
              </div>
            {/if}
          </section>
        {:else if key === 'profit'}
          {#if profit.error}
            <div class="card"><ErrorCard error={profit.error} retry={profit.reload} /></div>
          {:else if profit.loading && !profit.data}
            <div class="card"><Skeleton card /></div>
          {:else}
            <section class="card">
              <div class="card-head">
                <h3>{tr('Profit this month', 'यो महिनाको नाफा')}</h3>
                <a href="#/reports">{tr('Report', 'रिपोर्ट')}</a>
              </div>
              <div class="hstack" style="gap:18px">
                <div class="donut" style="--a:{share}"><span>{num(share)}%</span></div>
                <div class="legend">
                  <div><i></i><span>{tr('Profit', 'नाफा')}</span> · <b>{rs(profit.data?.profit)}</b></div>
                  <div><i style="--c:var(--surface-3)"></i><span>{tr('Cost of goods', 'सामानको लागत')}</span> · {rs(profit.data?.cost_of_goods)}</div>
                  <div><i style="--c:var(--warn)"></i><span>{tr('Expenses', 'खर्च')}</span> · {rs(profit.data?.expenses_total)}</div>
                </div>
              </div>
            </section>
          {/if}
        {/if}
      </div>
    {/each}
  </div>

  <div class="section-title"><h3>{tr('Recent sales', 'भर्खरका बिक्री')}</h3><a href="#/sales">{tr('See all', 'सबै')}</a></div>
  <div class="list">
    {#if recent.error}
      <ErrorCard error={recent.error} retry={recent.reload} />
    {:else if recent.loading && !recent.data}
      <Skeleton rows={3} />
    {:else if (recent.data?.data.length ?? 0) === 0}
      <Empty icon="receipt" title={tr('No sales yet', 'अहिलेसम्म बिक्री छैन')} text={tr('Your first bill will show here.', 'पहिलो बिल यहाँ देखिनेछ।')} />
    {:else}
      {#each recent.data?.data ?? [] as s (s.id)}
        <a class="row" href={`#/sales/${s.id}`}>
          {#if s.customer}
            <span class="avatar">{initials(s.customer.name)}</span>
          {:else}
            <span class="avatar good"><span class="ms">person</span></span>
          {/if}
          <div class="row-main">
            <div class="row-title">{s.customer?.name ?? tr('Walk-in customer', 'पसलमा आएका ग्राहक')}</div>
            <div class="row-sub">{s.bill_no ?? ''} · {formatTime(s.sold_at)}</div>
          </div>
          <div class="row-end">
            <span class="amount">{rs(s.total)}</span>
            {#if s.balance > 0}
              <span class="badge warn">{tr('Credit', 'उधारो')}</span>
            {:else}
              <span class="badge good">{tr('Paid', 'भुक्तानी भयो')}</span>
            {/if}
          </div>
        </a>
      {/each}
    {/if}
  </div>
</div>
