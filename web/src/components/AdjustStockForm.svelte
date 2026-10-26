<script lang="ts">
  import { api, newKey } from '../lib/api'
  import { action } from '../lib/resource.svelte'
  import { tr, num } from '../lib/i18n'
  import { toast } from '../lib/toast.svelte'
  import type { Item } from '../lib/types'
  import Field from './Field.svelte'

  // The stock change form. Used on the Adjust stock page and inside the item's Sheet.
  //   <AdjustStockForm item={item} onsaved={(updated) => ...} />
  let { item, onsaved }: { item: Item; onsaved: (updated: Item) => void } = $props()

  const REASONS: [string, string][] = [
    ['Damaged', 'बिग्रिएको'],
    ['Expired', 'म्याद सकिएको'],
    ['Counted again', 'फेरि गनेको'],
    ['Gift', 'उपहार'],
    ['Other', 'अन्य'],
  ]
  const MAX_QTY = 1000000

  let dir = $state<'add' | 'remove'>('remove')
  let qty = $state<number | null>(1)
  let note = $state('')
  let key = $state(newKey())
  const save = action()

  const amount = $derived(qty !== null && Number.isInteger(qty) && qty >= 1 ? qty : 0)
  const change = $derived(dir === 'add' ? amount : -amount)
  const next = $derived(item.quantity + change)
  const tooLow = $derived(next < 0)
  const canSave = $derived(amount > 0 && note.trim().length > 0 && !tooLow)

  const serverError = $derived.by(() => {
    const e = save.error
    if (!e) return null
    return e.field('quantity') ?? e.field('change') ?? (Object.keys(e.errors).length ? null : e.message)
  })

  function step(by: number): void {
    qty = Math.min(MAX_QTY, Math.max(1, amount + by))
  }

  async function submit(e: SubmitEvent): Promise<void> {
    e.preventDefault()
    if (!canSave) return
    const res = await save.run(() =>
      api.post<{ data: Item }>('/stock-adjustments', { item_id: item.id, change, note: note.trim() }, key),
    )
    if (!res) return
    key = newKey()
    toast(
      `Stock updated: ${item.name} now ${num(res.data.quantity)} ${item.unit}`,
      `स्टक मिलाइयो: ${item.name} अब ${num(res.data.quantity)} ${item.unit}`,
    )
    onsaved(res.data)
  }
</script>

<form class="stack" onsubmit={submit}>
  <div class="seg block">
    <button type="button" class:active={dir === 'add'} onclick={() => (dir = 'add')}>
      <span class="ms">add</span><span>{tr('Add', 'थप्ने')}</span>
    </button>
    <button type="button" class:active={dir === 'remove'} onclick={() => (dir = 'remove')}>
      <span class="ms">remove</span><span>{tr('Remove', 'घटाउने')}</span>
    </button>
  </div>

  <div class="hstack between">
    <span class="bold">{tr('How many', 'कति')} ({item.unit})</span>
    <div class="stepper">
      <button type="button" aria-label={tr('Less', 'कम')} onclick={() => step(-1)}><span class="ms">remove</span></button>
      <input class="qty" type="number" min="1" max={MAX_QTY} inputmode="numeric" bind:value={qty} aria-label={tr('How many', 'कति')} />
      <button type="button" aria-label={tr('More', 'थप')} onclick={() => step(1)}><span class="ms">add</span></button>
    </div>
  </div>
  {#if serverError}
    <div class="alert bad"><span class="ms">error</span><div>{serverError}</div></div>
  {/if}

  <div class="stack-sm">
    <span class="small muted">{tr('Reason', 'कारण')}</span>
    <div class="chips wrap">
      {#each REASONS as [en, ne]}
        <button type="button" class="chip" class:active={note.trim() === en} onclick={() => (note = en)}>{tr(en, ne)}</button>
      {/each}
    </div>
  </div>

  <Field label={tr('Note (required)', 'नोट (अनिवार्य)')} error={save.field('note')}>
    <textarea bind:value={note} placeholder={tr('Example: 2 trays broke on the way', 'उदाहरण: बाटोमा २ ट्रे फुट्यो')}></textarea>
  </Field>

  {#if tooLow}
    <div class="alert warn"><span class="ms">warning</span><div>{tr('Stock cannot go below 0.', 'स्टक ० भन्दा कम हुन सक्दैन।')}</div></div>
  {/if}

  <div class="card tonal hstack between">
    <span>{tr('New stock', 'नयाँ स्टक')}</span>
    <span class="stat-value" class:bad={tooLow}>{num(next)} <span class="small">{item.unit}</span></span>
  </div>

  <button class="btn btn-primary btn-lg btn-block" type="submit" disabled={save.busy || !canSave}>
    <span class="ms">check</span><span>{save.busy ? tr('Saving…', 'सेभ हुँदैछ…') : tr('Save', 'सेभ गर्ने')}</span>
  </button>
</form>

<style>
  .qty {
    width: 64px;
    border: 0;
    background: transparent;
    text-align: center;
    font-weight: 700;
    font-size: 16px;
    font-variant-numeric: tabular-nums;
    -moz-appearance: textfield;
    appearance: textfield;
  }
  .qty::-webkit-outer-spin-button,
  .qty::-webkit-inner-spin-button {
    -webkit-appearance: none;
    margin: 0;
  }
</style>
