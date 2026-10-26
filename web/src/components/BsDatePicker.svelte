<script lang="ts">
  import { adToBs, bsToAd, daysInBsMonth, formatBs, formatAd, monthTitle, shiftMonth, todayAd, weekday, MIN_YEAR, MAX_YEAR } from '../lib/bs'
  import { digits, tr } from '../lib/i18n'
  import { settings } from '../lib/settings.svelte'
  import Sheet from './Sheet.svelte'

  // A date box that shows the Nepali (BS) date and lets the person pick a day from a BS calendar.
  // `value` is the AD date "YYYY-MM-DD" (what the API wants). Leave `min` or `max` out for no limit.
  //   <BsDatePicker bind:value={billDate} label="Bill date" />
  let { value = $bindable(todayAd()), label = '', min = '', max = '' }: { value?: string; label?: string; min?: string; max?: string } = $props()

  let open = $state(false)
  let view = $state(adToBs(value || todayAd()))

  $effect(() => {
    if (open) view = adToBs(value || todayAd())
  })

  const days = $derived(daysInBsMonth(view.year, view.month))
  const lead = $derived(new Date(bsToAd(view.year, view.month, 1) + 'T00:00:00Z').getUTCDay())
  const today = todayAd()
  const weekdays = $derived([0, 1, 2, 3, 4, 5, 6].map((i) => weekday(new Date(Date.UTC(2026, 9, 25 + i)).toISOString().slice(0, 10)).slice(0, settings.ne ? 3 : 2)))

  function go(by: number): void {
    const next = shiftMonth(view.year, view.month, by)
    if (next.year < MIN_YEAR || next.year > MAX_YEAR) return
    view = { year: next.year, month: next.month, day: 1 }
  }

  function disabled(d: number): boolean {
    const ad = bsToAd(view.year, view.month, d)
    return (!!min && ad < min) || (!!max && ad > max)
  }

  function pick(d: number): void {
    if (disabled(d)) return
    value = bsToAd(view.year, view.month, d)
    open = false
  }
</script>

<div class="field">
  {#if label}<span class="label">{label}</span>{/if}
  <button type="button" class="date-box" onclick={() => (open = true)}>
    <span class="ms">event</span>
    <span class="stack-sm" style="text-align:left;gap:0">
      <span class="bold">{value ? (settings.bsDates ? formatBs(value) : formatAd(value)) : tr('Pick a date', 'मिति छान्नुहोस्')}</span>
      {#if value}<span class="tiny muted">{settings.bsDates ? formatAd(value) : formatBs(value)}</span>{/if}
    </span>
  </button>
</div>

<Sheet bind:open title={label || tr('Pick a date', 'मिति छान्नुहोस्')}>
  <div class="hstack between">
    <button type="button" class="btn btn-icon" aria-label={tr('Previous month', 'अघिल्लो महिना')} onclick={() => go(-1)}><span class="ms">chevron_left</span></button>
    <h3>{monthTitle(view.year, view.month)}</h3>
    <button type="button" class="btn btn-icon" aria-label={tr('Next month', 'अर्को महिना')} onclick={() => go(1)}><span class="ms">chevron_right</span></button>
  </div>
  <div class="cal">
    {#each weekdays as w}<span class="cal-head">{w}</span>{/each}
    {#each Array(lead) as _}<span></span>{/each}
    {#each Array(days) as _, i}
      {@const d = i + 1}
      {@const ad = bsToAd(view.year, view.month, d)}
      <button type="button" class="cal-day" class:on={ad === value} class:today={ad === today} disabled={disabled(d)} onclick={() => pick(d)}>
        {digits(d)}
        <span class="cal-ad">{digits(Number(ad.slice(8)))}</span>
      </button>
    {/each}
  </div>
  <button type="button" class="btn btn-tonal" onclick={() => { value = today; open = false }}>{tr('Today', 'आज')}</button>
</Sheet>

<style>
  .date-box {
    display: flex;
    align-items: center;
    gap: 10px;
    width: 100%;
    padding: 10px 14px;
    border-radius: var(--r-md);
    border: 1.5px solid var(--line);
    background: var(--surface);
    cursor: pointer;
  }
  .cal {
    display: grid;
    grid-template-columns: repeat(7, 1fr);
    gap: 4px;
    text-align: center;
  }
  .cal-head {
    font-size: 12px;
    font-weight: 700;
    color: var(--muted);
    padding: 4px 0;
  }
  .cal-day {
    position: relative;
    border: 0;
    border-radius: 12px;
    padding: 9px 0 13px;
    background: transparent;
    font-weight: 600;
  }
  .cal-day:hover:not(:disabled) {
    background: var(--surface-2);
  }
  .cal-day.today {
    outline: 1.5px solid var(--primary);
  }
  .cal-day.on {
    background: var(--primary);
    color: var(--on-seed);
  }
  .cal-day:disabled {
    opacity: 0.3;
    cursor: default;
  }
  .cal-ad {
    position: absolute;
    right: 5px;
    bottom: 2px;
    font-size: 9px;
    font-weight: 500;
    opacity: 0.6;
  }
</style>
