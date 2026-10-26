<script lang="ts">
  import { session } from '../lib/session.svelte'
  import { navigate } from '../lib/router.svelte'
  import { tr } from '../lib/i18n'
  import { initials } from '../lib/util'

  interface Link {
    path: string
    icon: string
    en: string
    ne: string
    owner?: boolean
    later?: boolean
  }
  interface Group {
    en: string
    ne: string
    links: Link[]
  }

  const GROUPS: Group[] = [
    {
      en: 'Selling',
      ne: 'बिक्री',
      links: [
        { path: '/sales', icon: 'receipt', en: 'Sales list', ne: 'बिक्री सूची' },
        { path: '/notifications', icon: 'notifications', en: 'Notifications', ne: 'सूचनाहरू' },
      ],
    },
    {
      en: 'Stock',
      ne: 'स्टक',
      links: [
        { path: '/stock-count', icon: 'fact_check', en: 'Stock count', ne: 'स्टक गणना', owner: true },
        { path: '/low-stock', icon: 'production_quantity_limits', en: 'Low stock and reorder', ne: 'कम स्टक र पुनः अर्डर', owner: true },
        { path: '/categories', icon: 'category', en: 'Categories', ne: 'वर्गहरू', owner: true },
      ],
    },
    {
      en: 'Buying',
      ne: 'खरिद',
      links: [
        { path: '/purchases', icon: 'shopping_bag', en: 'Purchases', ne: 'खरिदहरू', owner: true },
        { path: '/suppliers', icon: 'local_shipping', en: 'Suppliers', ne: 'डिलरहरू', owner: true },
      ],
    },
    {
      en: 'Money',
      ne: 'पैसा',
      links: [
        { path: '/expenses', icon: 'payments', en: 'Expenses', ne: 'खर्चहरू', owner: true },
        { path: '/cash-book', icon: 'account_balance_wallet', en: 'Cash book', ne: 'नगद किताब', owner: true },
        { path: '/payments', icon: 'swap_vert', en: 'All payments', ne: 'सबै भुक्तानी', owner: true },
      ],
    },
    {
      en: 'Reports and VAT',
      ne: 'रिपोर्ट र भ्याट',
      links: [
        { path: '/reports', icon: 'insights', en: 'Reports', ne: 'रिपोर्टहरू', owner: true },
        { path: '/vat', icon: 'receipt_long', en: 'VAT', ne: 'भ्याट', owner: true },
      ],
    },
    {
      en: 'Settings',
      ne: 'सेटिङ',
      links: [
        { path: '/settings/shop', icon: 'storefront', en: 'Shop details', ne: 'पसलको विवरण', owner: true },
        { path: '/settings/staff', icon: 'badge', en: 'Staff', ne: 'कर्मचारी', owner: true },
        { path: '/settings/look', icon: 'palette', en: 'App look and language', ne: 'एपको रूप र भाषा' },
        { path: '/settings/printer', icon: 'print', en: 'Printer', ne: 'प्रिन्टर', later: true },
        { path: '/settings/activity', icon: 'history', en: 'Activity log', ne: 'गतिविधि लग', owner: true },
      ],
    },
  ]

  const groups = $derived(
    GROUPS.map((g) => ({ ...g, links: g.links.filter((l) => !l.owner || session.isOwner) })).filter((g) => g.links.length > 0),
  )

  async function signOut() {
    await session.logout()
    navigate('/login')
  }
</script>

<div class="page narrow">
  <a class="card hstack" href="#/profile">
    <span class="avatar" style="width:52px;height:52px;font-size:18px">{initials(session.user?.name ?? '')}</span>
    <div class="row-main">
      <div class="row-title">{session.user?.name}</div>
      <div class="row-sub">{session.business?.name ?? 'PASAL'} · {session.isOwner ? tr('Owner', 'मालिक') : tr('Staff', 'कर्मचारी')}</div>
    </div>
    <span class="ms chev">chevron_right</span>
  </a>

  {#each groups as group (group.en)}
    <div class="section-title"><h3>{tr(group.en, group.ne)}</h3></div>
    <div class="list">
      {#each group.links as link (link.path)}
        <a class="row" href={`#${link.path}`}>
          <span class="icon-tile"><span class="ms">{link.icon}</span></span>
          <div class="row-main"><div class="row-title">{tr(link.en, link.ne)}</div></div>
          {#if link.later}<span class="badge later">{tr('Later', 'पछि')}</span>{/if}
          <span class="ms chev">chevron_right</span>
        </a>
      {/each}
    </div>
  {/each}

  <button class="btn btn-danger btn-block btn-lg" type="button" onclick={signOut}><span class="ms">logout</span><span>{tr('Sign out', 'साइन आउट')}</span></button>
</div>
