<script lang="ts">
  // Grey boxes while data loads. `rows` list rows, or `card` for one tall block.
  let { rows = 5, card = false }: { rows?: number; card?: boolean } = $props()
</script>

{#if card}
  <div class="skeleton" style="height:120px;border-radius:var(--r-lg)"></div>
{:else}
  <div class="list">
    {#each Array(rows) as _}
      <div class="row">
        <div class="skeleton" style="width:44px;height:44px;border-radius:50%"></div>
        <div class="row-main stack-sm">
          <div class="skeleton" style="height:14px;width:55%"></div>
          <div class="skeleton" style="height:12px;width:35%"></div>
        </div>
      </div>
    {/each}
  </div>
{/if}
