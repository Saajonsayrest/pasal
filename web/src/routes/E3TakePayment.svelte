<script lang="ts">
  import { api, newKey } from '../lib/api'
  import { action, resource } from '../lib/resource.svelte'
  import { tr, num, plural } from '../lib/i18n'
  import { rs, toPaisa, fromPaisa, percentOf } from '../lib/money'
  import { daysUntil, adOfStamp, formatDate } from '../lib/bs'
  import { navigate } from '../lib/router.svelte'
  import { toast } from '../lib/toast.svelte'
  import { allocateOldestFirst } from '../lib/allocation'
  import { initials } from '../lib/util'
  import type { CustomerLedger, Payment } from '../lib/types'
  import AmountPad from '../components/AmountPad.svelte'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'

  let { params }: { params: Record<string, string> } = $props()

  const METHODS = [
    { key: 'cash', icon: 'payments', en: 'Cash', ne: 'नगद' },
    { key: 'qr', icon: 'qr_code_2', en: 'QR', ne: 'QR' },
    { key: 'bank', icon: 'account_balance', en: 'Bank', ne: 'बैंक' },
    { key: 'esewa', icon: 'account_balance_wallet', en: 'eSewa', ne: 'eSewa' },
    { key: 'khalti', icon: 'account_balance_wallet', en: 'Khalti', ne: 'Khalti' },
  ]

  const NE_ORDER = ['पहिलो', 'दोस्रो', 'तेस्रो', 'चौथो', 'पाँचौं', 'छैटौं', 'सातौं', 'आठौं', 'नवौं', 'दसौं']

  function orderLabel(index: number): string {
    const n = index + 1
    if (n > NE_ORDER.length) return tr(`${n}th`, `${num(n)}औं`)
    const en = n === 1 ? '1st' : n === 2 ? '2nd' : n === 3 ? '3rd' : `${n}th`
    return tr(en, NE_ORDER[index])
  }

  const ledger = resource(() => api.get<CustomerLedger>(`/customers/${params.id}/ledger`))
  const data = $derived(ledger.data)
  const name = $derived(data?.customer.name ?? '')
  const owes = $derived(data?.owes ?? 0)
  const half = $derived(percentOf(owes, 50))

  const open = $derived(
    (data?.sales ?? [])
      .filter((s) => s.balance > 0 && s.cancelled_at === null)
      .sort((a, b) => Date.parse(a.sold_at) - Date.parse(b.sold_at)),
  )

  let typed = $state<string | null>(null)
  const raw = $derived(typed ?? fromPaisa(owes))
  const paisa = $derived(toPaisa(raw))
  const tooMuch = $derived(paisa !== null && paisa > owes)
  const amountError = $derived.by(() => {
    if (paisa === null || paisa === 0) return tr('Type an amount more than zero.', 'शून्यभन्दा बढी रकम लेख्नुहोस्।')
    if (tooMuch) return tr(`The amount is more than ${name} owes (${rs(owes)}).`, `रकम ${name}ले दिनुपर्ने ${rs(owes)} भन्दा बढी छ।`)
    return null
  })

  const plan = $derived(paisa !== null && paisa > 0 && !tooMuch ? allocateOldestFirst(open, paisa) : null)

  const chips = $derived([
    { label: `${tr('Full', 'पूरा')} ${rs(owes)}`, value: owes },
    { label: `${tr('Half', 'आधा')} ${rs(half)}`, value: half },
    { label: rs(100000), value: 100000 },
  ])

  let method = $state('cash')

  const save = action()
  let key = newKey()
  let keyBody = ''

  async function submit(e: Event) {
    e.preventDefault()
    if (paisa === null || paisa <= 0 || tooMuch) return
    const body = { customer_id: Number(params.id), amount: paisa, method }
    const json = JSON.stringify(body)
    if (json !== keyBody) {
      key = newKey()
      keyBody = json
    }
    const res = await save.run(() => api.post<{ data: Payment[]; owes_left: number }>('/payments', body, key))
    if (res) {
      key = newKey()
      keyBody = ''
      toast(`Payment saved. ${name} now owes ${rs(res.owes_left)}.`, `भुक्तानी सेभ भयो। अब ${name}को बाँकी ${rs(res.owes_left)}।`)
      navigate(`/customers/${params.id}`)
    }
  }
</script>

