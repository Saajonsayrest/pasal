<script lang="ts">
  import type { Snippet } from 'svelte'
  import { portal } from '../lib/portal'
  import { tr } from '../lib/i18n'

  // A bottom sheet on a phone, a dialog on a wide screen. It moves itself to the app frame.
  //   <Sheet bind:open title="Take payment"> ... </Sheet>
  let { open = $bindable(false), title = '', children }: { open?: boolean; title?: string; children: Snippet } = $props()
</script>

<svelte:window onkeydown={(e) => e.key === 'Escape' && (open = false)} />

<div class="sheet-layer" class:open use:portal={'.app'}>
  <div class="backdrop" role="presentation" onclick={() => (open = false)}></div>
  <div class="sheet" role="dialog" aria-modal="true" aria-label={title} aria-hidden={!open}>
    <div class="sheet-head">
      <h2>{title}</h2>
      <button class="btn btn-icon" aria-label={tr('Close', 'बन्द')} onclick={() => (open = false)}><span class="ms">close</span></button>
    </div>
    {#if open}{@render children()}{/if}
  </div>
</div>
