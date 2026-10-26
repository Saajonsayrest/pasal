<script lang="ts">
  import { api } from '../lib/api'
  import { resource, action } from '../lib/resource.svelte'
  import { tr, num } from '../lib/i18n'
  import { rs, toPaisa, fromPaisa } from '../lib/money'
  import { formatDate } from '../lib/bs'
  import { navigate } from '../lib/router.svelte'
  import { toast } from '../lib/toast.svelte'
  import type { VatFiling } from '../lib/types'
  import { FILING_STATUS, dueDate, dueInDays, errorText, filingStatus, periodTitle } from '../lib/vat'
  import BsDatePicker from '../components/BsDatePicker.svelte'
  import Field from '../components/Field.svelte'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'

  let { params }: { params: Record<string, string> } = $props()

  const filing = resource(() => api.get<{ data: VatFiling }>(`/vat/filings/${params.id}`))
  const f = $derived(filing.data?.data)
  const status = $derived(f ? filingStatus(f) : 'not_filed')
  const heroClass = $derived(status === 'not_filed' ? 'warn' : status === 'paid' ? 'good' : 'soft')

  let filedOn = $state('')
  let paidOn = $state('')
  let paidText = $state('0')
  let receiptNo = $state('')
  let note = $state('')
  let filled = false

  $effect(() => {
    const v = f
    if (!v || filled) return
    filled = true
    filedOn = v.filed_on ?? ''
    paidOn = v.paid_on ?? ''
    paidText = fromPaisa(v.paid_amount)
    receiptNo = v.receipt_no ?? ''
    note = v.note ?? ''
  })

  const paid = $derived(toPaisa(paidText))
  const remaining = $derived(f && paid !== null ? f.payable - paid : null)
  const paidError = $derived(paid === null ? tr('Enter an amount, for example 500', 'रकम लेख्नुहोस्, जस्तै 500') : null)

  function dueText(days: number): string {
    if (days < 0) return tr(`${num(-days)} days past due`, `${num(-days)} दिन नाघेको`)
    return tr(`${num(days)} days left`, `${num(days)} दिन बाँकी`)
  }

  const save = action()
  const SHOWN = ['paid_amount', 'receipt_no', 'note']

  async function saveMarks(): Promise<void> {
    if (paid === null) return
    const res = await save.run(() =>
      api.patch<{ data: VatFiling }>(`/vat/filings/${params.id}`, {
        filed_on: filedOn || null,
        paid_amount: paid,
        paid_on: paidOn || null,
        receipt_no: receiptNo.trim() || null,
        note: note.trim() || null,
      }),
    )
    if (!res) return
    toast('Filing saved', 'फाइलिङ सेभ भयो')
    navigate('/vat/filings')
  }
</script>

