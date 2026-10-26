<script lang="ts">
  import { settings, SEEDS, type Theme } from '../lib/settings.svelte'
  import { tr } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { formatDate, todayAd } from '../lib/bs'

  const COLOURS: [string, string][] = [
    ['Green', 'हरियो'],
    ['Blue', 'नीलो'],
    ['Purple', 'बैजनी'],
    ['Red', 'रातो'],
    ['Orange', 'सुन्तला'],
    ['Teal', 'हरियो-नीलो'],
    ['Grey', 'खरानी'],
  ]
  const THEMES: { key: Theme; en: string; ne: string }[] = [
    { key: 'light', en: 'Light', ne: 'हल्का' },
    { key: 'dark', en: 'Dark', ne: 'गाढा' },
    { key: 'black', en: 'Black', ne: 'कालो' },
  ]
</script>

<div class="page narrow">
  <section class="card stack">
    <div class="stack-sm">
      <h3>{tr('Main colour', 'मुख्य रङ')}</h3>
      <span class="small muted">{tr('Used on buttons and charts', 'बटन र चार्टमा देखिन्छ')}</span>
    </div>
    <div class="hstack wrap" style="gap:12px">
      {#each SEEDS as seed, i (seed)}
        {@const picked = settings.seed === seed}
        <button
          class="btn-icon"
          type="button"
          aria-label={tr(COLOURS[i][0], COLOURS[i][1])}
          aria-pressed={picked}
          style="width:46px;height:46px;min-height:46px;background:{seed};color:#fff;{picked ? 'box-shadow:0 0 0 3px var(--surface),0 0 0 5px var(--text)' : ''}"
          onclick={() => settings.set({ seed })}
        >
          {#if picked}<span class="ms">check</span>{/if}
        </button>
      {/each}
    </div>
  </section>

  <section class="card stack">
    <h3>{tr('Theme', 'थिम')}</h3>
    <div class="seg block">
      {#each THEMES as t (t.key)}
        <button type="button" class:active={settings.theme === t.key} onclick={() => settings.set({ theme: t.key })}>{tr(t.en, t.ne)}</button>
      {/each}
    </div>
  </section>

  <section class="card stack">
    <h3>{tr('Language', 'भाषा')}</h3>
    <div class="seg block">
      <button type="button" class:active={!settings.ne} onclick={() => settings.set({ lang: 'en' })}>English</button>
      <button type="button" class:active={settings.ne} onclick={() => settings.set({ lang: 'ne' })}>नेपाली</button>
    </div>
  </section>

  <section class="card stack">
    <div class="stack-sm">
      <h3>{tr('Date style', 'मितिको ढाँचा')}</h3>
      <span class="small muted">{tr('BS date first, AD small', 'BS मिति पहिले, AD सानो अक्षरमा')}</span>
    </div>
    <div class="seg block">
      <button type="button" class:active={settings.bsDates} onclick={() => settings.set({ bsDates: true })}>BS</button>
      <button type="button" class:active={!settings.bsDates} onclick={() => settings.set({ bsDates: false })}>AD</button>
    </div>
  </section>

  <section class="card tonal stack">
    <span class="stat-label">{tr('Preview', 'नमुना')}</span>
    <div class="hstack between">
      <div class="stat">
        <span class="stat-label">{tr('We owe', 'हामीले तिर्न बाँकी')}</span>
        <span class="stat-value">{rs(12400000)}</span>
      </div>
      <span class="badge primary">{formatDate(todayAd())}</span>
    </div>
  </section>
</div>
