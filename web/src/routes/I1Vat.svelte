<script lang="ts">
  import { api, newKey } from '../lib/api'
  import { resource, action, debounce } from '../lib/resource.svelte'
  import { tr, num } from '../lib/i18n'
  import { rs, toPaisa } from '../lib/money'
  import { bsMonthRange, daysUntil, formatDate, monthTitle, periodLabel, todayAd, todayBs } from '../lib/bs'
  import { navigate } from '../lib/router.svelte'
  import { toast } from '../lib/toast.svelte'
  import { FILING_STATUS, errorText, filingStatus } from '../lib/vat'
  import type { VatFiling, VatPreview } from '../lib/types'
  import MonthNav from '../components/MonthNav.svelte'
  import Field from '../components/Field.svelte'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'

  let year = $state(todayBs().year)
  let month = $state(todayBs().month)
  const range = $derived(bsMonthRange(year, month))
  const period = $derived(periodLabel(year, month))
  const title = $derived(monthTitle(year, month))
  const isCurrent = $derived(range.from <= todayAd() && todayAd() <= range.to)

  let openingText = $state('0')
  let opening = $state(0)
  $effect(() => debounce(() => openingText, 400, (v) => {
    const paisa = toPaisa(v)
    if (paisa !== null) opening = paisa
  }))
  const openingError = $derived(toPaisa(openingText) === null ? tr('Type an amount, for example 1250', 'रकम लेख्नुहोस्, जस्तै 1250') : null)

  const preview = resource(() =>
    api.get<VatPreview>('/vat/preview', { from: range.from, to: range.to, opening_carry: opening }),
  )
  const showOpening = $derived(!!preview.data && preview.data.carry_in_source.toLowerCase().includes('opening'))
  const days = $derived(preview.data ? daysUntil(preview.data.due_date) : 0)

  const filings = resource(() => api.page<VatFiling>('/vat/filings', { per_page: 50 }))
  const existing = $derived(filings.data?.data.find((f) => f.period === period) ?? null)

  const save = action()
  let key = newKey()

  async function saveMonth(): Promise<void> {
    const res = await save.run(() =>
      api.post<{ data: VatFiling }>('/vat/filings', { period, from: range.from, to: range.to, opening_carry: opening }, key),
    )
    if (!res) return
    key = newKey()
    toast(`Saved as ${title} filing`, `${title} फाइलिङमा सेभ भयो`)
    navigate('/vat/filings')
  }
</script>