<div class="page narrow">
  {#if filing.error}
    <ErrorCard error={filing.error} retry={filing.reload} />
  {:else if filing.loading && !filing.data}
    <Skeleton card />
  {:else if f}
    <section class="hero {heroClass}">
      <div class="stat">
        <span class="stat-label">{periodTitle(f.period)} · {tr(FILING_STATUS[status].en, FILING_STATUS[status].ne)}</span>
        <span class="stat-value lg">{rs(f.payable, { paisa: true })}</span>
        <span class="stat-sub">{tr('Due', 'तिर्ने अन्तिम मिति')} {formatDate(dueDate(f.period_to))} · {dueText(dueInDays(f.period_to))}</span>
      </div>
    </section>

    <section class="card">
      <div class="card-head">
        <h3>{tr('Frozen numbers', 'जमेका अंक')}</h3>
        {#if f.source === 'manual'}
          <span class="badge info"><span class="ms">edit_note</span><span>{tr('Typed in', 'हातले भरेको')}</span></span>
        {:else}
          <span class="badge primary"><span class="ms">calculate</span><span>{tr('Computed', 'हिसाबबाट बनेको')}</span></span>
        {/if}
      </div>
      <p class="small muted hstack" style="margin-bottom:6px"><span class="ms">lock</span><span>{tr('These numbers are frozen. They cannot be edited.', 'यी अंक जमेका छन्। यी सच्याउन मिल्दैन।')}</span></p>
      <div class="kv">
        <div><span class="k">{tr('Period', 'अवधि')}</span><span class="v">{f.period}</span></div>
        <div><span class="k">{tr('From', 'देखि')}</span><span class="v">{formatDate(f.period_from)}</span></div>
        <div><span class="k">{tr('To', 'सम्म')}</span><span class="v">{formatDate(f.period_to)}</span></div>
        <div><span class="k">{tr('Sales taxable', 'करयोग्य बिक्री')}</span><span class="v">{rs(f.sales_taxable, { paisa: true })}</span></div>
        <div><span class="k">{tr('Sales exempt', 'करमुक्त बिक्री')}</span><span class="v">{rs(f.sales_exempt, { paisa: true })}</span></div>
        <div><span class="k">{tr('Output VAT', 'बिक्रीमा भ्याट')}</span><span class="v">{rs(f.output_vat, { paisa: true })}</span></div>
        <div><span class="k">{tr('Purchases taxable', 'करयोग्य खरिद')}</span><span class="v">{rs(f.purchases_taxable, { paisa: true })}</span></div>
        <div><span class="k">{tr('Input VAT', 'खरिदमा भ्याट')}</span><span class="v">{rs(f.input_vat, { paisa: true })}</span></div>
        <div><span class="k">{tr('Carry in', 'अघिल्लो बाँकी')}</span><span class="v">{rs(f.carry_in, { paisa: true })}</span></div>
        <div class="total"><span class="k">{tr('Payable', 'तिर्नुपर्ने')}</span><span class="v">{rs(f.payable, { paisa: true })}</span></div>
        <div><span class="k">{tr('Carry out', 'अर्को महिनामा सर्ने')}</span><span class="v">{rs(f.carry_out, { paisa: true })}</span></div>
      </div>
    </section>

    <section class="card">
      <div class="card-head"><h3>{tr('Your entries', 'आफूले भरेको विवरण')}</h3></div>
      <div class="kv" style="margin-bottom:8px">
        <div class="total"><span class="k">{tr('Remaining to pay', 'अझै तिर्नुपर्ने')}</span><span class="v">{remaining === null ? '' : rs(remaining, { paisa: true })}</span></div>
      </div>
      <div class="form-grid two">
        <BsDatePicker bind:value={filedOn} label={tr('Filed on', 'फाइल गरेको मिति')} />
        <BsDatePicker bind:value={paidOn} label={tr('Paid on', 'तिरेको मिति')} />
        <Field label={tr('Paid amount', 'तिरेको रकम')} error={save.field('paid_amount') ?? paidError}>
          <div class="input-group">
            <span class="prefix">Rs</span>
            <input inputmode="decimal" placeholder="0" bind:value={paidText} />
          </div>
        </Field>
        <Field label={tr('Receipt number', 'रसिद नम्बर')} error={save.field('receipt_no')}>
          <input placeholder={tr('R-', 'आर-')} bind:value={receiptNo} />
        </Field>
        <Field label={tr('Note', 'टिप्पणी')} error={save.field('note')} full>
          <textarea placeholder={tr('For example: paid at the bank', 'जस्तै: बैंकमा तिरियो')} bind:value={note}></textarea>
        </Field>
      </div>
    </section>

    {#if save.error}
      <div class="alert bad"><span class="ms">error</span><div>{errorText(save.error, SHOWN)}</div></div>
    {/if}

    <div class="bottom-bar">
      <button class="btn btn-primary btn-lg btn-block" onclick={saveMarks} disabled={save.busy || paid === null}>
        <span class="ms">check</span><span>{save.busy ? tr('Saving…', 'सेभ हुँदैछ…') : tr('Save', 'सेभ गर्ने')}</span>
      </button>
    </div>
  {/if}
</div>
