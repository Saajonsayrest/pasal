<script lang="ts">
  import { ROUTES, loaderFor } from './routes'
  import type { RouteDef } from './routes'
  import { route, match, navigate } from './lib/router.svelte'
  import { session } from './lib/session.svelte'
  import { shell } from './lib/shell.svelte'
  import { toasts } from './lib/toast.svelte'
  import { settings } from './lib/settings.svelte'
  import { tr } from './lib/i18n'
  import Shell from './components/Shell.svelte'
  import Locked from './components/Locked.svelte'
  import NotFound from './components/NotFound.svelte'
  import Skeleton from './components/Skeleton.svelte'
  import Empty from './components/Empty.svelte'

  const found = $derived.by<{ def: RouteDef; params: Record<string, string> } | null>(() => {
    for (const def of ROUTES) {
      const params = match(def.path, route.path)
      if (params) return { def, params }
    }
    return null
  })

  // Send people to the login screen when they are not signed in, and away from it when they are.
  $effect(() => {
    if (session.checking) return
    if (!session.loggedIn && !found?.def.public) navigate('/login', true)
    else if (session.loggedIn && found?.def.id === 'A1') navigate('/', true)
  })

  const title = $derived(shell.current ?? tr(found?.def.title[0] ?? 'PASAL', found?.def.title[1]))
  $effect(() => {
    document.title = `${title} · PASAL`
  })

  const loader = $derived(found ? loaderFor(found.def, session.isOwner) : null)
  const blocked = $derived(!!found && !found.def.public && !session.loggedIn)
</script>

<div class="stage">
  <div class="app" data-lang={settings.lang}>
    {#if session.checking || blocked}
      <div class="main-col no-shell"><div class="page narrow"><Skeleton card /></div></div>
    {:else if !found}
      <div class="main-col no-shell"><NotFound /></div>
    {:else if found.def.ownerOnly && !session.isOwner && session.loggedIn}
      <Shell active={found.def.nav} {title} backTo="/">
        <Locked />
      </Shell>
    {:else}
      {#snippet body()}
        {#key route.path}
          {#if loader}
            {#await loader()}
              <div class="page"><Skeleton card /><Skeleton rows={4} /></div>
            {:then mod}
              {@const Page = mod.default}
              <Page params={found.params} query={route.query} />
            {:catch}
              <div class="page narrow">
                <Empty icon="error" title={tr('This page could not open', 'यो पेज खुल्न सकेन')} text={tr('Reload the website and try again.', 'वेबसाइट रिलोड गरेर फेरि प्रयास गर्नुहोस्।')} />
              </div>
            {/await}
          {:else}
            <div class="page narrow">
              <Empty icon="construction" title={tr('Not built yet', 'अझै बनेको छैन')} text={found.def.id + ' · ' + found.def.title[0]} />
            </div>
          {/if}
        {/key}
      {/snippet}

      {#if found.def.noShell}
        <div class="main-col no-shell">{@render body()}</div>
      {:else}
        <Shell active={found.def.nav} {title} backTo={found.def.back} noNav={found.def.noNav}>
          {@render body()}
        </Shell>
      {/if}
    {/if}

    <div class="toast" class:show={toasts.visible}><span class="ms">check_circle</span><span>{toasts.message}</span></div>
  </div>
</div>
