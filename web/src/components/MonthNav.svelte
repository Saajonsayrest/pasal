<script lang="ts">
  import { monthTitle, shiftMonth, todayBs } from '../lib/bs'
  import { tr } from '../lib/i18n'

  // Previous and next Nepali (BS) month. Bind year and month:  <MonthNav bind:year bind:month />
  let { year = $bindable(todayBs().year), month = $bindable(todayBs().month) }: { year?: number; month?: number } = $props()

  function go(by: number): void {
    const next = shiftMonth(year, month, by)
    year = next.year
    month = next.month
  }
</script>

<div class="hstack between">
  <button class="btn btn-icon" aria-label={tr('Previous month', 'अघिल्लो महिना')} onclick={() => go(-1)}><span class="ms">chevron_left</span></button>
  <h3>{monthTitle(year, month)}</h3>
  <button class="btn btn-icon" aria-label={tr('Next month', 'अर्को महिना')} onclick={() => go(1)}><span class="ms">chevron_right</span></button>
</div>
