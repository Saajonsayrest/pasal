<script lang="ts">
  import type { Snippet } from 'svelte'

  // One labelled form field with the error under it.
  //   <Field label="Name" error={save.field('name')}><input bind:value={name} /></Field>
  let { label, error = null, hint = '', full = false, children }: { label: string; error?: string | null; hint?: string; full?: boolean; children: Snippet } = $props()
</script>

<label class="field" class:has-error={!!error} class:full>
  <span class="label">{label}</span>
  {@render children()}
  {#if error}
    <span class="field-error"><span class="ms" style="font-size:16px">error</span><span>{error}</span></span>
  {:else if hint}
    <span class="field-hint">{hint}</span>
  {/if}
</label>
