<script lang="ts">
  import { api } from '../lib/api'
  import { resource } from '../lib/resource.svelte'
  import { session } from '../lib/session.svelte'
  import { tr, num } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { formatTime, todayAd } from '../lib/bs'
  import { portal } from '../lib/portal'
  import { setTitle } from '../lib/shell.svelte'
  import { initials, telHref } from '../lib/util'
  import type { Customer, Item, Sale } from '../lib/types'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Empty from '../components/Empty.svelte'

  const today = todayAd()
  const first = session.user?.name.split(' ')[0] ?? ''
  $effect(() => setTitle(tr(`Namaste, ${first}`, `नमस्ते, ${first}`)))

  const mine = resource(async () => {
    const name = session.user?.name
    const all = await api.all<Sale>('/sales', { from: today, to: today })
    return all.filter((s) => s.sold_by === name && s.cancelled_at === null)
  })
  const remind = resource(() => api.page<Customer>('/customers', { owes: 1, sort: 'oldest', per_page: 5 }))
  const low = resource(() => api.page<Item>('/items', { low_stock: 1, per_page: 3 }))

  const count = $derived(mine.data?.length ?? 0)
  const total = $derived((mine.data ?? []).reduce((sum, s) => sum + s.total - s.returned_total, 0))
  const recent = $derived((mine.data ?? []).slice(0, 3))
</script>

<div class="page">
  <div use:portal={'#topbar-actions'} class="contents">
    <a class="btn btn-icon" href="#/notifications" aria-label={tr('Notifications', 'सूचनाहरू')}><span class="ms">notifications</span></a>
    <a class="btn btn-icon phone-only" href="#/profile" aria-label={tr('Profile', 'प्रोफाइल')}><span class="avatar" style="width:34px;height:34px;font-size:13px">{initials(session.user?.name ?? '')}</span></a>
  </div>

  <a class="hero hstack between" href="#/sell" style="padding:26px 22px;min-height:160px">
    <div class="stack-sm">
      <span class="stat-label">{tr('For the next customer', 'अर्को ग्राहकलाई')}</span>
      <span class="stat-value xl">{tr('New sale', 'नयाँ बिक्री')}</span>
    </div>
    <span class="icon-tile lg" style="background:rgb(255 255 255 / .2);color:#fff"><span class="ms" style="font-size:30px">add_shopping_cart</span></span>
  </a>

  <section class="card">
    <div class="card-head"><h3>{tr('My sales today', 'आजको मेरो बिक्री')}</h3><a href="#/sales">{tr('See all', 'सबै')}</a></div>
    {#if mine.error}
      <ErrorCard error={mine.error} retry={mine.reload} />
    {:else if mine.loading && !mine.data}
      <Skeleton card />
    {:else}
      <div class="grid-2">
        <div class="stat"><span class="stat-label">{tr('Total amount', 'जम्मा रकम')}</span><span class="stat-value">{rs(total)}</span></div>
        <div class="stat"><span class="stat-label">{tr('Bills', 'बिल')}</span><span class="stat-value">{num(count)}</span></div>
      </div>
    {/if}
  </section>

  <div class="section-title"><h3>{tr('Customers to remind', 'सम्झाउनुपर्ने ग्राहक')}</h3><a href="#/customers">{tr('See all', 'सबै')}</a></div>
  <div class="list">
    {#if remind.error}
      <ErrorCard error={remind.error} retry={remind.reload} />
    {:else if remind.loading && !remind.data}
      <Skeleton rows={3} />
    {:else if (remind.data?.data.length ?? 0) === 0}
      <Empty icon="done_all" title={tr('No one owes money', 'कसैको उधारो बाँकी छैन')} />
    {:else}
      {#each remind.data?.data ?? [] as c (c.id)}
        <div class="row">
          <span class="avatar">{initials(c.name)}</span>
          <div class="row-main">
            <div class="row-title">{c.name}</div>
            <div class="row-sub">{tr('To collect', 'उठाउन बाँकी')}</div>
          </div>
          <div class="row-end">
            <span class="amount">{rs(c.owes)}</span>
            <div class="hstack" style="gap:6px">
              {#if c.phone}
                <a class="btn btn-ghost btn-sm" href={telHref(c.phone)} aria-label={tr('Call', 'फोन गर्ने')}><span class="ms">call</span></a>
              {/if}
              <a class="btn btn-tonal btn-sm" href={`#/customers/${c.id}/remind`}><span class="ms">notifications_active</span><span>{tr('Remind', 'सम्झाउने')}</span></a>
            </div>
          </div>
        </div>
      {/each}
    {/if}
  </div>

  <div class="section-title"><h3>{tr('Low stock', 'कम स्टक')}</h3><a href="#/low-stock">{tr('See all', 'सबै')}</a></div>
  <div class="list">
    {#if low.error}
      <ErrorCard error={low.error} retry={low.reload} />
    {:else if low.loading && !low.data}
      <Skeleton rows={2} />
    {:else}
      {#each low.data?.data ?? [] as item (item.id)}
        <div class="row">
          <span class="icon-tile warn"><span class="ms">production_quantity_limits</span></span>
          <div class="row-main">
            <div class="row-title">{item.name}</div>
            <div class="row-sub">{tr(`Only ${num(item.quantity)} ${item.unit} left`, `मात्र ${num(item.quantity)} ${item.unit} बाँकी`)}</div>
          </div>
        </div>
      {/each}
      {#if (low.data?.meta.total ?? 0) > 3}
        <a class="row" href="#/low-stock">
          <span class="icon-tile"><span class="ms">more_horiz</span></span>
          <div class="row-main">
            <div class="row-title">{tr(`${num((low.data?.meta.total ?? 0) - 3)} more items`, `अरू ${num((low.data?.meta.total ?? 0) - 3)} सामान`)}</div>
            <div class="row-sub">{tr('Their stock is low too', 'यिनीहरूको स्टक पनि कम छ')}</div>
          </div>
          <span class="ms chev">chevron_right</span>
        </a>
      {/if}
    {/if}
  </div>

  <div class="section-title"><h3>{tr('My recent sales', 'मेरा भर्खरका बिक्री')}</h3></div>
  <div class="list">
    {#if mine.error}
      <ErrorCard error={mine.error} retry={mine.reload} />
    {:else if mine.loading && !mine.data}
      <Skeleton rows={3} />
    {:else if recent.length === 0}
      <Empty icon="receipt" title={tr('No sales yet today', 'आज अहिलेसम्म बिक्री छैन')} />
    {:else}
      {#each recent as s (s.id)}
        <a class="row" href={`#/sales/${s.id}`}>
          <span class="icon-tile"><span class="ms">receipt</span></span>
          <div class="row-main">
            <div class="row-title">{s.customer?.name ?? tr('Walk-in customer', 'पसलमा आएका ग्राहक')}</div>
            <div class="row-sub">{s.bill_no ?? ''} · {formatTime(s.sold_at)}</div>
          </div>
          <div class="row-end">
            <span class="amount">{rs(s.total)}</span>
            {#if s.balance > 0}
              <span class="badge warn">{tr('Credit', 'उधारो')}</span>
            {:else}
              <span class="badge good">{tr('Paid', 'भुक्तानी भयो')}</span>
            {/if}
          </div>
        </a>
      {/each}
    {/if}
  </div>
</div>
