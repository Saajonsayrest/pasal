<script lang="ts">
  import { api, newKey } from '../lib/api'
  import { action } from '../lib/resource.svelte'
  import { tr, digits } from '../lib/i18n'
  import { toPaisa } from '../lib/money'
  import { bsMonthRange, formatDate, monthName, periodLabel, shiftMonth, todayBs } from '../lib/bs'
  import { navigate } from '../lib/router.svelte'
  import { toast } from '../lib/toast.svelte'
  import type { VatFiling } from '../lib/types'
  import { errorText } from '../lib/vat'
  import BsDatePicker from '../components/BsDatePicker.svelte'
  import Field from '../components/Field.svelte'

  const YEARS = Array.from({ length: 13 }, (_, i) => 2078 + i)
  const MONTHS = Array.from({ length: 12 }, (_, i) => i + 1)

  const previous = shiftMonth(todayBs().year, todayBs().month, -1)
  let year = $state(previous.year)
  let month = $state(previous.month)
  const range = $derived(bsMonthRange(year, month))
  const period = $derived(periodLabel(year, month))

  type AmountKey = 'sales_taxable' | 'sales_exempt' | 'output_vat' | 'purchases_taxable' | 'input_vat' | 'carry_in' | 'payable' | 'carry_out'
  const AMOUNTS: { key: AmountKey; en: string; ne: string }[] = [
    { key: 'sales_taxable', en: 'Sales taxable', ne: 'करयोग्य बिक्री' },
    { key: 'sales_exempt', en: 'Sales exempt', ne: 'करमुक्त बिक्री' },
    { key: 'output_vat', en: 'Output VAT', ne: 'बिक्रीमा भ्याट' },
    { key: 'purchases_taxable', en: 'Purchases taxable', ne: 'करयोग्य खरिद' },
    { key: 'input_vat', en: 'Input VAT', ne: 'खरिदमा भ्याट' },
    { key: 'carry_in', en: 'Carry in', ne: 'अघिल्लो बाँकी' },
    { key: 'payable', en: 'Payable', ne: 'तिर्नुपर्ने' },
    { key: 'carry_out', en: 'Carry out', ne: 'अर्को महिनामा सर्ने' },
  ]
  let amounts = $state<Record<AmountKey, string>>({
    sales_taxable: '0',
    sales_exempt: '0',
    output_vat: '0',
    purchases_taxable: '0',
    input_vat: '0',
    carry_in: '0',
    payable: '0',
    carry_out: '0',
  })
  let paidText = $state('0')
  let filedOn = $state('')
  let receiptNo = $state('')

  const amountsValid = $derived(AMOUNTS.every((a) => toPaisa(amounts[a.key]) !== null) && toPaisa(paidText) !== null)

  function amountError(text: string): string | null {
    return toPaisa(text) === null ? tr('Enter an amount, for example 1250.50', 'रकम लेख्नुहोस्, जस्तै 1250.50') : null
  }

  const INLINE = ['period', 'from', 'to', 'paid_amount', 'receipt_no', ...AMOUNTS.map((a) => a.key)]

  const save = action()
  let key = newKey()

  function paise(text: string): number {
    return toPaisa(text) ?? 0
  }

  async function saveReturn(): Promise<void> {
    if (!amountsValid) return
    const body = {
      manual: true,
      period,
      from: range.from,
      to: range.to,
      sales_taxable: paise(amounts.sales_taxable),
      sales_exempt: paise(amounts.sales_exempt),
      output_vat: paise(amounts.output_vat),
      purchases_taxable: paise(amounts.purchases_taxable),
      input_vat: paise(amounts.input_vat),
      carry_in: paise(amounts.carry_in),
      payable: paise(amounts.payable),
      carry_out: paise(amounts.carry_out),
      filed_on: filedOn || null,
      paid_amount: paise(paidText),
      receipt_no: receiptNo.trim() || null,
    }
    const res = await save.run(() => api.post<{ data: VatFiling }>('/vat/filings', body, key))
    if (!res) return
    key = newKey()
    toast(`${period} return saved`, `${digits(period)} रिटर्न सेभ भयो`)
    navigate('/vat/filings')
  }
</script>

<div class="page narrow">
  <div class="alert">
    <span class="ms">info</span>
    <div>{tr('Save months in date order. Each month reads the carry of the month before it.', 'महिनाहरू मितिको क्रममा सेभ गर्नुहोस्। हरेक महिनाले अघिल्लो महिनाको बाँकी पढ्छ।')}</div>
  </div>

  <div class="form-grid two">
    <div class="field full">
      <span class="label">{tr('Nepali month', 'बिक्रम सम्वत् महिना')}</span>
      <div class="hstack">
        <select bind:value={year} aria-label={tr('Year', 'वर्ष')}>
          {#each YEARS as y}<option value={y}>{digits(y)}</option>{/each}
        </select>
        <select bind:value={month} aria-label={tr('Month', 'महिना')}>
          {#each MONTHS as m}<option value={m}>{monthName(m)}</option>{/each}
        </select>
      </div>
    </div>

    <Field label={tr('Period label', 'अवधिको नाम')} error={save.field('period')} hint={tr('Made from the month you picked', 'छानेको महिनाबाट बन्छ')} full>
      <input value={period} readonly />
    </Field>
    <Field label={tr('From', 'देखि')} error={save.field('from')}>
      <input value={formatDate(range.from)} readonly />
    </Field>
    <Field label={tr('To', 'सम्म')} error={save.field('to')}>
      <input value={formatDate(range.to)} readonly />
    </Field>

    {#each AMOUNTS as a (a.key)}
      <Field label={tr(a.en, a.ne)} error={save.field(a.key) ?? amountError(amounts[a.key])}>
        <div class="input-group">
          <span class="prefix">Rs</span>
          <input inputmode="decimal" placeholder="0" bind:value={amounts[a.key]} />
        </div>
      </Field>
    {/each}

    <BsDatePicker bind:value={filedOn} label={tr('Filed on', 'फाइल गरेको मिति')} />
    <Field label={tr('Paid amount', 'तिरेको रकम')} error={save.field('paid_amount') ?? amountError(paidText)}>
      <div class="input-group">
        <span class="prefix">Rs</span>
        <input inputmode="decimal" placeholder="0" bind:value={paidText} />
      </div>
    </Field>
    <Field label={tr('Receipt number', 'रसिद नम्बर')} error={save.field('receipt_no')} full>
      <input placeholder={tr('R-', 'आर-')} bind:value={receiptNo} />
    </Field>
  </div>

  {#if save.error}
    <div class="alert bad" style="margin-top:12px"><span class="ms">error</span><div>{errorText(save.error, INLINE)}</div></div>
  {/if}

  <div class="bottom-bar">
    <button class="btn btn-primary btn-lg btn-block" onclick={saveReturn} disabled={save.busy || !amountsValid}>
      <span class="ms">save</span><span>{save.busy ? tr('Saving…', 'सेभ हुँदैछ…') : tr('Save return', 'रिटर्न सेभ गर्ने')}</span>
    </button>
  </div>
</div>
