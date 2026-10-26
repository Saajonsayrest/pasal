<script lang="ts">
  import { api, newKey } from '../lib/api'
  import type { ApiError } from '../lib/api'
  import { resource, debounce, action } from '../lib/resource.svelte'
  import { cart, lineAmount, overLimit, vatBreakdown, type Method } from '../lib/cart.svelte'
  import { tr, num } from '../lib/i18n'
  import { rs, toPaisa, fromPaisa, percentOf } from '../lib/money'
  import { navigate } from '../lib/router.svelte'
  import { session } from '../lib/session.svelte'
  import { toast } from '../lib/toast.svelte'
  import { initials } from '../lib/util'
  import type { Customer, Sale } from '../lib/types'
  import Sheet from '../components/Sheet.svelte'
  import AmountPad from '../components/AmountPad.svelte'
  import Field from '../components/Field.svelte'
  import Empty from '../components/Empty.svelte'

  const methods: [Method, string, string, string][] = [
    ['cash', 'Cash', 'नगद', 'payments'],
    ['qr', 'QR', 'QR', 'qr_code_2'],
    ['bank', 'Bank', 'बैंक', 'account_balance'],
    ['card', 'Card', 'कार्ड', 'credit_card'],
  ]

  let { query = {} }: { query?: Record<string, string> } = $props()

  // Coming back from "Add new customer": pick the customer that was just made.
  $effect(() => {
    const id = Number(query.customer)
    if (!id) return
    api
      .get<{ data: Customer }>(`/customers/${id}`)
      .then((res) => {
        cart.setCustomer(res.data)
        navigate('/sell/checkout', true)
      })
      .catch(() => navigate('/sell/checkout', true))
  })

  const save = action()
  let key = newKey()
  let keyBody = ''

  let discOpen = $state(false)
  let discMode = $state<'rs' | 'pct'>('rs')
  let discText = $state('')
  let discErr = $state<string | null>(null)

  let custOpen = $state(false)
  let custTyped = $state('')
  let custTerm = $state('')
  let ignoreLimit = $state(false)

  let paidOpen = $state(false)
  let paidText = $state('0')
  let paidErr = $state<string | null>(null)

  $effect(() => debounce(() => custTyped, 250, (v) => (custTerm = v)))
  const custs = resource(() => api.page<Customer>('/customers', { search: custTerm, per_page: 50 }))

  const rate = $derived(session.business?.vat_rate ?? 0)
  const split = $derived(vatBreakdown(cart.lines, cart.discount, rate))
  const typedPaisa = $derived(toPaisa(paidText))
  const owes = $derived(cart.customer?.owes ?? 0)
  const limit = $derived(cart.customer?.credit_limit ?? null)
  const limitHit = $derived(!!cart.customer && overLimit(owes, cart.balance, limit))
  const limitBlocked = $derived(limitHit && !(session.isOwner && ignoreLimit))
  const blocked = $derived(!cart.canCheckout || limitBlocked)
  const overLine = $derived(cart.lines.find((l) => l.qty > l.item.quantity))

  function errorFor(error: ApiError | null, test: (key: string) => boolean): string | null {
    if (!error) return null
    for (const [name, messages] of Object.entries(error.errors)) {
      if (test(name) && messages[0]) return messages[0]
    }
    return null
  }

  const stockMsg = $derived(errorFor(save.error, (k) => k === 'quantity' || k.startsWith('items')))
  const discMsg = $derived(discErr ?? save.field('discount'))
  const paidMsg = $derived(paidErr ?? save.field('paid'))

  function openDiscount(): void {
    discMode = 'rs'
    discText = cart.discount > 0 ? fromPaisa(cart.discount) : ''
    discErr = null
    discOpen = true
  }

  function applyDiscount(): void {
    const raw = discText.trim() || '0'
    const paisa =
      discMode === 'rs'
        ? toPaisa(raw)
        : /^\d{1,3}(\.\d{1,2})?$/.test(raw) && Number(raw) <= 100
          ? percentOf(cart.subtotal, Number(raw))
          : null
    if (paisa === null) {
      discErr = tr('Type an amount', 'रकम लेख्नुहोस्')
      return
    }
    if (paisa > cart.subtotal) {
      discErr = tr('The discount is more than the bill', 'छुट बिलभन्दा बढी छ')
      return
    }
    cart.setDiscount(paisa)
    discOpen = false
  }

  function pickCustomer(c: Customer | null): void {
    cart.setCustomer(c)
    ignoreLimit = false
    custOpen = false
  }

  function openPaid(): void {
    paidText = fromPaisa(cart.paidAmount)
    paidErr = null
    paidOpen = true
  }

  function presetPaid(paisa: number): void {
    paidText = fromPaisa(paisa)
    paidErr = null
  }

  function applyPaid(): void {
    const p = toPaisa(paidText)
    if (p === null) {
      paidErr = tr('Type an amount', 'रकम लेख्नुहोस्')
      return
    }
    if (p > cart.total) {
      paidErr = tr(`The paid amount is more than the total, ${rs(cart.total)}`, `तिरेको रकम जम्माभन्दा बढी छ, ${rs(cart.total)}`)
      return
    }
    cart.setPaid(p === cart.total ? null : p)
    paidOpen = false
  }

  async function finish(): Promise<void> {
    const body = {
      customer_id: cart.customer?.id,
      paid: cart.paidAmount,
      discount: cart.discount,
      method: cart.method,
      note: cart.note.trim() || undefined,
      items: cart.lines.map((l) => ({ item_id: l.item.id, quantity: l.qty })),
      ...(limitHit && session.isOwner && ignoreLimit ? { ignore_credit_limit: true } : {}),
    }
    const text = JSON.stringify(body)
    if (text !== keyBody) {
      key = newKey()
      keyBody = text
    }
    const res = await save.run(() => api.post<{ data: Sale }>('/sales', body, key))
    if (!res) return
    const sale = res.data
    cart.clear()
    key = newKey()
    keyBody = ''
    toast(`Sale saved as ${sale.bill_no ?? sale.id}`, `बिक्री सेभ भयो: ${sale.bill_no ?? sale.id}`)
    navigate(`/sales/${sale.id}/bill`)
  }
