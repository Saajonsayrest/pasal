<script lang="ts">
  import { tr } from '../lib/i18n'
  import Empty from './Empty.svelte'

  let { text = '' }: { text?: string } = $props()
</script>

<div class="page narrow">
  <Empty icon="search_off" title={tr('Page not found', 'पेज भेटिएन')} {text}>
    <a class="btn btn-primary" href="#/">{tr('Go home', 'गृहपृष्ठमा जाने')}</a>
  </Empty>
</div>