<form class="page narrow" onsubmit={submit}>
  {#if ledger.error}
    <ErrorCard error={ledger.error} retry={ledger.reload} />
  {:else if ledger.loading && !data}
    <Skeleton card />
    <Skeleton rows={3} />
  {:else if data}
    <section class="hero warn">
      <div class="hstack between" style="align-items:flex-start">
        <div class="stat">
          <span class="stat-label">{tr(`To collect from ${name}`, `${name}बाट उठाउन बाँकी`)}</span>
          <span class="stat-value xl warn">{rs(owes)}</span>
          <span class="stat-sub">
            {tr(`${open.length} open ${plural(open.length, 'bill', 'bills')}`, `${num(open.length)} खुला बिल`)}
          </span>
        </div>
        <span class="avatar warn" style="width:52px;height:52px;font-size:18px">{initials(name)}</span>
      </div>
    </section>

    <div class="section-title"><h3>{tr('Oldest bills are paid first', 'सबैभन्दा पुरानो बिल पहिले तिरिन्छ')}</h3></div>

    {#if open.length === 0}
      <p class="muted center">{tr('No open bills. Nothing to take.', 'खुला बिल छैन। लिने रकम छैन।')}</p>
    {:else}
      <div class="list">
        {#each open as bill, i (bill.id)}
          {@const days = Math.max(0, -daysUntil(adOfStamp(bill.sold_at)))}
          <div class="row">
            <span class="icon-tile warn"><span class="ms">receipt_long</span></span>
            <div class="row-main">
              <div class="row-title">{bill.bill_no ?? `#${bill.id}`}</div>
              <div class="row-sub">
                {formatDate(bill.sold_at)} · {days === 0 ? tr('Today', 'आज') : tr(`${num(days)} days ago`, `${num(days)} दिन अघि`)}
              </div>
            </div>
            <div class="row-end">
              <span class="amount">{rs(bill.balance)}</span>
              <span class="badge warn">{orderLabel(i)}</span>
            </div>
          </div>
        {/each}
      </div>
    {/if}

    <div class="kv">
      <div class="total"><span class="k">{tr('Total owed', 'जम्मा बाँकी')}</span><span class="v">{rs(owes)}</span></div>
    </div>

    <AmountPad bind:value={() => raw, (v) => (typed = v)} />

    <div class="chips" style="justify-content:center">
      {#each chips as chip}
        <button type="button" class="chip" class:active={paisa === chip.value} onclick={() => (typed = fromPaisa(chip.value))}>{chip.label}</button>
      {/each}
    </div>

    <div class="seg block">
      {#each METHODS as m}
        <button type="button" class:active={method === m.key} onclick={() => (method = m.key)}>
          <span class="ms">{m.icon}</span><span>{tr(m.en, m.ne)}</span>
        </button>
      {/each}
    </div>

    {#if amountError}
      <div class="alert bad"><span class="ms">error</span><div>{amountError}</div></div>
    {:else if plan}
      <div class="card tonal" style="padding:12px 14px">
        <span class="small muted">{tr('The money will be used like this', 'पैसा यसरी मिलाइन्छ')}</span>
        <div class="kv" style="margin-top:4px">
          {#each plan.allocations as a}
            <div>
              <span class="k">{a.bill.bill_no ?? `#${a.bill.id}`}</span>
              <span class="v">
                {a.paidOff
                  ? tr(`${rs(a.pays)} paid off`, `${rs(a.pays)} चुक्ता`)
                  : tr(`${rs(a.pays)} paid, ${rs(a.bill.balance - a.pays)} left`, `${rs(a.pays)} तिरियो, ${rs(a.bill.balance - a.pays)} बाँकी`)}
              </span>
            </div>
          {/each}
          <div class="total">
            <span class="k">{tr(`After this, ${name} owes`, `त्यसपछि ${name}को बाँकी`)}</span>
            <span class="v">{rs(owes - (paisa ?? 0))}</span>
          </div>
        </div>
      </div>
    {/if}

    <p class="small muted center">{tr('The money pays the oldest bills first.', 'पैसा सबैभन्दा पुरानो बिलबाट मिलाइन्छ।')}</p>

    {#if save.field('amount')}
      <div class="alert bad"><span class="ms">error</span><div>{save.field('amount')}</div></div>
    {/if}
    {#if save.message}
      <div class="alert bad"><span class="ms">error</span><div>{save.message}</div></div>
    {/if}

    <div class="bottom-bar">
      <button class="btn btn-good btn-lg btn-block" type="submit" disabled={save.busy || amountError !== null || open.length === 0}>
        <span class="ms">check</span><span>{save.busy ? tr('Saving…', 'सेभ हुँदैछ…') : tr('Save payment', 'भुक्तानी सेभ गर्ने')}</span>
      </button>
    </div>
  {/if}
</form>
