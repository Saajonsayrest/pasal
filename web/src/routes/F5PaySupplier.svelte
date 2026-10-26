<script lang="ts">
  import { api, newKey } from '../lib/api'
  import { resource, action } from '../lib/resource.svelte'
  import { navigate } from '../lib/router.svelte'
  import { tr, num, plural } from '../lib/i18n'
  import { rs, toPaisa, fromPaisa } from '../lib/money'
  import { adOfStamp, daysUntil, formatDate } from '../lib/bs'
  import { setTitle } from '../lib/shell.svelte'
  import { toast } from '../lib/toast.svelte'
  import { initials } from '../lib/util'
  import type { Payment, SupplierLedger } from '../lib/types'
  import AmountPad from '../components/AmountPad.svelte'
  import Empty from '../components/Empty.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Skeleton from '../components/Skeleton.svelte'

  let { params }: { params: Record<string, string> } = $props()
  const supplierId = $derived(Number(params.id))

  type Bill = SupplierLedger['purchases'][number]

  const ledger = resource(() => api.get<SupplierLedger>(`/suppliers/${params.id}/ledger`))
  const d = $derived(ledger.data)

  $effect(() => {
    if (d) setTitle(d.supplier.name)
  })

  const time = (iso: string): number => Date.parse(iso.replace(/(\.\d{3})\d+/, '$1'))

  const bills = $derived.by<Bill[]>(() =>
    (d?.purchases ?? []).filter((p) => p.balance > 0).sort((a, b) => time(a.bought_at) - time(b.bought_at)),
  )

  const NE_ORDINAL = ['पहिलो', 'दोस्रो', 'तेस्रो', 'चौथो', 'पाँचौं', 'छैटौं', 'सातौं', 'आठौं', 'नवौं', 'दसौं']

  function ordinal(n: number): string {
    const tens = n % 100
    const suffix = tens >= 11 && tens <= 13 ? 'th' : ['th', 'st', 'nd', 'rd'][n % 10] ?? 'th'
    return tr(`${n}${suffix}`, NE_ORDINAL[n - 1] ?? num(n))
  }

  function ageText(iso: string): string {
    const days = Math.max(0, -daysUntil(adOfStamp(iso)))
    return tr(`${days} days ago`, `${num(days)} दिन अघि`)
  }

  const methods = [
    { key: 'cash', icon: 'payments', en: 'Cash', ne: 'नगद' },
    { key: 'bank', icon: 'account_balance', en: 'Bank', ne: 'बैंक' },
    { key: 'cheque', icon: 'receipt', en: 'Cheque', ne: 'चेक' },
  ]
  const quick = [1000000, 2000000]

  let amountText = $state('')
  let method = $state('cash')
  let seeded = false

  $effect(() => {
    if (!d || seeded) return
    seeded = true
    amountText = fromPaisa(d.we_owe)
  })

  const owed = $derived(d?.we_owe ?? 0)
  const amount = $derived(toPaisa(amountText) ?? 0)
  const tooMuch = $derived(amount > owed)

  const plan = $derived.by(() => {
    let left = amount
    const steps: { bill: Bill; take: number }[] = []
    for (const bill of bills) {
      if (left <= 0) break
      const take = Math.min(left, bill.balance)
      steps.push({ bill, take })
      left -= take
    }
    return steps
  })
  const applied = $derived(plan.reduce((sum, step) => sum + step.take, 0))
  const afterOwes = $derived(owed - applied)

  const save = action()
  let key = newKey()

  async function submit(): Promise<void> {
    if (!d || amount <= 0 || tooMuch) return
    const res = await save.run(() =>
      api.post<{ data: Payment[]; owes_left: number }>('/payments', { supplier_id: supplierId, amount, method }, key),
    )
    if (!res) return
    key = newKey()
    toast(`Payment saved. We owe ${rs(res.owes_left)}.`, `भुक्तानी सेभ भयो। हामीले ${rs(res.owes_left)} तिर्नुपर्छ।`)
    navigate(`/suppliers/${supplierId}`, true)
  }
</script>

