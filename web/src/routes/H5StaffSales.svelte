<script lang="ts">
  import { api } from '../lib/api'
  import { resource } from '../lib/resource.svelte'
  import { tr, num } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { rangeFor } from '../lib/range'
  import { initials } from '../lib/util'
  import type { StaffReport } from '../lib/types'
  import RangePicker from '../components/RangePicker.svelte'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Empty from '../components/Empty.svelte'

  const first = rangeFor('month')
  let from = $state(first.from)
  let to = $state(first.to)

  const report = resource(() => api.get<StaffReport>('/reports/staff', { from, to }))
  const rows = $derived(report.data?.data ?? [])
  const totalSales = $derived(rows.reduce((n, r) => n + r.sales, 0))
  const totalBills = $derived(rows.reduce((n, r) => n + r.bills, 0))
  const totalDiscount = $derived(rows.reduce((n, r) => n + r.discount, 0))
  const peak = $derived(Math.max(1, ...rows.map((r) => r.sales)))

  const avg = (sales: number, bills: number) => (bills > 0 ? Math.round(sales / bills) : 0)
  const share = (sales: number) => (totalSales > 0 ? Math.round((sales / totalSales) * 100) : 0)
  const barWidth = (sales: number) => Math.max(0, (sales / peak) * 100)
</script>

<div class="page">
  <RangePicker bind:from bind:to />

  {#if report.error}
    <ErrorCard error={report.error} retry={report.reload} />
  {:else if !report.data}
    <Skeleton card />
    <Skeleton rows={3} />
  {:else if rows.length === 0}
    <Empty icon="badge" title={tr('No sales in these dates', 'यो मितिमा बिक्री छैन')} text={tr('Pick other dates above.', 'माथि अर्को मिति छान्नुहोस्।')} />
  {:else}
    <section class="hero soft">
      <div class="stat">
        <span class="stat-label">{tr('Total sales', 'जम्मा बिक्री')}</span>
        <span class="stat-value xl">{rs(totalSales)}</span>
        <span class="stat-sub">{tr(`${num(totalBills)} bills`, `${num(totalBills)} बिल`)}</span>
      </div>
    </section>

    <div class="stack phone-only">
      {#each rows as r (r.user_id ?? r.name)}
        <section class="card">
          <div class="hstack between">
            <div class="hstack">
              <span class="avatar">{initials(r.name)}</span>
              <div><div class="bold">{r.name}</div></div>
            </div>
            <span class="stat-value" style="font-size:20px">{rs(r.sales)}</span>
          </div>
          <div class="progress" style="--w:{barWidth(r.sales)}%;margin:14px 0 6px"><span></span></div>
          <div class="tiny muted">{tr(`${share(r.sales)}% of total sales`, `कुल बिक्रीको ${num(share(r.sales))}%`)}</div>
          <div class="kv" style="margin-top:8px">
            <div><span class="k">{tr('Bills', 'बिल')}</span><span class="v">{num(r.bills)}</span></div>
            <div><span class="k">{tr('Average bill', 'औसत बिल')}</span><span class="v">{rs(avg(r.sales, r.bills))}</span></div>
            <div><span class="k">{tr('Discount given', 'दिएको छुट')}</span><span class="v">{rs(r.discount)}</span></div>
          </div>
        </section>
      {/each}
    </div>

    <div class="table-wrap wide-only">
      <table class="table">
        <thead>
          <tr>
            <th>{tr('Staff', 'कर्मचारी')}</th>
            <th class="r">{tr('Bills', 'बिल')}</th>
            <th class="r">{tr('Sales', 'बिक्री')}</th>
            <th class="r">{tr('Average bill', 'औसत बिल')}</th>
            <th class="r">{tr('Discount given', 'दिएको छुट')}</th>
            <th class="r">{tr('Share', 'हिस्सा')}</th>
          </tr>
        </thead>
        <tbody>
          {#each rows as r (r.user_id ?? r.name)}
            <tr>
              <td>
                <div class="progress" style="--w:{barWidth(r.sales)}%;margin-bottom:6px"><span></span></div>
                <span class="bold">{r.name}</span>
              </td>
              <td class="r">{num(r.bills)}</td>
              <td class="r">{rs(r.sales)}</td>
              <td class="r">{rs(avg(r.sales, r.bills))}</td>
              <td class="r">{rs(r.discount)}</td>
              <td class="r">{num(share(r.sales))}%</td>
            </tr>
          {/each}
          <tr>
            <td class="bold">{tr('Total', 'जम्मा')}</td>
            <td class="r bold">{num(totalBills)}</td>
            <td class="r bold">{rs(totalSales)}</td>
            <td class="r">{rs(avg(totalSales, totalBills))}</td>
            <td class="r bold">{rs(totalDiscount)}</td>
            <td class="r bold">100%</td>
          </tr>
        </tbody>
      </table>
    </div>
  {/if}
</div>
