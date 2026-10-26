<script lang="ts">
  import { api } from '../lib/api'
  import { resource, debounce } from '../lib/resource.svelte'
  import { cart, vatBreakdown, type CartItem } from '../lib/cart.svelte'
  import { tr, num } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { navigate } from '../lib/router.svelte'
  import { session } from '../lib/session.svelte'
  import { toast } from '../lib/toast.svelte'
  import { portal } from '../lib/portal'
  import type { Category, Item } from '../lib/types'
  import Sheet from '../components/Sheet.svelte'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Empty from '../components/Empty.svelte'

  let typed = $state('')
  let term = $state('')
  let category = $state<number | null>(null)
  let camOpen = $state(false)

  $effect(() => debounce(() => typed, 250, (v) => (term = v)))

  const categories = resource(() => api.all<Category>('/categories'))
  const items = resource(() => api.page<Item>('/items', { search: term, category_id: category, per_page: 50 }))

  const rows = $derived(items.data?.data ?? [])
  const hasCamera = typeof window !== 'undefined' && 'BarcodeDetector' in window
  const split = $derived(vatBreakdown(cart.lines, cart.discount, session.business?.vat_rate ?? 0))

  function inCart(id: number): number {
    return cart.lines.find((l) => l.item.id === id)?.qty ?? 0
  }

  function addItem(item: CartItem): void {
    if (!cart.add(item)) toast('No more of this item in stock', 'यो सामानको स्टक सकियो')
  }

  async function addByCode(raw: string): Promise<void> {
    const code = raw.trim()
    if (!code) return
    let found = rows.find((i) => i.sku === code)
    if (!found) {
      const res = await api.page<Item>('/items', { search: code, per_page: 50 })
      found = res.data.find((i) => i.sku === code)
    }
    if (!found) {
      toast(`No item has the code ${code}`, `${code} कोडको सामान भेटिएन`)
      return
    }
    if (cart.add(found)) {
      typed = ''
      toast(`Added ${found.name}`, `${found.name} थपियो`)
    } else {
      toast('No more of this item in stock', 'यो सामानको स्टक सकियो')
    }
  }

  function onSearchKey(e: KeyboardEvent): void {
    if (e.key !== 'Enter') return
    e.preventDefault()
    void addByCode(typed)
  }

  function foundOnCamera(code: string): void {
    if (!camOpen) return
    camOpen = false
    void addByCode(code)
  }

  function camera(node: HTMLVideoElement, onFound: (code: string) => void) {
    type Detector = { detect(source: HTMLVideoElement): Promise<{ rawValue: string }[]> }
    const Ctor = (window as unknown as { BarcodeDetector: new (o: { formats: string[] }) => Detector }).BarcodeDetector
    const detector = new Ctor({ formats: ['ean_13', 'ean_8', 'upc_a', 'upc_e', 'code_128', 'qr_code'] })
    let stream: MediaStream | null = null
    let timer: ReturnType<typeof setInterval> | undefined
    let busy = false
    let closed = false

    const stop = () => {
      closed = true
      clearInterval(timer)
      stream?.getTracks().forEach((t) => t.stop())
      node.srcObject = null
    }

    navigator.mediaDevices
      .getUserMedia({ video: { facingMode: 'environment' } })
      .then(async (s) => {
        if (closed) {
          s.getTracks().forEach((t) => t.stop())
          return
        }
        stream = s
        node.srcObject = s
        await node.play()
        timer = setInterval(async () => {
          if (busy) return
          busy = true
          try {
            const code = (await detector.detect(node))[0]?.rawValue
            if (code) onFound(code)
          } catch {
            // A frame that cannot be read is skipped.
          } finally {
            busy = false
          }
        }, 400)
      })
      .catch(() => toast('The camera is not available', 'क्यामेरा खुलेन'))

    return { destroy: stop }
  }

  function holdCart(): void {
    if (cart.hold()) navigate('/sell/held')
  }
</script>

