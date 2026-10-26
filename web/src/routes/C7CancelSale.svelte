<script lang="ts">
  import { api, newKey } from '../lib/api'
  import { resource, action } from '../lib/resource.svelte'
  import { returnPreview, returnValue } from '../lib/cart.svelte'
  import { tr, num } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { navigate } from '../lib/router.svelte'
  import { toast } from '../lib/toast.svelte'
  import type { Sale, SaleReturn } from '../lib/types'
  import Field from '../components/Field.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Skeleton from '../components/Skeleton.svelte'

  let { params }: { params: Record<string, string> } = $props()

  const bill = resource(() => api.get<{ data: Sale }>(`/sales/${params.id}`))
  const sale = $derived(bill.data?.data)

  let reason = $state('')
  let reasonTouched = $state(false)
  let understood = $state(false)
  let restock = $state(true)
  const save = action()
  let key = newKey()
  let keyBody = ''

  const stillWith = $derived((sale?.items ?? []).reduce((sum, l) => sum + (l.quantity - l.returned_quantity), 0))
  const goodsValue = $derived(
    (sale?.items ?? []).reduce((sum, l) => sum + returnValue(l.quantity - l.returned_quantity, l.line_total, l.quantity), 0),
  )
  const cashBack = $derived(sale ? returnPreview(goodsValue, sale.balance).cashBack : 0)
  const reasonError = $derived(reasonTouched && !reason.trim() ? tr('Please write a reason.', 'कारण लेख्नुहोस्।') : save.field('note'))
  const blocked = $derived(!reason.trim() || !understood || save.busy || !!sale?.cancelled_at)

  async function cancelSale(): Promise<void> {
    if (!sale) return
    const body = { restock, note: reason.trim() }
    const text = JSON.stringify(body)
    if (text !== keyBody) {
      key = newKey()
      keyBody = text
    }
    const res = await save.run(() => api.post<{ data: SaleReturn; sale_balance: number; sale_cancelled: boolean }>(`/sales/${sale.id}/cancel`, body, key))
    if (!res) return
    key = newKey()
    keyBody = ''
    toast('Sale cancelled', 'बिक्री रद्द भयो')
    navigate(`/sales/${sale.id}`)
  }
</script>

<div class="page narrow">
  {#if bill.error}
    <ErrorCard error={bill.error} retry={bill.reload} />
  {:else if bill.loading && !bill.data}
    <Skeleton card />
  {:else if sale}
    <section class="hero" style="background:var(--bad)">
      <span class="ms fill" style="font-size:40px">warning</span>
      <h2 style="margin-top:10px">{tr(`Cancel bill ${sale.bill_no ?? `#${sale.id}`}?`, `बिल ${sale.bill_no ?? `#${sale.id}`} रद्द गर्ने?`)}</h2>
      <p style="margin-top:6px;opacity:.9">{tr('Here is what happens when you cancel:', 'रद्द गर्दा यी कुरा हुन्छन्:')}</p>
    </section>

    {#if sale.cancelled_at}
      <div class="alert bad"><span class="ms">cancel</span><div>{tr('This sale is already cancelled.', 'यो बिक्री पहिले नै रद्द भएको छ।')}</div></div>
    {/if}

    <div class="alert warn">
      <span class="ms">warning</span>
      <div>{tr('Every item still with the customer is returned in one step.', 'ग्राहकसँग भएका सबै सामान एकै पटक फिर्ता हुन्छन्।')}</div>
    </div>

    <section class="card">
      <div class="kv">
        <div><span class="k">{tr('Items coming back', 'फिर्ता आउने सामान')}</span><span class="v">{num(stillWith)}</span></div>
        <div><span class="k">{tr('Value of these items', 'यी सामानको मूल्य')}</span><span class="v">{rs(goodsValue)}</span></div>
        <div><span class="k">{tr('Cash to give back', 'नगद फिर्ता दिनु पर्ने')}</span><span class="v">{rs(cashBack)}</span></div>
      </div>
    </section>

    <Field label={tr('Reason (required)', 'कारण (अनिवार्य)')} error={reasonError}>
      <input placeholder={tr('Why cancel this bill?', 'किन यो बिल रद्द गर्दै हुनुहुन्छ?')} bind:value={reason} onblur={() => (reasonTouched = true)} />
    </Field>

    <section class="card hstack between">
      <span>{tr('Put returned items back in stock', 'फिर्ता सामान स्टकमा राख्ने')}</span>
      <label class="switch"><input type="checkbox" bind:checked={restock} /><span></span></label>
    </section>

    <section class="card hstack between">
      <span>{tr('I understand. This cannot be undone.', 'मैले बुझें। यो फिर्ता हुँदैन।')}</span>
      <label class="switch"><input type="checkbox" bind:checked={understood} /><span></span></label>
    </section>

    {#if save.error}
      <div class="alert bad"><span class="ms">error</span><div>{save.error.message}</div></div>
    {/if}
  {/if}
</div>

{#if sale}
  <div class="bottom-bar">
    <a class="btn btn-outline btn-lg" href={`#/sales/${sale.id}`} style="flex:1"><span>{tr('Keep sale', 'बिक्री राख्ने')}</span></a>
    <button class="btn btn-danger btn-lg" style="flex:1.4" disabled={blocked} onclick={cancelSale}>
      <span class="ms">cancel</span><span>{save.busy ? tr('Cancelling…', 'रद्द हुँदैछ…') : tr('Cancel sale', 'बिक्री रद्द गर्ने')}</span>
    </button>
  </div>
{/if}
