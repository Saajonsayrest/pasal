<script lang="ts">
  import { digits, num } from '../lib/i18n'

  // Big amount display with a number keypad (Cashew style). `value` is the typed text in rupees,
  // for example "1250.5". Turn it into paisa with toPaisa(value).
  //   <AmountPad bind:value={raw} />
  let { value = $bindable('0') }: { value?: string } = $props()

  function press(key: string): void {
    let raw = value || '0'
    if (key === 'del') raw = raw.length > 1 ? raw.slice(0, -1) : '0'
    else if (key === '.') {
      if (raw.includes('.')) return
      raw += '.'
    } else {
      const [, frac] = raw.split('.')
      if (frac !== undefined && frac.length >= 2) return // paisa has two digits
      if (raw.replace('.', '').length >= 12) return
      raw = raw === '0' ? key : raw + key
    }
    value = raw
  }

  const shown = $derived.by(() => {
    const [i, d] = (value || '0').split('.')
    return digits(num(Number(i)) + (d !== undefined ? `.${d}` : ''))
  })
  const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9']
</script>

<div class="amount-display"><span class="cur">Rs</span><span class="val">{shown}</span></div>
<div class="keypad">
  {#each keys as k}
    <button type="button" onclick={() => press(k)}>{digits(k)}</button>
  {/each}
  <button type="button" class="fn" onclick={() => press('.')}>.</button>
  <button type="button" onclick={() => press('0')}>{digits('0')}</button>
  <button type="button" class="fn" aria-label="Delete" onclick={() => press('del')}><span class="ms">backspace</span></button>
</div>
