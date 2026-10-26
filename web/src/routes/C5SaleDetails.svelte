<script lang="ts">
  import { api, newKey } from '../lib/api'
  import { resource, action } from '../lib/resource.svelte'
  import { tr, num } from '../lib/i18n'
  import { rs, toPaisa, fromPaisa } from '../lib/money'
  import { formatDate, formatTime } from '../lib/bs'
  import { session } from '../lib/session.svelte'
  import { toast } from '../lib/toast.svelte'
  import type { Sale } from '../lib/types'
  import Sheet from '../components/Sheet.svelte'
  import AmountPad from '../components/AmountPad.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Skeleton from '../components/Skeleton.svelte'

  let { params }: { params: Record<string, string> } = $props()

  const METHODS: Record<string, [string, string]> = {
    cash: ['Cash', 'नगद'],
    qr: ['QR', 'QR'],
    bank: ['Bank', 'बैंक'],
    card: ['Card', 'कार्ड'],
    esewa: ['eSewa', 'eSewa'],
    khalti: ['Khalti', 'Khalti'],
  }

  const bill = resource(() => api.get<{ data: Sale }>(`/sales/${params.id}`))
  const sale = $derived(bill.data?.data)
  const cancelled = $derived(!!sale?.cancelled_at)

  let payOpen = $state(false)
  let payText = $state('0')
  let payMethod = $state<'cash' | 'qr' | 'bank'>('cash')
  const pay = action()
  let payKey = newKey()
  let payBody = ''

  const payPaisa = $derived(toPaisa(payText))
  const payable = $derived(!!sale && sale.balance > 0 && payPaisa !== null && payPaisa > 0)

  function openPay(): void {
    payText = fromPaisa(sale?.balance ?? 0)
    pay.clear()
    payOpen = true
  }

  async function savePayment(): Promise<void> {
    if (!sale || payPaisa === null) return
    const body = { sale_id: sale.id, amount: payPaisa, method: payMethod }
    const text = JSON.stringify(body)
    if (text !== payBody) {
      payKey = newKey()
      payBody = text
    }
    const res = await pay.run(() => api.post<{ data: unknown; balance_left: number }>('/payments', body, payKey))
    if (!res) return
    payKey = newKey()
    payBody = ''
    payOpen = false
    toast('Payment saved', 'भुक्तानी सेभ भयो')
    bill.reload()
  }

  const status = $derived.by(() => {
    if (!sale) return { text: '', cls: '', icon: '' }
    if (sale.cancelled_at) return { text: tr('Cancelled', 'रद्द'), cls: 'bad', icon: 'cancel' }
    if (sale.returned_total > 0) return { text: tr('Returned', 'फिर्ता'), cls: 'info', icon: 'undo' }
    if (sale.balance > 0) return { text: tr('Credit', 'उधारो'), cls: 'warn', icon: 'schedule' }
    return { text: tr('Paid', 'तिरेको'), cls: 'good', icon: 'check_circle' }
  })
</script>

