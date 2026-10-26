<script lang="ts">
  import type { Snippet } from 'svelte'
  import { bottomNav, sideNav, canSee } from '../lib/nav'
  import { session } from '../lib/session.svelte'
  import { tr } from '../lib/i18n'
  import { back } from '../lib/router.svelte'
  import { initials } from '../lib/util'

  let {
    active = '',
    title,
    backTo,
    noNav = false,
    children,
  }: { active?: string; title: string; backTo?: string; noNav?: boolean; children: Snippet } = $props()

  let scrolled = $state(false)
  const role = $derived(session.user?.role)
</script>

<div class="shell">
  <nav class="side-nav">
    <div class="brand">
      <div class="logo">प</div>
      <div>
        <div class="shop">{session.business?.name ?? 'PASAL'}</div>
        <div class="tiny muted">{session.isOwner ? tr('Owner', 'मालिक') : tr('Staff', 'कर्मचारी')}</div>
      </div>
    </div>
    <a class="sell-btn" href="#/sell"><span class="ms">add_shopping_cart</span><span>{tr('New sale', 'नयाँ बिक्री')}</span></a>
    {#each sideNav as group}
      {#if canSee(group, role)}
        {#if group.label}<div class="group-label">{tr(group.label.en, group.label.ne)}</div>{/if}
        {#each group.items as item}
          {#if canSee(item, role)}
            <a href={`#${item.href}`} class:active={item.key === active}>
              <span class="ms">{item.icon}</span><span>{tr(item.en, item.ne)}</span>
            </a>
          {/if}
        {/each}
      {/if}
    {/each}
    <a class="user" href="#/profile">
      <span class="avatar" style="width:32px;height:32px;font-size:13px">{initials(session.user?.name ?? '')}</span>
      <span>{session.user?.name}</span>
    </a>
  </nav>

  <div class="main-col" onscroll={(e) => (scrolled = e.currentTarget.scrollTop > 4)}>
    <header class="topbar" class:scrolled>
      {#if backTo}
        <button class="btn-icon btn back" aria-label={tr('Back', 'पछाडि')} onclick={() => back(backTo)}><span class="ms">arrow_back</span></button>
      {/if}
      <div class="title">{title}</div>
      <div class="topbar-actions" id="topbar-actions"></div>
    </header>
    {@render children()}
  </div>

  {#if !noNav}
    <nav class="bottom-nav">
      {#each bottomNav as item}
        <a href={`#${item.href}`} class:active={item.key === active} class:sell={item.key === 'sell'}>
          <span class="pill"><span class="ms">{item.icon}</span></span>
          <span>{tr(item.en, item.ne)}</span>
        </a>
      {/each}
    </nav>
  {/if}
</div>