<div class="page narrow">
  {#if ledger.error}
    <ErrorCard error={ledger.error} retry={ledger.reload} />
  {:else if d}
    <section class="hero soft">
      <div class="hstack between" style="align-items:flex-start">
        <div class="stat">
          <span class="stat-label">{tr(`We owe ${d.supplier.name}`, `${d.supplier.name} लाई हामीले तिर्ने`)}</span>
          <span class="stat-value xl">{rs(d.we_owe)}</span>
          <span class="stat-sub">{tr(`${num(bills.length)} open ${plural(bills.length, 'bill', 'bills')}`, `${num(bills.length)} खुला बिल`)}</span>
        </div>
        <span class="avatar info" style="width:52px;height:52px;font-size:18px">{initials(d.supplier.name)}</span>
      </div>
    </section>

    {#if bills.length === 0}
      <Empty icon="task_alt" title={tr('Nothing to pay', 'तिर्नुपर्ने बाँकी छैन')} text={tr('All bills with this supplier are paid.', 'यो डिलरका सबै बिल चुक्ता छन्।')} />
    {:else}
      <div class="section-title"><h3>{tr('Oldest bills are paid first', 'सबैभन्दा पुरानो बिल पहिले तिरिन्छ')}</h3></div>
      <div class="list">
        {#each bills as bill, i (bill.id)}
          <div class="row">
            <span class="icon-tile info"><span class="ms">receipt_long</span></span>
            <div class="row-main">
              <div class="row-title">{bill.bill_no ?? tr('No bill number', 'बिल नम्बर छैन')}</div>
              <div class="row-sub">{formatDate(bill.bought_at)} · {ageText(bill.bought_at)}</div>
            </div>
            <div class="row-end">
              <span class="amount">{rs(bill.balance)}</span>
              <span class="badge info">{ordinal(i + 1)}</span>
            </div>
          </div>
        {/each}
      </div>

      <div class="kv">
        <div class="total"><span class="k">{tr('Total we owe', 'जम्मा हामीले तिर्ने')}</span><span class="v">{rs(owed)}</span></div>
      </div>

      <div class="chips" style="justify-content:center">
        <button type="button" class="chip" class:active={amount === owed} onclick={() => (amountText = fromPaisa(owed))}>
          {tr(`Full ${rs(owed)}`, `पूरा ${rs(owed)}`)}
        </button>
        {#each quick as q (q)}
          <button type="button" class="chip" class:active={amount === q} disabled={q > owed} onclick={() => (amountText = fromPaisa(q))}>{rs(q)}</button>
        {/each}
      </div>

      <AmountPad bind:value={amountText} />

      <div class="seg block">
        {#each methods as m (m.key)}
          <button type="button" class:active={method === m.key} onclick={() => (method = m.key)}>
            <span class="ms">{m.icon}</span><span>{tr(m.en, m.ne)}</span>
          </button>
        {/each}
      </div>

      {#if plan.length > 0}
        <div class="card tonal" style="padding:12px 14px">
          <span class="small muted">{tr('The money will be used like this', 'पैसा यसरी मिलाइन्छ')}</span>
          <div class="kv" style="margin-top:4px">
            {#each plan as step (step.bill.id)}
              <div>
                <span class="k">{step.bill.bill_no ?? tr('No bill number', 'बिल नम्बर छैन')}</span>
                <span class="v">{tr(`${rs(step.take)} paid off`, `${rs(step.take)} चुक्ता`)}</span>
              </div>
            {/each}
            <div class="total"><span class="k">{tr('After this, we owe', 'त्यसपछि हामीले तिर्ने')}</span><span class="v">{rs(afterOwes)}</span></div>
          </div>
        </div>
      {/if}

      {#if tooMuch}
        <span class="field-error">
          <span class="ms" style="font-size:16px">error</span>
          <span>{tr(`The amount is more than we owe (${rs(owed)}).`, `रकम हामीले तिर्नुपर्ने ${rs(owed)} भन्दा बढी छ।`)}</span>
        </span>
      {/if}

      <p class="small muted center">{tr('The money pays the oldest bills first.', 'पैसा सबैभन्दा पुरानो बिलबाट मिलाइन्छ।')}</p>

      {#if save.message || save.field('amount')}
        <div class="alert bad"><span class="ms">error</span><div>{save.field('amount') ?? save.message}</div></div>
      {/if}

      <div class="bottom-bar">
        <button class="btn btn-good btn-lg btn-block" type="button" disabled={save.busy || amount <= 0 || tooMuch} onclick={submit}>
          <span class="ms">check</span><span>{save.busy ? tr('Saving…', 'सेभ हुँदैछ…') : tr('Save payment', 'सेभ गर्ने')}</span>
        </button>
      </div>
    {/if}
  {:else}
    <Skeleton card />
    <Skeleton rows={3} />
  {/if}
</div>
