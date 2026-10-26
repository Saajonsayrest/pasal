<script lang="ts">
  import { api } from '../lib/api'
  import { resource } from '../lib/resource.svelte'
  import { tr } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { rangeFor } from '../lib/range'
  import type { Summary } from '../lib/types'
  import RangePicker from '../components/RangePicker.svelte'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'

  const first = rangeFor('month')
  let from = $state(first.from)
  let to = $state(first.to)

  const report = resource(() => api.get<Summary>('/reports/summary', { from, to }))
  const s = $derived(report.data)

  const LINKS: { href: string; icon: string; tone: string; en: string; ne: string; sub: string; sub_ne: string }[] = [
    { href: '#/reports/sales', icon: 'bar_chart', tone: '', en: 'Sales chart', ne: 'बिक्री चार्ट', sub: 'Sales per day', sub_ne: 'दिनअनुसार बिक्री' },
    { href: '#/reports/items', icon: 'trending_up', tone: '', en: 'Top and slow items', ne: 'धेरै र कम बिक्ने सामान', sub: 'Best and slow sellers', sub_ne: 'धेरै बिक्ने र नबिक्ने' },
    { href: '#/reports/credit-age', icon: 'hourglass_bottom', tone: 'warn', en: 'Credit age', ne: 'उधारोको उमेर', sub: 'How old the credit is', sub_ne: 'उधारो कति दिन पुरानो' },
    { href: '#/reports/staff', icon: 'badge', tone: '', en: 'Staff sales', ne: 'कर्मचारीको बिक्री', sub: 'Sales per staff', sub_ne: 'कर्मचारीअनुसार बिक्री' },
    { href: '#/reports/export', icon: 'download', tone: '', en: 'Export', ne: 'निर्यात', sub: 'CSV files for each list', sub_ne: 'हरेक सूचीको CSV फाइल' },
    { href: '#/vat', icon: 'receipt_long', tone: 'info', en: 'VAT this month', ne: 'यो महिनाको भ्याट', sub: 'VAT to pay', sub_ne: 'भ्याट तिर्ने हिसाब' },
  ]
</script>

<div class="page">
  <RangePicker bind:from bind:to />

  {#if report.error}
    <ErrorCard error={report.error} retry={report.reload} />
  {:else if !s}
    <Skeleton card />
    <Skeleton card />
  {:else}
    <section class="hero">
      <div class="stat">
        <span class="stat-label">{tr('Profit', 'नाफा')}</span>
        <span class="stat-value xl">{rs(s.profit)}</span>
        <span class="stat-sub">{tr('Sales minus VAT, goods and expenses', 'बिक्रीबाट भ्याट, सामान र खर्च घटाएपछि')}</span>
      </div>
    </section>

    <section class="card">
      <div class="card-head"><h3>{tr('How the profit is made', 'नाफा कसरी बन्यो')}</h3></div>
      <div class="kv">
        <div><span class="k">{tr('Sales', 'बिक्री')}</span><span class="v">{rs(s.sales_total)}</span></div>
        <div><span class="k">{tr('Minus VAT collected', 'घटाउने: संकलन गरेको भ्याट')}</span><span class="v">{rs(s.vat_collected)}</span></div>
        <div><span class="k">{tr('Minus cost of goods', 'घटाउने: सामानको लागत')}</span><span class="v">{rs(s.cost_of_goods)}</span></div>
        <div><span class="k">{tr('Minus expenses', 'घटाउने: खर्च')}</span><span class="v">{rs(s.expenses_total)}</span></div>
        <div class="total"><span class="k">{tr('Profit', 'नाफा')}</span><span class="v">{rs(s.profit)}</span></div>
      </div>
    </section>

    <a class="card" href="#/items">
      <div class="hstack">
        <span class="icon-tile good"><span class="ms">inventory_2</span></span>
        <div class="stat">
          <span class="stat-label">{tr('Stock value today', 'आजको स्टकको मूल्य')}</span>
          <span class="stat-value">{rs(s.stock_value)}</span>
          <span class="stat-sub">{tr('At buying price', 'खरिद मूल्यमा')}</span>
        </div>
      </div>
    </a>

    <div class="grid-2">
      <a class="card" href="#/customers">
        <div class="stat-icon warn"><span class="ms">call_received</span></div>
        <div class="stat">
          <span class="stat-label">{tr('To collect', 'उठाउन बाँकी')}</span>
          <span class="stat-value">{rs(s.owed_to_us)}</span>
          <span class="stat-sub">{tr('From customers', 'ग्राहकबाट')}</span>
        </div>
      </a>
      <a class="card" href="#/suppliers">
        <div class="stat-icon info"><span class="ms">call_made</span></div>
        <div class="stat">
          <span class="stat-label">{tr('We owe', 'हामीले तिर्न बाँकी')}</span>
          <span class="stat-value">{rs(s.we_owe)}</span>
          <span class="stat-sub">{tr('To suppliers', 'डिलरलाई')}</span>
        </div>
      </a>
    </div>

    <p class="small muted">{tr('Stock value, to collect and we owe are as of today, not only for the dates you picked.', 'स्टकको मूल्य, उठाउन बाँकी र हामीले तिर्न बाँकी आजको हिसाबमा हो, छानेका मितिमा मात्र होइन।')}</p>
  {/if}

  <div class="section-title"><h3>{tr('All reports', 'सबै रिपोर्ट')}</h3></div>
  <div class="grid-auto">
    {#each LINKS as l (l.href)}
      <a class="card" href={l.href}>
        <div class="hstack">
          <span class="icon-tile {l.tone}"><span class="ms">{l.icon}</span></span>
          <div class="row-main">
            <div class="row-title">{tr(l.en, l.ne)}</div>
            <div class="row-sub">{tr(l.sub, l.sub_ne)}</div>
          </div>
        </div>
      </a>
    {/each}
  </div>
</div>
