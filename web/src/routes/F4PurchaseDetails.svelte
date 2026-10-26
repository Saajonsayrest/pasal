<script lang="ts">
  import { api, newKey } from '../lib/api'
  import { resource, action } from '../lib/resource.svelte'
  import { tr, num } from '../lib/i18n'
  import { rs, toPaisa, fromPaisa } from '../lib/money'
  import { formatDate } from '../lib/bs'
  import { toast } from '../lib/toast.svelte'
  import type { Payment, Purchase } from '../lib/types'
  import AmountPad from '../components/AmountPad.svelte'
  import Sheet from '../components/Sheet.svelte'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'

  let { params }: { params: Record<string, string> } = $props()

  const purchase = resource(async () => (await api.get<{ data: Purchase }>(`/purchases/${params.id}`)).data)
  const p = $derived(purchase.data)

  const methods = [
    { key: 'cash', icon: 'payments', en: 'Cash', ne: 'नगद' },
    { key: 'bank', icon: 'account_balance', en: 'Bank', ne: 'बैंक' },
    { key: 'cheque', icon: 'receipt', en: 'Cheque', ne: 'चेक' },
  ]

  function methodText(m: string): string {
    if (m === 'cash') return tr('cash', 'नगद')
    if (m === 'bank') return tr('bank', 'बैंक')
    if (m === 'cheque') return tr('cheque', 'चेक')
    return m || tr('not set', 'छैन')
  }

  let payOpen = $state(false)
  let amountText = $state('0')
  let method = $state('cash')
  const pay = action()
  let payKey = newKey()

  function openPay(): void {
    if (!p) return
    amountText = fromPaisa(p.balance)
    payOpen = true
  }

  async function sendPayment(): Promise<void> {
    const amount = toPaisa(amountText)
    if (!p || amount === null || amount <= 0) return
    const res = await pay.run(() =>
      api.post<{ data: Payment; balance_left: number }>('/payments', { purchase_id: p.id, amount, method }, payKey),
    )
    if (!res) return
    payKey = newKey()
    payOpen = false
    toast(`Payment saved. We owe ${rs(res.balance_left)} on this bill.`, `भुक्तानी सेभ भयो। यो बिलमा हामीले ${rs(res.balance_left)} तिर्नुपर्छ।`)
    await purchase.reload()
  }
</script>

<div class="page narrow">
  {#if purchase.error}
    <ErrorCard error={purchase.error} retry={purchase.reload} />
  {:else if p}
    <section class="card">
      <div class="hstack between" style="align-items:flex-start">
        <div class="stack-sm" style="gap:2px">
          <span class="small muted">
            {p.bill_no ? tr(`Bill ${p.bill_no}`, `बिल ${p.bill_no}`) : tr('No bill number', 'बिल नम्बर छैन')}
          </span>
          <h2><a href={`#/suppliers/${p.supplier_id}`}>{p.supplier?.name ?? tr('Deleted supplier', 'हटाइएको डिलर')}</a></h2>
        </div>
        {#if p.balance > 0}
          <span class="badge warn"><span class="ms">schedule</span><span>{tr('We owe', 'हामीले तिर्ने')}</span></span>
        {:else}
          <span class="badge good"><span class="ms">check</span><span>{tr('Paid', 'तिरेको')}</span></span>
        {/if}
      </div>
      <div class="kv" style="margin-top:10px">
        <div><span class="k">{tr('Bill date', 'बिल मिति')}</span><span class="v">{p.bill_date ? formatDate(p.bill_date) : tr('Not set', 'छैन')}</span></div>
        <div><span class="k">{tr('Bought on', 'खरिद मिति')}</span><span class="v">{formatDate(p.bought_at)}</span></div>
      </div>
    </section>

    <div class="section-title"><h3>{tr('Items', 'सामान')}</h3></div>
    <div class="list">
      {#each p.items ?? [] as line}
        <div class="row">
          <span class="icon-tile info"><span class="ms">inventory_2</span></span>
          <div class="row-main">
            <div class="row-title">{line.item_name}</div>
            <div class="row-sub">{num(line.quantity)} × {rs(line.unit_cost)}</div>
          </div>
          <span class="amount">{rs(line.line_total)}</span>
        </div>
      {/each}
    </div>

    <section class="card">
      <div class="kv">
        <div><span class="k">{tr('Lines total', 'सामानको जम्मा')}</span><span class="v">{rs(p.total - p.vat_amount)}</span></div>
        <div><span class="k">{tr('VAT', 'भ्याट')}</span><span class="v">{rs(p.vat_amount)}</span></div>
        <div class="total"><span class="k">{tr('Total', 'जम्मा')}</span><span class="v">{rs(p.total)}</span></div>
        <div><span class="k">{tr('Paid', 'तिरेको')}</span><span class="v good">{rs(p.paid)}</span></div>
        <div><span class="k">{tr('Balance', 'बाँकी')}</span><span class="v" class:warn={p.balance > 0}>{rs(p.balance)}</span></div>
      </div>
    </section>

    <div class="section-title"><h3>{tr('Payments', 'भुक्तानी')}</h3></div>
    {#if (p.payments ?? []).length === 0}
      <section class="card">
        <div class="empty" style="padding:14px 8px">
          <span class="ms" style="font-size:30px;color:var(--muted)">payments</span>
          <p>{tr('No payment yet', 'अहिलेसम्म कुनै भुक्तानी छैन')}</p>
        </div>
      </section>
    {:else}
      <div class="list">
        {#each p.payments ?? [] as pm (pm.id)}
          <div class="row">
            <span class="icon-tile good"><span class="ms">call_made</span></span>
            <div class="row-main">
              <div class="row-title">{rs(pm.amount)}</div>
              <div class="row-sub">{methodText(pm.method)} · {formatDate(pm.paid_at)}</div>
            </div>
          </div>
        {/each}
      </div>
    {/if}

    {#if p.balance > 0}
      <button class="btn btn-good btn-lg btn-block" type="button" onclick={openPay}><span class="ms">call_made</span><span>{tr('Pay supplier', 'डिलरलाई भुक्तानी')}</span></button>
    {/if}
    <a class="btn btn-tonal btn-block" href={`#/suppliers/${p.supplier_id}`}><span class="ms">storefront</span><span>{tr('Supplier ledger', 'डिलर खाता')}</span></a>
  {:else}
    <Skeleton card />
    <Skeleton rows={3} />
  {/if}
</div>

<Sheet bind:open={payOpen} title={tr('Pay supplier for this bill', 'यो बिलको भुक्तानी')}>
  <AmountPad bind:value={amountText} />
  <div class="seg block">
    {#each methods as m (m.key)}
      <button type="button" class:active={method === m.key} onclick={() => (method = m.key)}>
        <span class="ms">{m.icon}</span><span>{tr(m.en, m.ne)}</span>
      </button>
    {/each}
  </div>
  {#if pay.field('amount') || pay.message}
    <div class="alert bad"><span class="ms">error</span><div>{pay.field('amount') ?? pay.message}</div></div>
  {/if}
  <button class="btn btn-good btn-lg btn-block" type="button" disabled={pay.busy} onclick={sendPayment}>
    <span class="ms">check</span><span>{pay.busy ? tr('Saving…', 'सेभ हुँदैछ…') : tr('Save payment', 'सेभ गर्ने')}</span>
  </button>
</Sheet>
