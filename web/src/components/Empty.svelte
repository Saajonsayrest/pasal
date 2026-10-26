<script lang="ts">
  import type { Snippet } from 'svelte'

  // A friendly empty screen with one clear button.
  //   <Empty icon="group" title="No customers yet" text="Add your first customer."> <a class="btn btn-primary" ...>Add</a> </Empty>
  let { icon = 'inbox', title, text = '', children }: { icon?: string; title: string; text?: string; children?: Snippet } = $props()
</script>

<div class="empty">
  <div class="empty-art"><span class="ms">{icon}</span></div>
  <h2>{title}</h2>
  {#if text}<p class="muted">{text}</p>{/if}
  {#if children}{@render children()}{/if}
</div>
