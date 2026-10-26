<script lang="ts">
  import { api, newKey } from '../lib/api'
  import { resource, action } from '../lib/resource.svelte'
  import { returnPreview, returnValue } from '../lib/cart.svelte'
  import { tr, num } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { navigate } from '../lib/router.svelte'
  import { toast } from '../lib/toast.svelte'
  import type { Sale, SaleLine, SaleReturn } from '../lib/types'
  import Field from '../components/Field.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Skeleton from '../components/Skeleton.svelte'

  let { params }: { params: Record<string, string> } = $props()

  type ReturnResult = { data: SaleReturn; sale_balance: number; sale_cancelled: boolean }

  const bill = resource(() => api.get<{ data: Sale }>(`/sales/${params.id}`))
  const sale = $derived(bill.data?.data)
  const lines = $derived(sale?.items ?? [])

  const REASONS: [string, string][] = [
    ['Damaged', 'बिग्रिएको'],
    ['Wrong item', 'गलत सामान'],
    ['Customer changed mind', 'ग्राहकले मन बदले'],
    ['Expired', 'म्याद सकियो'],
  ]

  let picked = $state<Record<number, number>>({})
  let restock = $state(true)
  let note = $state('')
  const save = action()
  let key = newKey()
  let keyBody = ''

  function returnable(line: SaleLine): number {
    return line.quantity - line.returned_quantity
  }

  function qtyOf(line: SaleLine): number {
    return Math.min(picked[line.id] ?? 0, returnable(line))
  }

  function setQty(line: SaleLine, qty: number): void {
    picked[line.id] = Math.max(0, Math.min(returnable(line), qty))
  }

  const count = $derived(lines.reduce((sum, l) => sum + qtyOf(l), 0))
  const value = $derived(lines.reduce((sum, l) => sum + returnValue(qtyOf(l), l.line_total, l.quantity), 0))
  const split = $derived(sale ? returnPreview(value, sale.balance) : null)
  const blocked = $derived(count === 0 || save.busy || !!sale?.cancelled_at)

  async function saveReturn(): Promise<void> {
    if (!sale) return
    const body = {
      items: lines.filter((l) => qtyOf(l) > 0).map((l) => ({ sale_item_id: l.id, quantity: qtyOf(l) })),
      restock,
      ...(note.trim() ? { note: note.trim() } : {}),
    }
    const text = JSON.stringify(body)
    if (text !== keyBody) {
      key = newKey()
      keyBody = text
    }
    const res = await save.run(() => api.post<ReturnResult>(`/sales/${sale.id}/returns`, body, key))
    if (!res) return
    key = newKey()
    keyBody = ''
    toast(
      `Return saved. Refunded ${rs(res.data.refunded)}. Balance ${rs(res.sale_balance)}.`,
      `फिर्ता सेभ भयो। ${rs(res.data.refunded)} फिर्ता। बाँकी ${rs(res.sale_balance)}।`,
    )
    navigate(`/sales/${sale.id}`)
  }
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
          <h2>{sale.customer?.name ?? tr('Walk-in customer', 'पसलमा आएका ग्राहक')}</h2>
        </div>
        {#if sale.balance > 0}
          <span class="badge warn"><span class="ms">schedule</span><span>{tr('Credit', 'उधारो')}</span></span>
        {:else}
          <span class="badge good"><span class="ms">check_circle</span><span>{tr('Paid', 'तिरेको')}</span></span>
        {/if}
      </div>
    </section>

    {#if sale.cancelled_at}
      <div class="alert bad"><span class="ms">cancel</span><div>{tr('This sale is cancelled. Nothing is left to return.', 'यो बिक्री रद्द भएको छ। फिर्ता गर्ने सामान छैन।')}</div></div>
    {/if}

    <div class="section-title"><h3>{tr('Items to return', 'फिर्ता दिने सामान')}</h3></div>
    <div class="list">
      {#each lines as line (line.id)}
        {@const max = returnable(line)}
        {@const qty = qtyOf(line)}
        <div class="row">
          <span class="icon-tile"><span class="ms">inventory_2</span></span>
          <div class="row-main">
            <div class="row-title">{line.item_name}</div>
            <div class="row-sub">
              {#if max > 0}
                {tr('Sold', 'बिक्री')} {num(line.quantity)} · {rs(line.unit_price)}
              {:else}
                {tr('Already returned', 'पहिले नै फिर्ता भयो')}
              {/if}
            </div>
          </div>
          <div class="stepper">
            <button aria-label={tr('Less', 'कम')} disabled={qty <= 0} onclick={() => setQty(line, qty - 1)}><span class="ms">remove</span></button>
            <span class="val">{num(qty)}</span>
            <button aria-label={tr('More', 'थप')} disabled={qty >= max} onclick={() => setQty(line, qty + 1)}><span class="ms">add</span></button>
          </div>
        </div>
      {/each}
    </div>

    <div class="section-title"><h3>{tr('Reason', 'कारण')}</h3></div>
    <div class="chips wrap">
      {#each REASONS as [en, ne]}
        <button class="chip" class:active={note === en} onclick={() => (note = en)}>{tr(en, ne)}</button>
      {/each}
    </div>

    <Field label={tr('Note (optional)', 'नोट (ऐच्छिक)')} error={save.field('note')}>
      <input bind:value={note} />
    </Field>

    <section class="card hstack between">
      <span>{tr('Put returned items back in stock', 'फिर्ता सामान स्टकमा राख्ने')}</span>
      <label class="switch"><input type="checkbox" bind:checked={restock} /><span></span></label>
    </section>

    <section class="card">
      <div class="kv">
        <div><span class="k">{tr('Items returned', 'फिर्ता सामान')}</span><span class="v">{num(count)}</span></div>
        <div class="total"><span class="k">{tr('Refund value', 'फिर्ता रकम')}</span><span class="v">{rs(value)}</span></div>
        <div><span class="k">{tr('Debt taken off', 'उधारोबाट घटाइने')}</span><span class="v">{rs(split?.debtDown ?? 0)}</span></div>
        <div><span class="k">{tr('Cash to give back', 'नगद फिर्ता दिनु पर्ने')}</span><span class="v" class:warn={(split?.cashBack ?? 0) > 0}>{rs(split?.cashBack ?? 0)}</span></div>
        <div><span class="k">{tr('Credit left after return', 'फिर्ता पछिको उधारो')}</span><span class="v">{rs(split?.balanceAfter ?? 0)}</span></div>
      </div>
    </section>

    <div class="alert">
      <span class="ms">{restock ? 'inventory_2' : 'block'}</span>
      <div>{restock ? tr('Stock goes back up for returned items', 'फिर्ता सामानको स्टक फेरि बढ्छ') : tr('Returned items will not go back on the shelf', 'फिर्ता सामान स्टकमा फर्किने छैन')}</div>
    </div>

    {#if save.error}
      <div class="alert bad"><span class="ms">error</span><div>{save.error.message}</div></div>
    {/if}
  {/if}
</div>

{#if sale}
  <div class="bottom-bar">
    <a class="btn btn-outline btn-lg" href={`#/sales/${sale.id}`} style="flex:1"><span>{tr('Back', 'फर्कनुहोस्')}</span></a>
    <button class="btn btn-primary btn-lg" style="flex:1.4" disabled={blocked} onclick={saveReturn}>
      <span class="ms">check</span><span>{save.busy ? tr('Saving…', 'सेभ हुँदैछ…') : tr('Save return', 'फिर्ता सेभ गर्ने')}</span>
    </button>
  </div>
{/if}