<div class="page">
  <MonthNav bind:year bind:month />
  <p class="small muted" style="margin:-6px 0 0">{formatDate(range.from)} {tr('to', 'सम्म')} {formatDate(range.to)}</p>

  {#if preview.error}
    <ErrorCard error={preview.error} retry={preview.reload} />
  {:else if preview.loading && !preview.data}
    <Skeleton card />
  {:else if preview.data}
    <section class="card">
      <div class="hstack between">
        <div class="stat">
          <span class="stat-label">{tr('Due date', 'तिर्ने अन्तिम मिति')}</span>
          <span class="bold">{formatDate(preview.data.due_date)}</span>
        </div>
        <div class="stat" style="text-align:right">
          <span class="stat-value lg" class:bad={days < 0}>{num(Math.abs(days))}</span>
          <span class="stat-sub" style="justify-content:flex-end">{days < 0 ? tr('days past due', 'म्याद नाघेको दिन') : tr('days left', 'दिन बाँकी')}</span>
        </div>
      </div>
    </section>

    <section class="hero">
      <div class="stat">
        <span class="stat-label">{tr('VAT to pay this month', 'यो महिनाको तिर्नुपर्ने भ्याट')}</span>
        <span class="stat-value xl">{rs(preview.data.payable, { paisa: true })}</span>
        <span class="stat-sub">
          {isCurrent
            ? tr(`Numbers up to today (${formatDate(todayAd())})`, `आजसम्मको अंक (${formatDate(todayAd())} सम्म)`)
            : tr('Numbers for the whole month', 'महिना भरिको अंक')}
        </span>
      </div>
    </section>

    <section class="card">
      <div class="card-head"><h3>{tr('Breakdown', 'हिसाब')}</h3></div>
      <div class="kv">
        <div><span class="k">{tr('Sales bills', 'बिक्री बिल')}</span><span class="v">{num(preview.data.sales_bills)}</span></div>
        <div><span class="k">{tr('Taxable sales', 'करयोग्य बिक्री')}</span><span class="v">{rs(preview.data.sales_taxable, { paisa: true })}</span></div>
        <div><span class="k">{tr('Exempt sales', 'करमुक्त बिक्री')}</span><span class="v">{rs(preview.data.sales_exempt, { paisa: true })}</span></div>
        <div><span class="k">{tr('Output VAT', 'बिक्रीमा लागेको भ्याट')}</span><span class="v">{rs(preview.data.output_vat, { paisa: true })}</span></div>
        <div><span class="k">{tr('Purchase bills with VAT', 'भ्याट भएका खरिद बिल')}</span><span class="v">{num(preview.data.purchase_bills_with_vat)}</span></div>
        <div><span class="k">{tr('Taxable purchases', 'करयोग्य खरिद')}</span><span class="v">{rs(preview.data.purchases_taxable, { paisa: true })}</span></div>
        <div><span class="k">{tr('Input VAT', 'खरिदमा तिरेको भ्याट')}</span><span class="v">{rs(preview.data.input_vat, { paisa: true })}</span></div>
        <div><span class="k">{tr('Carried from last month', 'अघिल्लो महिनाबाट सरेको')}</span><span class="v">{rs(preview.data.carry_in, { paisa: true })}</span></div>
        <div class="total"><span class="k">{tr('Payable', 'तिर्नुपर्ने')}</span><span class="v">{rs(preview.data.payable, { paisa: true })}</span></div>
        <div><span class="k">{tr('Carry to next month', 'अर्को महिनामा सर्ने')}</span><span class="v">{rs(preview.data.carry_out, { paisa: true })}</span></div>
      </div>
      <p class="tiny muted" style="margin-top:10px">{tr(
        'Payable = output VAT − input VAT − carried from last month. If that is below zero, nothing is paid and the rest is carried to next month.',
        'तिर्नुपर्ने = बिक्रीको भ्याट − खरिदको भ्याट − अघिल्लो बाँकी। शून्यभन्दा कम भए केही तिर्नु पर्दैन र बाँकी अर्को महिनामा सर्छ।',
      )}</p>
    </section>

    {#if showOpening}
      <section class="card stack">
        <Field label={tr('Opening carry (rupees)', 'सुरुको बाँकी (रुपैयाँ)')} error={openingError} hint={tr('Set once. Type the credit from your last IRD return. If you are not sure, keep 0.', 'एक पटक मात्र। अन्तिम IRD रिटर्नको बाँकी लेख्नुहोस्। थाहा छैन भने 0 राख्नुहोस्।')}>
          <div class="input-group">
            <span class="prefix">Rs</span>
            <input inputmode="decimal" bind:value={openingText} />
          </div>
        </Field>
      </section>
    {/if}

    <p class="tiny muted">{tr(
      'These numbers are building blocks to copy into the IRD form. Check the box names with the IRD portal before you file.',
      'यी अंक IRD फारममा सार्नका लागि आधार हुन्। फाइल गर्नु अघि IRD पोर्टलमा खानाहरूको नाम जाँच गर्नुहोस्।',
    )}</p>

    {#if existing}
      <section class="card">
        <div class="hstack between">
          <div class="stack-sm" style="gap:0">
            <span class="small muted">{tr(`${title} is already saved`, `${title} पहिले नै सेभ भइसकेको छ`)}</span>
            <a class="bold" href={`#/vat/filings/${existing.id}`}>{tr('Open the filing', 'फाइलिङ खोल्ने')}</a>
          </div>
          <span class="badge {FILING_STATUS[filingStatus(existing)].cls}">{tr(FILING_STATUS[filingStatus(existing)].en, FILING_STATUS[filingStatus(existing)].ne)}</span>
        </div>
      </section>
    {/if}

    {#if save.error}
      <div class="alert bad"><span class="ms">error</span><div>{errorText(save.error)}</div></div>
    {/if}

    <div class="hstack wrap">
      <button class="btn btn-primary" onclick={saveMonth} disabled={save.busy || !!existing || openingError !== null}>
        <span class="ms">save</span>
        <span>{save.busy ? tr('Saving…', 'सेभ हुँदैछ…') : tr(`Save ${title} as filing`, `${title} फाइलिङमा सेभ गर्ने`)}</span>
      </button>
      <a class="btn btn-outline" href="#/vat/filings"><span class="ms">folder</span><span>{tr('See filings', 'फाइलिङ हेर्ने')}</span></a>
      <a class="btn btn-outline" href="#/vat/old-return"><span class="ms">history</span><span>{tr('Add old return', 'पुरानो रिटर्न थप्ने')}</span></a>
      <a class="btn btn-outline" href="#/vat/books"><span class="ms">menu_book</span><span>{tr('Sales and purchase books', 'बिक्री र खरिद खाता')}</span></a>
    </div>
  {/if}
</div>