</script>

{#if cart.lines.length === 0}
  <div class="page narrow">
    <Empty icon="shopping_cart" title={tr('The cart is empty', 'कार्ट खाली छ')} text={tr('Add items on the sell screen first.', 'पहिले बिक्री पेजमा सामान थप्नुहोस्।')}>
      <a class="btn btn-primary" href="#/sell">{tr('Go to sell', 'बेच्न जाने')}</a>
    </Empty>
  </div>
{:else}
  <div class="page">
    {#if save.message}
      <div class="alert bad"><span class="ms">error</span><div>{save.message}</div></div>
    {/if}

    <div class="split">
      <div class="stack">
        <section class="card">
          <div class="card-head">
            <h3>{tr('Cart', 'कार्ट')}</h3>
            <span class="small muted">{num(cart.count)} {tr('items', 'सामान')}</span>
          </div>
          {#if stockMsg}
            <div class="alert bad" style="margin-bottom:8px"><span class="ms">error</span><div>{stockMsg}</div></div>
          {:else if overLine}
            <div class="alert warn" style="margin-bottom:8px">
              <span class="ms">warning</span>
              <div>{tr(`Only ${num(overLine.item.quantity)} ${overLine.item.name} left. Lower the amount.`, `${overLine.item.name} मात्र ${num(overLine.item.quantity)} बाँकी छ। संख्या घटाउनुहोस्।`)}</div>
            </div>
          {/if}
          <div class="list plain no-icons">
            {#each cart.lines as line (line.item.id)}
              <div class="row no-icon" style="padding:10px 0">
                <div class="row-main">
                  <div class="row-title">{line.item.name}</div>
                  <div class="row-sub">{rs(line.item.sell_price)} {tr('each', 'प्रति')}</div>
                </div>
                <div class="stepper">
                  <button aria-label={tr('Less', 'कम')} disabled={line.qty <= 1} onclick={() => cart.setQty(line.item.id, line.qty - 1)}><span class="ms">remove</span></button>
                  <span class="val">{num(line.qty)}</span>
                  <button aria-label={tr('More', 'थप')} disabled={line.qty >= line.item.quantity} onclick={() => cart.setQty(line.item.id, line.qty + 1)}><span class="ms">add</span></button>
                </div>
                <span class="amount">{rs(lineAmount(line))}</span>
                <button class="btn btn-icon btn-sm" aria-label={tr('Remove item', 'सामान हटाउने')} onclick={() => cart.remove(line.item.id)}><span class="ms">delete</span></button>
              </div>
            {/each}
          </div>
        </section>

        <div class="list">
          <button class="row" onclick={openDiscount}>
            <span class="icon-tile"><span class="ms">sell</span></span>
            <div class="row-main">
              <div class="row-title">{tr('Bill discount', 'बिलमा छुट')}</div>
              <div class="row-sub">{cart.discount > 0 ? rs(cart.discount) : tr('None', 'छैन')}</div>
              {#if save.field('discount')}<span class="field-error"><span class="ms" style="font-size:16px">error</span><span>{save.field('discount')}</span></span>{/if}
            </div>
            <span class="ms chev">chevron_right</span>
          </button>
          <button class="row" onclick={() => (custOpen = true)}>
            <span class="icon-tile"><span class="ms">person</span></span>
            <div class="row-main">
              <div class="row-title">{cart.customer ? cart.customer.name : tr('Walk-in customer', 'पसलमा आएका ग्राहक')}</div>
              <div class="row-sub">
                {#if cart.customer}
                  {owes > 0 ? tr(`Owes ${rs(owes)}`, `बाँकी ${rs(owes)}`) : tr('Paid up', 'सबै चुक्ता')}
                {:else}
                  {tr('Cash only', 'नगद मात्र')}
                {/if}
              </div>
              {#if save.field('customer_id')}<span class="field-error"><span class="ms" style="font-size:16px">error</span><span>{save.field('customer_id')}</span></span>{/if}
            </div>
            <span class="ms chev">chevron_right</span>
          </button>
        </div>

        <section class="card">
          <div class="kv">
            <div><span class="k">{tr('Subtotal', 'उप-जम्मा')}</span><span class="v">{rs(cart.subtotal)}</span></div>
            <div><span class="k">{tr('Discount', 'छुट')}</span><span class="v">{rs(cart.discount)}</span></div>
            <div><span class="k">{tr('Taxable amount', 'करयोग्य रकम')}</span><span class="v">{rs(split.taxable, { paisa: true })}</span></div>
            <div><span class="k">{tr('VAT', 'भ्याट')} {num(rate)}%</span><span class="v">{rs(split.vat, { paisa: true })}</span></div>
            <div class="total"><span class="k">{tr('Total', 'जम्मा')}</span><span class="v">{rs(cart.total)}</span></div>
            <div><span class="k">{tr('Paid', 'तिरेको')}</span><span class="v good">{rs(cart.paidAmount)}</span></div>
            <div><span class="k">{tr('Balance on credit', 'उधारोमा बाँकी')}</span><span class="v" class:warn={cart.balance > 0}>{rs(cart.balance)}</span></div>
          </div>
        </section>
      </div>

      <aside class="stack sticky-side">
        <section class="card">
          <div class="card-head">
            <h3>{tr('Amount paid', 'तिरेको रकम')}</h3>
            <button class="btn btn-ghost btn-sm" onclick={openPaid}><span class="ms">edit</span><span>{tr('Change', 'बदल्ने')}</span></button>
          </div>
          <span class="stat-value lg">{rs(cart.paidAmount)}</span>
          {#if paidMsg}<span class="field-error" style="margin-top:6px"><span class="ms" style="font-size:16px">error</span><span>{paidMsg}</span></span>{/if}
        </section>

        <section class="card">
          <div class="card-head"><h3>{tr('Payment method', 'भुक्तानी तरिका')}</h3></div>
          <div class="seg block">
            {#each methods as [m, en, ne, icon]}
              <button class:active={cart.method === m} onclick={() => cart.setMethod(m)}><span class="ms">{icon}</span><span>{tr(en, ne)}</span></button>
            {/each}
          </div>
        </section>

        <section class="card">
          <Field label={tr('Note (optional)', 'नोट (ऐच्छिक)')} error={save.field('note')}>
            <input value={cart.note} oninput={(e) => cart.setNote(e.currentTarget.value)} />
          </Field>
        </section>

        {#if cart.balance > 0 && !cart.customer}
          <div class="alert warn">
            <span class="ms">warning</span>
            <div>{tr('Paid is less than the total. Pick a customer for credit (udhar).', 'तिरेको रकम जम्माभन्दा कम छ। उधारोका लागि ग्राहक छान्नुहोस्।')}</div>
          </div>
        {/if}

        {#if limitHit && cart.customer}
          <div class="alert warn">
            <span class="ms">warning</span>
            <div class="stack-sm" style="gap:8px">
              <div>{tr(`${cart.customer.name} would owe ${rs(owes + cart.balance)}. The limit is ${rs(limit ?? 0)}.`, `${cart.customer.name} ले ${rs(owes + cart.balance)} बाँकी राख्छन्। सीमा ${rs(limit ?? 0)} हो।`)}</div>
              {#if session.isOwner}
                <label class="hstack between">
                  <span>{tr('Sell past the limit', 'सीमा नाघेर बेच्ने')}</span>
                  <span class="switch"><input type="checkbox" bind:checked={ignoreLimit} /><span></span></span>
                </label>
              {:else}
                <div class="small">{tr('Ask the owner to allow this sale.', 'यो बिक्री गर्न मालिकलाई सोध्नुहोस्।')}</div>
              {/if}
            </div>
          </div>
        {/if}
      </aside>
    </div>

    <div class="bottom-bar">
      <div class="stack-sm" style="flex:1;gap:0">
        <span class="small muted">{tr('Total', 'जम्मा')}</span>
        <span class="stat-value" style="font-size:22px">{rs(cart.total)}</span>
      </div>
      <button class="btn btn-primary btn-lg" disabled={save.busy || blocked} onclick={finish}>
        <span class="ms">check</span><span>{save.busy ? tr('Saving…', 'सेभ हुँदैछ…') : tr('Finish sale', 'बिक्री पूरा गर्ने')}</span>
      </button>
    </div>
  </div>
{/if}

<Sheet bind:open={discOpen} title={tr('Bill discount', 'बिलमा छुट')}>
  <div class="seg block">
    <button class:active={discMode === 'rs'} onclick={() => (discMode = 'rs')}>Rs</button>
    <button class:active={discMode === 'pct'} onclick={() => (discMode = 'pct')}>%</button>
  </div>
  <Field label={tr('Amount or percent', 'रकम वा प्रतिशत')} error={discMsg} hint={session.isOwner ? '' : tr('Staff can give up to 10 percent of the bill.', 'कर्मचारीले बिलको १० प्रतिशतसम्म छुट दिन सक्छन्।')}>
    <div class="input-group">
      <span class="prefix">{discMode === 'rs' ? 'Rs' : '%'}</span>
      <input inputmode="decimal" placeholder="0" bind:value={discText} />
    </div>
  </Field>
  <button class="btn btn-primary btn-lg btn-block" onclick={applyDiscount}>{tr('Apply discount', 'छुट लागू गर्ने')}</button>
</Sheet>

<Sheet bind:open={custOpen} title={tr('Choose customer', 'ग्राहक छान्नुहोस्')}>
  <label class="search">
    <span class="ms">search</span>
    <input placeholder={tr('Search name or phone', 'नाम वा फोन खोज्नुहोस्')} bind:value={custTyped} />
  </label>
  <div class="list">
    <button class="row" onclick={() => pickCustomer(null)}>
      <span class="avatar good"><span class="ms">person</span></span>
      <div class="row-main">
        <div class="row-title">{tr('Walk-in customer', 'पसलमा आएका ग्राहक')}</div>
        <div class="row-sub">{tr('Cash only', 'नगद मात्र')}</div>
      </div>
    </button>
    {#if custs.error}
      <div class="alert bad"><span class="ms">error</span><div>{custs.error.message}</div></div>
    {:else if custs.loading && !custs.data}
      <p class="small muted">{tr('Loading…', 'लोड हुँदैछ…')}</p>
    {:else}
      {#each custs.data?.data ?? [] as c (c.id)}
        <button class="row" onclick={() => pickCustomer(c)}>
          <span class="avatar" class:warn={(c.owes ?? 0) > 0}>{initials(c.name)}</span>
          <div class="row-main">
            <div class="row-title">{c.name}</div>
            <div class="row-sub">{(c.owes ?? 0) > 0 ? tr(`Owes ${rs(c.owes)}`, `बाँकी ${rs(c.owes)}`) : tr('Paid up', 'सबै चुक्ता')}</div>
          </div>
        </button>
      {/each}
    {/if}
  </div>
  <a class="btn btn-tonal btn-block" href="#/customers/new?next=checkout"><span class="ms">person_add</span><span>{tr('Add new customer', 'नयाँ ग्राहक थप्ने')}</span></a>
</Sheet>

<Sheet bind:open={paidOpen} title={tr('Amount paid', 'तिरेको रकम')}>
  <div class="chips wrap" style="justify-content:center">
    <button class="chip" class:active={typedPaisa === cart.total} onclick={() => presetPaid(cart.total)}>{tr('Full', 'पूरा')}</button>
    <button class="chip" class:active={typedPaisa === percentOf(cart.total, 50)} onclick={() => presetPaid(percentOf(cart.total, 50))}>{tr('Half', 'आधा')}</button>
    <button class="chip" class:active={typedPaisa === 0} onclick={() => presetPaid(0)}>{tr('Nothing (credit)', 'केही होइन (उधारो)')}</button>
  </div>
  <AmountPad bind:value={paidText} />
  {#if paidErr}<span class="field-error"><span class="ms" style="font-size:16px">error</span><span>{paidErr}</span></span>{/if}
  <button class="btn btn-primary btn-lg btn-block" onclick={applyPaid}>{tr('Done', 'सम्पन्न')}</button>
</Sheet>
