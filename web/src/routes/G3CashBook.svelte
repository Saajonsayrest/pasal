<script lang="ts">
  import { api } from '../lib/api'
  import { resource } from '../lib/resource.svelte'
  import { tr, num } from '../lib/i18n'
  import { rs, toPaisa, fromPaisa } from '../lib/money'
  import { addDaysAd, formatDate, formatTime, todayAd } from '../lib/bs'
  import { toast } from '../lib/toast.svelte'
  import type { CashBook } from '../lib/types'
  import BsDatePicker from '../components/BsDatePicker.svelte'
  import Sheet from '../components/Sheet.svelte'
  import Field from '../components/Field.svelte'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Empty from '../components/Empty.svelte'

  type Entry = CashBook['data'][number]
  type Saved = { counted: number; expected: number; diff: number }
  type SavedDay = { day: string; saved: Saved }

  const PREFIX = 'pasal-cash-count:'
  const NOTES = [1000, 500, 100, 50, 20, 10, 5]
  const KIND: Record<Entry['kind'], { icon: string; tone: string; en: string; ne: string }> = {
    payment_in: { icon: 'arrow_downward', tone: 'good', en: 'Received from customer', ne: 'ग्राहकबाट पाइयो' },
    payment_out: { icon: 'arrow_upward', tone: 'info', en: 'Paid to supplier', ne: 'डिलरलाई तिरियो' },
    refund: { icon: 'undo', tone: 'warn', en: 'Refund to customer', ne: 'ग्राहकलाई फिर्ता' },
    expense: { icon: 'receipt_long', tone: 'bad', en: 'Expense', ne: 'खर्च' },
  }
  const METHOD: Record<string, [string, string]> = {
    cash: ['Cash', 'नगद'],
    qr: ['QR', 'QR'],
    bank: ['Bank', 'बैंक'],
    card: ['Card', 'कार्ड'],
    esewa: ['eSewa', 'eSewa'],
    khalti: ['Khalti', 'Khalti'],
  }
  const methodName = (m: string) => (METHOD[m] ? tr(METHOD[m][0], METHOD[m][1]) : m)

  const today = todayAd()
  let day = $state(today)
  let counted = $state('')
  let countError = $state<string | null>(null)
  let countOpen = $state(false)
  let counts = $state<number[]>(NOTES.map(() => 0))

  function readOne(d: string): Saved | null {
    try {
      return JSON.parse(localStorage.getItem(PREFIX + d) ?? 'null') as Saved | null
    } catch {
      return null
    }
  }

  function readSaved(): SavedDay[] {
    const out: SavedDay[] = []
    try {
      for (let i = 0; i < localStorage.length; i++) {
        const k = localStorage.key(i)
        if (!k?.startsWith(PREFIX)) continue
        const saved = readOne(k.slice(PREFIX.length))
        if (saved) out.push({ day: k.slice(PREFIX.length), saved })
      }
    } catch {
      // Storage can be blocked. The list stays empty.
    }
    return out.sort((a, b) => (a.day < b.day ? 1 : -1))
  }

  let savedDays = $state<SavedDay[]>(readSaved())

  $effect(() => {
    const saved = readOne(day)
    counted = saved ? fromPaisa(saved.counted) : ''
    countError = null
  })

  // Several pages when the day has more than 100 entries. Totals come from the first page.
  async function loadDay(d: string): Promise<CashBook> {
    const first = await api.get<CashBook>('/cash-book', { from: d, to: d, per_page: 100, page: 1 })
    const data = [...first.data]
    const pages = Math.min(Math.ceil(first.meta.total / 100), 200)
    for (let page = 2; page <= pages; page++) {
      const next = await api.get<CashBook>('/cash-book', { from: d, to: d, per_page: 100, page })
      data.push(...next.data)
    }
    return { ...first, data }
  }

  const book = resource(() => loadDay(day))
  const fresh = $derived(!book.loading && !!book.data && book.data.from === day)
  const expected = $derived(book.data?.closing_balance ?? 0)

  const countedPaisa = $derived(counted.trim() === '' ? null : toPaisa(counted))
  const invalid = $derived(counted.trim() !== '' && countedPaisa === null)
  const diff = $derived(countedPaisa === null ? null : countedPaisa - expected)

  const noteTotal = $derived(NOTES.reduce((sum, n, i) => sum + n * counts[i], 0))
  const noteDiff = $derived(noteTotal * 100 - expected)

  function useCount(): void {
    counted = fromPaisa(noteTotal * 100)
    countOpen = false
  }

  function saveDay(): void {
    if (countedPaisa === null || !fresh) {
      countError = tr('Type the counted cash in rupees first', 'पहिले गनिएको नगद रुपैयाँमा लेख्नुहोस्')
      return
    }
    countError = null
    const saved: Saved = { counted: countedPaisa, expected, diff: countedPaisa - expected }
    try {
      localStorage.setItem(PREFIX + day, JSON.stringify(saved))
    } catch {
      // Storage can be blocked. The count stays on screen only.
    }
    savedDays = readSaved()
    toast('Count saved', 'गन्ती सेभ भयो')
  }

  const dayChips = [1, 2].map((back) => addDaysAd(today, -back))
