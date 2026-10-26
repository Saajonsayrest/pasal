<script lang="ts">
  import { tr } from '../lib/i18n'
</script>

<div class="page narrow">
  <div class="locked card">
    <span class="ms">lock</span>
    <h2>{tr('Only the owner can see this', 'यो मालिकले मात्र हेर्न सक्नुहुन्छ')}</h2>
    <p class="muted">{tr('Ask the shop owner if you need it.', 'चाहिएमा पसलको मालिकलाई सोध्नुहोस्।')}</p>
    <a class="btn btn-tonal" href="#/">{tr('Go home', 'गृहपृष्ठमा जाने')}</a>
  </div>
</div>