<div class="page">
  <div use:portal={'#topbar-actions'} class="contents">
    <a class="btn btn-icon" href="#/sell/held" aria-label={tr('Held carts', 'रोकिएका कार्ट')}>
      <span class="ms">pause_circle</span>
      {#if cart.held.length > 0}<span class="badge primary">{num(cart.held.length)}</span>{/if}
    </a>
    <a class="btn btn-icon" href="#/sales" aria-label={tr('Sales list', 'बिक्री सूची')}><span class="ms">history</span></a>
  </div>

  <div class="split">
    <div class="stack">
      <div class="hstack">
        <label class="search">
          <span class="ms">search</span>
          <input placeholder={tr('Search item name or code', 'सामानको नाम वा कोड खोज्नुहोस्')} bind:value={typed} onkeydown={onSearchKey} />
        </label>
        {#if hasCamera}
          <button class="btn btn-primary btn-icon" style="width:50px;min-height:50px;color:var(--on-seed)" aria-label={tr('Scan with camera', 'क्यामेराले स्क्यान')} onclick={() => (camOpen = true)}>
            <span class="ms">barcode_scanner</span>
          </button>
        {/if}
      </div>

      {#if categories.error}
        <ErrorCard error={categories.error} retry={categories.reload} />
      {:else}
        <div class="chips">
          <button class="chip" class:active={category === null} onclick={() => (category = null)}>{tr('All', 'सबै')}</button>
          {#each categories.data ?? [] as cat (cat.id)}
            <button class="chip" class:active={category === cat.id} onclick={() => (category = cat.id)}>{cat.name}</button>
          {/each}
        </div>
      {/if}

      {#if items.error}
        <ErrorCard error={items.error} retry={items.reload} />
      {:else if items.loading && !items.data}
        <Skeleton card />
      {:else if rows.length === 0}
        <Empty icon="search_off" title={tr('No items found', 'सामान भेटिएन')} text={tr('Try another word or category.', 'अर्को शब्द वा वर्ग छान्नुहोस्।')} />
      {:else}
        <div class="item-grid">
          {#each rows as item (item.id)}
            {@const qty = inCart(item.id)}
            {@const out = item.quantity <= 0}
            <button class="item-tile" class:low={item.is_low_stock} class:selected={qty > 0} class:out disabled={out} onclick={() => addItem(item)}>
              {#if qty > 0}<span class="qty-badge">{num(qty)}</span>{/if}
              {#if item.photo_url}
                <img class="photo" src={item.photo_url} alt="" />
              {:else}
                <span class="emoji"><span class="ms">inventory_2</span></span>
              {/if}
              <span class="name">{item.name}</span>
              <span class="stock">
                {#if out}
                  <span>{tr('No stock', 'स्टक छैन')}</span>
                {:else}
                  <span>{num(item.quantity)}</span> <span>{item.is_low_stock ? tr('left only', 'मात्र बाँकी') : tr('left', 'बाँकी')}</span>
                {/if}
              </span>
              <span class="price">{rs(item.sell_price)}</span>
            </button>
          {/each}
        </div>
      {/if}
    </div>

    <aside class="sticky-side stack">
      <section class="card wide-only">
        <div class="card-head">
          <h3>{tr('Cart', 'कार्ट')}</h3>
          <button class="btn btn-ghost btn-sm" disabled={cart.count === 0} onclick={holdCart}><span class="ms">pause</span><span>{tr('Hold', 'रोक्ने')}</span></button>
        </div>
        {#if cart.lines.length === 0}
          <p class="small muted">{tr('No items yet. Tap an item to add it.', 'अहिलेसम्म सामान छैन। सामानमा थिचेर थप्नुहोस्।')}</p>
        {:else}
          <div class="list plain no-icons">
            {#each cart.lines as line (line.item.id)}
              <div class="row no-icon" style="padding:10px 0">
                <div class="row-main">
                  <div class="row-title">{line.item.name}</div>
                  <div class="row-sub">{rs(line.item.sell_price)}</div>
                </div>
                <div class="stepper">
                  <button aria-label={tr('Less', 'कम')} disabled={line.qty <= 1} onclick={() => cart.setQty(line.item.id, line.qty - 1)}><span class="ms">remove</span></button>
                  <span class="val">{num(line.qty)}</span>
                  <button aria-label={tr('More', 'थप')} disabled={line.qty >= line.item.quantity} onclick={() => cart.setQty(line.item.id, line.qty + 1)}><span class="ms">add</span></button>
                </div>
              </div>
            {/each}
          </div>
          <div class="divider"></div>
          <div class="kv">
            <div><span class="k">{tr('Items', 'सामान')}</span><span class="v">{num(cart.count)}</span></div>
            <div><span class="k">{tr('VAT included', 'भ्याट सहित')}</span><span class="v">{rs(split.vat, { paisa: true })}</span></div>
            <div class="total"><span class="k">{tr('Total', 'जम्मा')}</span><span class="v">{rs(cart.total)}</span></div>
          </div>
        {/if}
        <button class="btn btn-primary btn-lg btn-block" style="margin-top:12px" disabled={cart.count === 0} onclick={() => navigate('/sell/checkout')}>
          <span>{tr('Go to payment', 'भुक्तानीमा जाने')}</span><span class="ms">arrow_forward</span>
        </button>
      </section>
    </aside>
  </div>

  <div class="bottom-bar phone-only">
    <div class="stack-sm" style="flex:1;gap:0">
      <span class="small muted">{num(cart.count)} {tr('items', 'सामान')}</span>
      <span class="stat-value" style="font-size:22px">{rs(cart.total)}</span>
    </div>
    <button class="btn btn-tonal btn-icon" aria-label={tr('Hold cart', 'कार्ट रोक्ने')} disabled={cart.count === 0} onclick={holdCart}><span class="ms">pause</span></button>
    <button class="btn btn-primary btn-lg" disabled={cart.count === 0} onclick={() => navigate('/sell/checkout')}>
      <span>{tr('Checkout', 'भुक्तानी')}</span><span class="ms">arrow_forward</span>
    </button>
  </div>
</div>

<Sheet bind:open={camOpen} title={tr('Scan a barcode', 'बारकोड स्क्यान')}>
  <video class="scan-view" muted playsinline use:camera={foundOnCamera}></video>
  <p class="small muted center">{tr('Hold the code in front of the camera.', 'कोड क्यामेराको अगाडि राख्नुहोस्।')}</p>
</Sheet>

<style>
  .item-tile .photo {
    width: 48px;
    height: 48px;
    object-fit: cover;
    border-radius: 12px;
  }
  .item-tile.out {
    opacity: 0.45;
  }
  .scan-view {
    width: 100%;
    aspect-ratio: 4 / 3;
    border-radius: var(--r-md);
    background: #000;
    object-fit: cover;
  }
</style>
