<script lang="ts">
  import { api } from '../lib/api'
  import { resource } from '../lib/resource.svelte'
  import { tr, num } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { formatDate, formatDateSub, formatTime } from '../lib/bs'
  import { session } from '../lib/session.svelte'
  import { toast } from '../lib/toast.svelte'
  import { whatsappHref } from '../lib/util'
  import type { Sale } from '../lib/types'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'

  let { params }: { params: Record<string, string> } = $props()

  const bill = resource(() => api.get<{ data: Sale }>(`/sales/${params.id}`))
  const sale = $derived(bill.data?.data)

  function savedFooter(): string {
    try {
      return localStorage.getItem('pasal-bill-footer')?.trim() ?? ''
    } catch {
      return ''
    }
  }

  const footer = $derived(savedFooter() || tr('Thank you. Visit again.', 'धन्यवाद। फेरि आउनुहोस्।'))

  const billText = $derived.by(() => {
    if (!sale) return ''
    const lines = [
      session.business?.name ?? 'PASAL',
      `${tr('Bill', 'बिल')} ${sale.bill_no ?? `#${sale.id}`} · ${formatDate(sale.sold_at)}`,
      `${tr('Total', 'जम्मा')}: ${rs(sale.total)}`,
      `${tr('Paid', 'तिरेको')}: ${rs(sale.paid)}`,
    ]
    if (sale.balance > 0) lines.push(`${tr('Balance', 'बाँकी')}: ${rs(sale.balance)}`)
    lines.push(footer)
    return lines.join('\n')
  })

  async function copyText(): Promise<void> {
    try {
      await navigator.clipboard.writeText(billText)
      toast('Bill text copied', 'बिलको पाठ कपी भयो')
    } catch {
      toast('Could not copy. Try again.', 'कपी गर्न सकिएन। फेरि प्रयास गर्नुहोस्।')
    }
  }
</script>

<div class="page narrow">
  {#if bill.error}
    <ErrorCard error={bill.error} retry={bill.reload} />
  {:else if bill.loading && !bill.data}
    <Skeleton card />
  {:else if sale}
    <section class="card" style="padding:22px 18px">
      <div class="stack" style="align-items:center;text-align:center;gap:4px">
        <span class="avatar" style="width:54px;height:54px;font-size:20px">प</span>
        <h2 style="margin-top:6px">{session.business?.name ?? 'PASAL'}</h2>
        {#if session.business?.address}<span class="small muted">{session.business.address}</span>{/if}
        {#if session.business?.phone}<span class="small muted">{tr('Phone', 'फोन')} {session.business.phone}</span>{/if}
        {#if session.business?.pan}<span class="small bold">{tr('PAN', 'PAN नं.')} {session.business.pan}</span>{/if}
      </div>

      <div class="divider" style="margin:16px 0"></div>
      <h3 class="center">{tr('VAT bill', 'भ्याट बिल')}</h3>

      <div class="kv" style="margin-top:8px">
        <div><span class="k">{tr('Bill no.', 'बिल नं.')}</span><span class="v">{sale.bill_no ?? `#${sale.id}`}</span></div>
        <div><span class="k">{tr('Date', 'मिति')}</span><span class="v">{formatDate(sale.sold_at)} <span class="tiny muted">{formatDateSub(sale.sold_at)}</span></span></div>
        <div><span class="k">{tr('Time', 'समय')}</span><span class="v">{formatTime(sale.sold_at)}</span></div>
        <div><span class="k">{tr('Customer', 'ग्राहक')}</span><span class="v">{sale.customer?.name ?? tr('Walk-in customer', 'पसलमा आएका ग्राहक')}</span></div>
        {#if sale.customer?.pan}<div><span class="k">{tr('Customer PAN', 'ग्राहकको PAN')}</span><span class="v">{sale.customer.pan}</span></div>{/if}
      </div>

      <div class="table-wrap" style="margin-top:14px;box-shadow:none;border:0">
        <table class="table">
          <thead>
            <tr><th>{tr('Item', 'सामान')}</th><th class="r">{tr('Qty', 'संख्या')}</th><th class="r">{tr('Amount', 'रकम')}</th></tr>
          </thead>
          <tbody>
            {#each sale.items ?? [] as line (line.id)}
              <tr>
                <td>{line.item_name}</td>
                <td class="r">{num(line.quantity)}</td>
                <td class="r">{rs(line.line_total)}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>

      <div class="kv" style="margin-top:12px">
        <div><span class="k">{tr('Subtotal', 'उप-जम्मा')}</span><span class="v">{rs(sale.subtotal)}</span></div>
        <div><span class="k">{tr('Discount', 'छुट')}</span><span class="v">{rs(sale.discount)}</span></div>
        <div><span class="k">{tr('Taxable amount', 'करयोग्य रकम')}</span><span class="v">{rs(sale.taxable_amount, { paisa: true })}</span></div>
        <div><span class="k">{tr('VAT', 'भ्याट')} {num(sale.vat_rate)}%</span><span class="v">{rs(sale.vat_amount, { paisa: true })}</span></div>
        {#if sale.exempt_amount > 0}<div><span class="k">{tr('No VAT items', 'भ्याट नलाग्ने सामान')}</span><span class="v">{rs(sale.exempt_amount)}</span></div>{/if}
        <div class="total"><span class="k">{tr('Total', 'जम्मा')}</span><span class="v">{rs(sale.total)}</span></div>
        {#if sale.returned_total > 0}<div><span class="k">{tr('Returned', 'फिर्ता')}</span><span class="v">{rs(sale.returned_total)}</span></div>{/if}
        <div><span class="k">{tr('Paid', 'तिरेको')}</span><span class="v">{rs(sale.paid)}</span></div>
        <div><span class="k">{tr('Balance', 'बाँकी')}</span><span class="v">{rs(sale.balance)}</span></div>
      </div>

      <div class="divider" style="margin:16px 0"></div>
      <p class="bold center">{footer}</p>
    </section>

    {#if sale.cancelled_at}
      <div class="alert bad no-print"><span class="ms">cancel</span><div>{tr('This bill is cancelled.', 'यो बिल रद्द भएको छ।')}</div></div>
    {/if}

    <div class="quick-actions no-print">
      <button onclick={() => window.print()}><span class="qa-icon"><span class="ms">print</span></span><span>{tr('Print', 'प्रिन्ट')}</span></button>
      {#if sale.customer?.phone}
        <a href={whatsappHref(sale.customer.phone, billText)} target="_blank" rel="noopener"><span class="qa-icon"><span class="ms">chat</span></span><span>{tr('WhatsApp', 'व्हाट्सएप')}</span></a>
      {/if}
      <button onclick={copyText}><span class="qa-icon"><span class="ms">content_copy</span></span><span>{tr('Copy text', 'पाठ कपी')}</span></button>
    </div>

    <a class="btn btn-primary btn-lg btn-block no-print" href="#/sell"><span class="ms">add_shopping_cart</span><span>{tr('New sale', 'नयाँ बिक्री')}</span></a>
  {/if}
</div>
