<script lang="ts">
  import { api } from '../lib/api'
  import { resource } from '../lib/resource.svelte'
  import { session } from '../lib/session.svelte'
  import { navigate } from '../lib/router.svelte'
  import { tr, num } from '../lib/i18n'
  import type { Business, Customer, Item, User } from '../lib/types'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'

  const shop = resource(() => api.get<{ data: Business }>('/business'))
  const items = resource(() => api.page<Item>('/items', { per_page: 1 }))
  const customers = resource(() => api.page<Customer>('/customers', { per_page: 1 }))
  const users = resource(() => api.page<User>('/users', { per_page: 1 }))

  const failed = $derived(shop.error ?? items.error ?? customers.error ?? users.error)
  const loading = $derived(!shop.data || !items.data || !customers.data || !users.data)

  const shopDone = $derived(
    !!shop.data && [shop.data.data.phone, shop.data.data.address, shop.data.data.pan].every((v) => !!v?.trim()),
  )
  const itemDone = $derived((items.data?.meta.total ?? 0) > 0)
  const customerDone = $derived((customers.data?.meta.total ?? 0) > 0)
  const staffDone = $derived((users.data?.meta.total ?? 0) > 1)
  const done = $derived([shopDone, itemDone, customerDone, staffDone].filter(Boolean).length)
  const percent = $derived(Math.round((done * 100) / 4))
  const first = session.user?.name.split(' ')[0] ?? ''

  function retry(): void {
    shop.reload()
    items.reload()
    customers.reload()
    users.reload()
  }

  function skip(): void {
    try {
      localStorage.setItem('pasal-welcome-done', '1')
    } catch {
      // Storage can be blocked. The guide will show again next time.
    }
    navigate('/')
  }
</script>

<div class="page narrow">
  <section class="hero">
    <div class="stat">
      <span class="stat-label">{tr(`Welcome, ${first}`, `स्वागत छ, ${first}`)}</span>
      <span class="stat-value lg">{tr("Let's set up your shop", 'पसल सेटअप गरौँ')}</span>
      <span class="stat-sub">{tr('Four quick steps. You can do them later too.', 'चार सजिला काम। पछि पनि गर्न सकिन्छ।')}</span>
    </div>
    <div style="margin-top:18px">
      <div class="hstack between small" style="margin-bottom:8px">
        <span class="bold">{tr(`${num(done)} of ${num(4)} steps done`, `${num(4)} मध्ये ${num(done)} काम पूरा भयो`)}</span>
        <span class="bold">{num(percent)}%</span>
      </div>
      <div class="progress" style="--w:{percent}%;background:rgb(255 255 255 / .25)"><span style="background:#fff"></span></div>
    </div>
  </section>

  <div class="section-title"><h3>{tr('Setup steps', 'सेटअपका काम')}</h3></div>

  {#if failed}
    <ErrorCard error={failed} retry={retry} />
  {:else if loading}
    <div class="list"><div class="row"><Skeleton card /></div><div class="row"><Skeleton card /></div></div>
  {:else}
    <div class="list">
      <a class="row" href="#/settings/shop">
        <span class="icon-tile {shopDone ? 'good' : 'primary'}"><span class="ms">{shopDone ? 'check' : 'storefront'}</span></span>
        <div class="row-main">
          <div class="row-title">{tr('Shop details', 'पसलको विवरण')}</div>
          <div class="row-sub">{tr('Phone, address and PAN', 'फोन, ठेगाना र PAN')}</div>
        </div>
        <div class="row-end"><span class="badge {shopDone ? 'good' : ''}">{shopDone ? tr('Done', 'भयो') : tr('To do', 'बाँकी')}</span></div>
        <span class="ms chev">chevron_right</span>
      </a>
      <a class="row" href="#/items/new">
        <span class="icon-tile {itemDone ? 'good' : 'primary'}"><span class="ms">{itemDone ? 'check' : 'add'}</span></span>
        <div class="row-main">
          <div class="row-title">{tr('Add your first item', 'पहिलो सामान थप्ने')}</div>
          <div class="row-sub">{tr('Name, price and stock', 'नाम, भाउ र स्टक')}</div>
        </div>
        <div class="row-end"><span class="badge {itemDone ? 'good' : ''}">{itemDone ? tr('Done', 'भयो') : tr('To do', 'बाँकी')}</span></div>
        <span class="ms chev">chevron_right</span>
      </a>
      <a class="row" href="#/customers/new">
        <span class="icon-tile {customerDone ? 'good' : 'primary'}"><span class="ms">{customerDone ? 'check' : 'person_add'}</span></span>
        <div class="row-main">
          <div class="row-title">{tr('Add your first customer', 'पहिलो ग्राहक थप्ने')}</div>
          <div class="row-sub">{tr('Name, phone and credit limit', 'नाम, फोन र उधारो सीमा')}</div>
        </div>
        <div class="row-end"><span class="badge {customerDone ? 'good' : ''}">{customerDone ? tr('Done', 'भयो') : tr('To do', 'बाँकी')}</span></div>
        <span class="ms chev">chevron_right</span>
      </a>
      <a class="row" href="#/settings/staff">
        <span class="icon-tile {staffDone ? 'good' : 'primary'}"><span class="ms">{staffDone ? 'check' : 'badge'}</span></span>
        <div class="row-main">
          <div class="row-title">{tr('Invite staff', 'कर्मचारी थप्ने')}</div>
          <div class="row-sub">{tr('Give staff a login. They cannot see buying prices.', 'कर्मचारीलाई लग इन दिनुहोस्। उनीहरूले खरिद भाउ देख्दैनन्।')}</div>
        </div>
        <div class="row-end"><span class="badge {staffDone ? 'good' : ''}">{staffDone ? tr('Done', 'भयो') : tr('To do', 'बाँकी')}</span></div>
        <span class="ms chev">chevron_right</span>
      </a>
    </div>
  {/if}

  <div class="bottom-bar">
    <button class="btn btn-outline btn-lg btn-block" type="button" onclick={skip}>{tr('Skip for now', 'अहिले छोड्ने')}</button>
  </div>
</div>