</script>

{#snippet verdict(d: number)}
  {#if d < 0}
    <div class="alert warn"><span class="ms">warning</span><div class="alert-title">{tr(`${rs(-d)} short`, `${rs(-d)} कम छ`)}</div></div>
  {:else if d > 0}
    <div class="alert"><span class="ms">info</span><div class="alert-title">{tr(`${rs(d)} over`, `${rs(d)} बढी छ`)}</div></div>
  {:else}
    <div class="alert good"><span class="ms">check_circle</span><div class="alert-title">{tr('Matches', 'मिल्यो')}</div></div>
  {/if}
{/snippet}

<div class="page">
  <BsDatePicker bind:value={day} label={tr('Day', 'दिन')} max={today} />
  <div class="chips">
    <button class="chip" class:active={day === today} onclick={() => (day = today)}>
      <span class="ms">today</span><span>{tr('Today', 'आज')} · {formatDate(today)}</span>
    </button>
    {#each dayChips as d (d)}
      <button class="chip" class:active={day === d} onclick={() => (day = d)}>{formatDate(d)}</button>
    {/each}
  </div>

  {#if book.error}
    <ErrorCard error={book.error} retry={book.reload} />
  {:else if book.loading && !book.data}
    <Skeleton card />
    <Skeleton rows={4} />
  {:else if book.data}
    {@const data = book.data}
    <section class="hero">
      <div class="stat">
        <span class="stat-label">{tr('Expected cash in drawer', 'ड्रअरमा अपेक्षित नगद')}</span>
        <span class="stat-value xl">{rs(data.closing_balance)}</span>
        <span class="stat-sub">{tr('Opening balance + money in - money out', 'सुरुको रकम + आएको - गएको')}</span>
      </div>
    </section>

    <section class="card">
      <div class="kv">
        <div><span class="k">{tr('Opening cash', 'सुरुको नगद')}</span><span class="v">{rs(data.opening_balance)}</span></div>
        <div><span class="k">{tr('Money in', 'आएको पैसा')}</span><span class="v good">+ {rs(data.money_in)}</span></div>
        <div><span class="k">{tr('Money out', 'गएको पैसा')}</span><span class="v bad">- {rs(data.money_out)}</span></div>
        <div class="total"><span class="k">{tr('Expected in drawer', 'ड्रअरमा अपेक्षित')}</span><span class="v">{rs(data.closing_balance)}</span></div>
      </div>
    </section>

    <section class="card stack">
      <Field label={tr('Counted cash (rupees)', 'गनिएको नगद (रुपैयाँ)')} error={invalid ? tr('Type a number in rupees', 'रुपैयाँमा संख्या लेख्नुहोस्') : countError}>
        <div class="input-group">
          <span class="prefix">Rs</span>
          <input inputmode="decimal" bind:value={counted} placeholder="0" />
        </div>
      </Field>
      {#if diff !== null}
        {@render verdict(diff)}
      {/if}
    </section>

    {#if savedDays.length > 0}
      <div class="section-title"><h3>{tr('Past days', 'पछिल्ला दिनहरू')}</h3></div>
      <div class="list">
        {#each savedDays as s (s.day)}
          <button class="row" onclick={() => (day = s.day)}>
            <span class="icon-tile" class:good={s.saved.diff === 0} class:warn={s.saved.diff < 0} class:info={s.saved.diff > 0}>
              <span class="ms">{s.saved.diff === 0 ? 'check' : s.saved.diff < 0 ? 'warning' : 'info'}</span>
            </span>
            <div class="row-main">
              <div class="row-title">{formatDate(s.day)}</div>
              <div class="row-sub">{tr('Counted', 'गनिएको')} {rs(s.saved.counted)}</div>
            </div>
            <span class="badge" class:good={s.saved.diff === 0} class:warn={s.saved.diff < 0} class:info={s.saved.diff > 0}>
              {s.saved.diff === 0 ? tr('Matched', 'मिल्यो') : s.saved.diff < 0 ? tr(`${rs(-s.saved.diff)} short`, `${rs(-s.saved.diff)} कम`) : tr(`${rs(s.saved.diff)} over`, `${rs(s.saved.diff)} बढी`)}
            </span>
          </button>
        {/each}
      </div>
    {/if}

    <div class="section-title"><h3>{tr('Entries', 'लेनदेन')}</h3><span class="small muted">{num(data.meta.total)}</span></div>
    {#if data.data.length === 0}
      <Empty icon="receipt_long" title={tr('No cash moved on this day', 'यस दिन नगद चलेन')} text={tr('Payments, supplier payments, refunds and expenses show here.', 'भुक्तानी, डिलरलाई तिरेको, फिर्ता र खर्च यहाँ देखिन्छ।')} />
    {:else}
      <div class="list phone-only">
        {#each data.data as e (`${e.kind}-${e.id}`)}
          <div class="row">
            <span class="icon-tile {KIND[e.kind].tone}"><span class="ms">{KIND[e.kind].icon}</span></span>
            <div class="row-main">
              <div class="row-title">{e.label ?? tr(KIND[e.kind].en, KIND[e.kind].ne)}</div>
              <div class="row-sub">{tr(KIND[e.kind].en, KIND[e.kind].ne)} · {methodName(e.method)} · {formatTime(e.at)}</div>
            </div>
            <div class="row-end">
              <span class="amount">{rs(e.amount)}</span>
              <span class="tiny muted">{tr('Balance', 'बाँकी')} {rs(e.balance)}</span>
            </div>
          </div>
        {/each}
      </div>

      <div class="table-wrap wide-only">
        <table class="table">
          <thead>
            <tr>
              <th>{tr('Time', 'समय')}</th>
              <th>{tr('Type', 'प्रकार')}</th>
              <th>{tr('Name', 'नाम')}</th>
              <th>{tr('Method', 'तरिका')}</th>
              <th class="r">{tr('Amount', 'रकम')}</th>
              <th class="r">{tr('Balance', 'बाँकी')}</th>
            </tr>
          </thead>
          <tbody>
            {#each data.data as e (`${e.kind}-${e.id}`)}
              <tr>
                <td>{formatTime(e.at)}</td>
                <td><span class="badge {KIND[e.kind].tone}"><span class="ms">{KIND[e.kind].icon}</span><span>{tr(KIND[e.kind].en, KIND[e.kind].ne)}</span></span></td>
                <td>{e.label ?? ''}</td>
                <td>{methodName(e.method)}</td>
                <td class="r">{rs(e.amount)}</td>
                <td class="r">{rs(e.balance)}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {/if}
  {/if}

  <div class="bottom-bar">
    <button class="btn btn-outline btn-lg" style="flex:1" onclick={() => (countOpen = true)}>
      <span class="ms">calculate</span><span>{tr('Count cash', 'नगद गन्ने')}</span>
    </button>
    <button class="btn btn-primary btn-lg" style="flex:1.2" disabled={!fresh} onclick={saveDay}>
      <span class="ms">save</span><span>{tr('Save count', 'गन्ती सेभ गर्ने')}</span>
    </button>
  </div>

  <Sheet bind:open={countOpen} title={tr('Count cash', 'नगद गन्ने')}>
    <div class="list">
      {#each NOTES as note, i (note)}
        <div class="row">
          <div class="row-main">
            <div class="row-title">{rs(note * 100)}</div>
            <div class="row-sub">{tr('Total', 'जम्मा')} {rs(note * counts[i] * 100)}</div>
          </div>
          <div class="stepper">
            <button type="button" aria-label={tr('Less', 'कम')} onclick={() => (counts[i] = Math.max(0, counts[i] - 1))}><span class="ms">remove</span></button>
            <span class="val">{num(counts[i])}</span>
            <button type="button" aria-label={tr('More', 'थप')} onclick={() => (counts[i] += 1)}><span class="ms">add</span></button>
          </div>
        </div>
      {/each}
    </div>
    <div class="kv">
      <div><span class="k">{tr('Expected', 'अपेक्षित')}</span><span class="v">{rs(expected)}</span></div>
      <div class="total"><span class="k">{tr('Counted total', 'गनिएको जम्मा')}</span><span class="v">{rs(noteTotal * 100)}</span></div>
    </div>
    {@render verdict(noteDiff)}
    <button class="btn btn-primary btn-lg btn-block" type="button" onclick={useCount}>
      <span>{tr('Use this count', 'यो गन्ती प्रयोग गर्ने')}</span>
    </button>
  </Sheet>
</div>
