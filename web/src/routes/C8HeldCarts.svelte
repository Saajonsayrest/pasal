<script lang="ts">
  import { cart, countOf, subtotalOf, totalOf, type HeldCart } from '../lib/cart.svelte'
  import { tr, num } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { formatTime } from '../lib/bs'
  import { navigate } from '../lib/router.svelte'
  import { toast } from '../lib/toast.svelte'
  import Sheet from '../components/Sheet.svelte'
  import Empty from '../components/Empty.svelte'

  let confirmOpen = $state(false)
  let discardId = $state<string | null>(null)
  const discarding = $derived(cart.held.find((h) => h.id === discardId) ?? null)

  function heldTotal(h: HeldCart): number {
    return totalOf(subtotalOf(h.lines), h.discount)
  }

  function namesOf(h: HeldCart): string {
    return h.lines.map((l) => l.item.name).join(', ')
  }

  function resume(h: HeldCart): void {
    if (cart.restore(h.id)) navigate('/sell')
  }

  function askDiscard(h: HeldCart): void {
    discardId = h.id
    confirmOpen = true
  }

  function discard(): void {
    if (discardId) cart.discard(discardId)
    discardId = null
    confirmOpen = false
    toast('Held cart deleted', 'रोकिएको कार्ट हटाइयो')
  }
</script>

<div class="page narrow">
  {#if cart.lines.length > 0 && cart.held.length > 0}
    <div class="alert">
      <span class="ms">info</span>
      <div>{tr('Your current cart will be held first when you resume a cart.', 'कार्ट फेरि सुरु गर्दा हालको कार्ट पहिले रोकिनेछ।')}</div>
    </div>
  {/if}

  {#if cart.held.length === 0}
    <section class="card">
      <Empty icon="pause_circle" title={tr('No held carts', 'कुनै कार्ट रोकिएको छैन')} text={tr('Hold a cart when a customer needs to wait. It shows here.', 'ग्राहकले पर्खनुपर्दा कार्ट रोक्न सकिन्छ। त्यो यहाँ देखिन्छ।')}>
        <a class="btn btn-tonal" href="#/sell"><span class="ms">add_shopping_cart</span><span>{tr('New sale', 'नयाँ बिक्री')}</span></a>
      </Empty>
    </section>
  {:else}
    {#each cart.held as h (h.id)}
      <section class="card">
        <div class="hstack between" style="align-items:flex-start">
          <div class="stack-sm" style="gap:2px">
            <span class="small muted">{tr('Held at', 'रोकिएको')} {formatTime(h.at)}</span>
            <h3>{h.label || tr('No name', 'नाम छैन')}</h3>
          </div>
          <span class="badge primary">{num(countOf(h.lines))} {tr('items', 'सामान')}</span>
        </div>
        <p class="small muted" style="margin-top:6px">{namesOf(h)}</p>
        <div class="hstack between" style="margin-top:12px">
          <div class="stack-sm" style="gap:0">
            <span class="small muted">{tr('Total', 'जम्मा')}</span>
            <span class="stat-value" style="font-size:22px">{rs(heldTotal(h))}</span>
          </div>
          <div class="hstack">
            <button class="btn btn-outline" onclick={() => askDiscard(h)}><span class="ms">delete</span><span>{tr('Discard', 'हटाउने')}</span></button>
            <button class="btn btn-primary" onclick={() => resume(h)}><span class="ms">play_arrow</span><span>{tr('Resume', 'फेरि सुरु')}</span></button>
          </div>
        </div>
      </section>
    {/each}
  {/if}
</div>

<Sheet bind:open={confirmOpen} title={tr('Discard this cart?', 'यो कार्ट हटाउने?')}>
  <p>{discarding?.label ? `${discarding.label}. ` : ''}{tr('The held cart and its items are removed. This cannot be undone.', 'रोकिएको कार्ट र यसका सामान हट्छन्। यो फिर्ता हुँदैन।')}</p>
  <div class="grid-2">
    <button class="btn btn-outline btn-lg" onclick={() => (confirmOpen = false)}>{tr('Keep it', 'राख्ने')}</button>
    <button class="btn btn-danger btn-lg" onclick={discard}><span class="ms">delete</span><span>{tr('Discard', 'हटाउने')}</span></button>
  </div>
</Sheet>