<div class="page narrow">
  {#if bill.error}
    <ErrorCard error={bill.error} retry={bill.reload} />
  {:else if bill.loading && !bill.data}
    <Skeleton card />
  {:else if sale}
    <section class="card">
      <div class="hstack between" style="align-items:flex-start">
        <div class="stack-sm" style="gap:2px">
          <span class="small muted">{tr('Bill', 'बिल')} {sale.bill_no ?? `#${sale.id}`}</span>
          {#if sale.customer_id}
            <h2><a href={`#/customers/${sale.customer_id}`}>{sale.customer?.name ?? tr('Customer', 'ग्राहक')}</a></h2>
          {:else}
            <h2>{tr('Walk-in customer', 'पसलमा आएका ग्राहक')}</h2>
          {/if}
        </div>
        <span class="badge {status.cls}"><span class="ms">{status.icon}</span><span>{status.text}</span></span>
      </div>
      <div class="kv" style="margin-top:10px">
        <div><span class="k">{tr('Sold by', 'बेच्ने')}</span><span class="v">{sale.sold_by ?? tr('Not known', 'थाहा छैन')} · {formatTime(sale.sold_at)} · {formatDate(sale.sold_at)}</span></div>
      </div>
    </section>

    {#if cancelled}
      <div class="alert bad"><span class="ms">cancel</span><div>{tr('This bill is cancelled. Nothing more can be paid or returned.', 'यो बिल रद्द भएको छ। अब भुक्तानी वा फिर्ता हुँदैन।')}</div></div>
    {/if}

    <div class="section-title"><h3>{tr('Items', 'सामान')}</h3></div>
    <div class="list">
      {#each sale.items ?? [] as line (line.id)}
        <div class="row">
          <span class="icon-tile"><span class="ms">inventory_2</span></span>
          <div class="row-main">
            <div class="row-title">{line.item_name}</div>
            <div class="row-sub">{num(line.quantity)} × {rs(line.unit_price)}</div>
            {#if line.returned_quantity > 0}
              <div class="row-sub warn">{tr(`${num(line.returned_quantity)} returned`, `${num(line.returned_quantity)} फिर्ता`)}</div>
            {/if}
          </div>
          <span class="amount">{rs(line.line_total)}</span>
        </div>
      {/each}
    </div>

    <section class="card">
      <div class="kv">
        <div><span class="k">{tr('Subtotal', 'उप-जम्मा')}</span><span class="v">{rs(sale.subtotal)}</span></div>
        {#if sale.discount > 0}<div><span class="k">{tr('Discount', 'छुट')}</span><span class="v">{rs(sale.discount)}</span></div>{/if}
        <div class="total"><span class="k">{tr('Total', 'जम्मा')}</span><span class="v">{rs(sale.total)}</span></div>
        {#if sale.returned_total > 0}<div><span class="k">{tr('Returned goods', 'फिर्ता सामान')}</span><span class="v">{rs(sale.returned_total)}</span></div>{/if}
        <div><span class="k">{tr('Paid', 'तिरेको')}</span><span class="v good">{rs(sale.paid)}</span></div>
        <div><span class="k">{tr('Balance on credit', 'उधारो बाँकी')}</span><span class="v" class:warn={sale.balance > 0}>{rs(sale.balance)}</span></div>
      </div>
    </section>

    <div class="section-title"><h3>{tr('Payments', 'भुक्तानी')}</h3></div>
    {#if (sale.payments ?? []).length === 0}
      <section class="card">
        <div class="empty" style="padding:14px 8px">
          <span class="ms" style="font-size:30px;color:var(--muted)">payments</span>
          <p>{tr('No payment yet', 'अहिलेसम्म कुनै भुक्तानी छैन')}</p>
        </div>
      </section>
    {:else}
      <div class="list">
        {#each sale.payments ?? [] as p (p.id)}
          {@const m = METHODS[p.method]}
          <div class="row">
            <span class="icon-tile"><span class="ms">{p.direction === 'refund' ? 'undo' : 'call_received'}</span></span>
            <div class="row-main">
              <div class="row-title">{p.direction === 'refund' ? tr('Given back', 'फिर्ता दिइयो') : tr('Received', 'प्राप्त')} · {m ? tr(m[0], m[1]) : p.method}</div>
              <div class="row-sub">{formatDate(p.paid_at)} · {formatTime(p.paid_at)}</div>
            </div>
            <span class="amount" class:good={p.direction !== 'refund'} class:warn={p.direction === 'refund'}>{rs(p.direction === 'refund' ? -p.amount : p.amount)}</span>
          </div>
        {/each}
      </div>
    {/if}

    {#if (sale.returns ?? []).length > 0}
      <div class="section-title"><h3>{tr('Returns', 'फिर्ता')}</h3></div>
      <div class="list">
        {#each sale.returns ?? [] as r (r.id)}
          <div class="row">
            <span class="icon-tile"><span class="ms">undo</span></span>
            <div class="row-main">
              <div class="row-title">{r.kind === 'cancel' ? tr('Sale cancelled', 'बिक्री रद्द') : tr('Items returned', 'सामान फिर्ता')}</div>
              <div class="row-sub">{formatDate(r.returned_at)} · {num(r.items.reduce((sum, i) => sum + i.quantity, 0))} {tr('items', 'सामान')}{r.restocked ? '' : tr(', not put back in stock', ', स्टकमा फर्किएन')}</div>
              {#if r.note}<div class="row-sub">{r.note}</div>{/if}
              <div class="row-sub">{tr('Refunded', 'फिर्ता रकम')} {rs(r.refunded)}</div>
            </div>
            <span class="amount">{rs(r.total)}</span>
          </div>
        {/each}
      </div>
    {/if}

    {#if !cancelled}
      <button class="btn btn-good btn-lg btn-block" onclick={openPay}><span class="ms">call_received</span><span>{tr('Take payment', 'पैसा लिने')}</span></button>
    {/if}
    <div class="grid-2">
      <a class="btn btn-tonal" href={`#/sales/${sale.id}/bill`}><span class="ms">receipt</span><span>{tr('View bill', 'बिल हेर्ने')}</span></a>
      {#if session.isOwner && !cancelled}
        <a class="btn btn-outline" href={`#/sales/${sale.id}/return`}><span class="ms">undo</span><span>{tr('Return items', 'सामान फिर्ता')}</span></a>
      {/if}
    </div>
    {#if session.isOwner && !cancelled}
      <a class="btn btn-danger btn-block" href={`#/sales/${sale.id}/cancel`}><span class="ms">cancel</span><span>{tr('Cancel sale', 'बिक्री रद्द')}</span></a>
    {/if}
  {/if}
</div>

<Sheet bind:open={payOpen} title={tr('Take payment', 'पैसा लिने')}>
  <div class="chips" style="justify-content:center">
    <button class="chip" class:active={payPaisa === sale?.balance} onclick={() => (payText = fromPaisa(sale?.balance ?? 0))}>{tr('Full', 'पूरा')} {rs(sale?.balance ?? 0)}</button>
    <button class="chip" onclick={() => (payText = '500')}>{rs(50000)}</button>
    <button class="chip" onclick={() => (payText = '200')}>{rs(20000)}</button>
  </div>
  <div class="seg block">
    <button class:active={payMethod === 'cash'} onclick={() => (payMethod = 'cash')}><span class="ms">payments</span><span>{tr('Cash', 'नगद')}</span></button>
    <button class:active={payMethod === 'qr'} onclick={() => (payMethod = 'qr')}><span class="ms">qr_code_2</span><span>QR</span></button>
    <button class:active={payMethod === 'bank'} onclick={() => (payMethod = 'bank')}><span class="ms">account_balance</span><span>{tr('Bank', 'बैंक')}</span></button>
  </div>
  <AmountPad bind:value={payText} />
  {#if pay.field('amount')}
    <span class="field-error"><span class="ms" style="font-size:16px">error</span><span>{pay.field('amount')}</span></span>
  {:else if pay.error}
    <span class="field-error"><span class="ms" style="font-size:16px">error</span><span>{pay.error.message}</span></span>
  {/if}
  <p class="small muted center">{tr('The money goes to this bill.', 'यो पैसा यही बिलमा जान्छ।')}</p>
  <button class="btn btn-good btn-lg btn-block" disabled={pay.busy || !payable} onclick={savePayment}>
    <span class="ms">check</span><span>{pay.busy ? tr('Saving…', 'सेभ हुँदैछ…') : tr('Save payment', 'सेभ गर्ने')}</span>
  </button>
</Sheet>
