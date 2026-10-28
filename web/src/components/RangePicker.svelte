<script lang="ts">
  import BsDatePicker from './BsDatePicker.svelte'
  import { formatDate } from '../lib/bs'
  import { tr } from '../lib/i18n'
  import { rangeFor, type RangePreset } from '../lib/range'

  // Preset chips and two date boxes for a custom range. Starts on this Nepali month.
  //   <RangePicker bind:from bind:to />
  let { from = $bindable(''), to = $bindable('') }: { from?: string; to?: string } = $props()

  let preset = $state<RangePreset>('month')

  const CHIPS: { key: RangePreset; en: string; ne: string }[] = [
    { key: 'today', en: 'Today', ne: 'आज' },
    { key: 'week', en: 'Last 7 days', ne: 'पछिल्ला ७ दिन' },
    { key: 'month', en: 'This month', ne: 'यो महिना' },
    { key: 'last_month', en: 'Last month', ne: 'गत महिना' },
    { key: 'quarter', en: 'Last 3 months', ne: 'पछिल्ला ३ महिना' },
    { key: 'custom', en: 'Custom', ne: 'आफैँ छान्ने' },
  ]

  function choose(key: RangePreset): void {
    preset = key
    if (key === 'custom') return
    const r = rangeFor(key)
    from = r.from
    to = r.to
  }
</script>

<div class="stack-sm">
  <div class="chips">
    {#each CHIPS as c (c.key)}
      <button type="button" class="chip" class:active={preset === c.key} onclick={() => choose(c.key)}>{tr(c.en, c.ne)}</button>
    {/each}
  </div>

  {#if preset === 'custom'}
    <div class="grid-2">
      <BsDatePicker bind:value={from} label={tr('From', 'देखि')} max={to} />
      <BsDatePicker bind:value={to} label={tr('To', 'सम्म')} min={from} />
    </div>
  {/if}

  {#if from && to}
    <p class="small muted" style="margin:-4px 0 0">{tr(`${formatDate(from)} to ${formatDate(to)}`, `${formatDate(from)} देखि ${formatDate(to)} सम्म`)}</p>
  {/if}
</div>
