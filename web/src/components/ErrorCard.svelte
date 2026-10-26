<script lang="ts">
  import type { ApiError } from '../lib/api'
  import { tr } from '../lib/i18n'

  // Shown when a screen could not load. Offers a retry.
  let { error, retry }: { error: ApiError; retry?: () => void } = $props()
</script>

<div class="alert bad">
  <span class="ms">error</span>
  <div class="stack-sm">
    <div>{error.message}</div>
    {#if retry}<button class="btn btn-sm btn-tonal" onclick={retry}>{tr('Try again', 'फेरि प्रयास गर्नुहोस्')}</button>{/if}
  </div>
</div>
