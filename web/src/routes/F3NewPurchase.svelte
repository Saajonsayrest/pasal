<script lang="ts">
  import { api, newKey } from '../lib/api'
  import { resource, action, debounce } from '../lib/resource.svelte'
  import { navigate } from '../lib/router.svelte'
  import { untrack } from 'svelte'
  import { tr, num } from '../lib/i18n'
  import { rs, toPaisa, fromPaisa } from '../lib/money'
  import { todayAd } from '../lib/bs'
  import { initials } from '../lib/util'
  import { toast } from '../lib/toast.svelte'
  import type { Item, Purchase, Supplier } from '../lib/types'
  import BsDatePicker from '../components/BsDatePicker.svelte'
  import Field from '../components/Field.svelte'
  import Sheet from '../components/Sheet.svelte'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Empty from '../components/Empty.svelte'

  let { query }: { query: Record<string, string> } = $props()

  type Line = { item: Item; qty: string; cost: string }

  const methods = [
    { key: 'cash', icon: 'payments', en: 'Cash', ne: 'नगद' },
    { key: 'bank', icon: 'account_balance', en: 'Bank', ne: 'बैंक' },
    { key: 'cheque', icon: 'receipt', en: 'Cheque', ne: 'चेक' },
  ]

  function intParam(text: string | undefined): number | null {
    return text && /^\d+$/.test(text) ? Number(text) : null
  }

  function optionalPaisa(text: string): number | null {
    return text.trim() === '' ? 0 : toPaisa(text)
  }

  const suppliers = resource(() => api.all<Supplier>('/suppliers', {}, 50))
  let supplierId = $state<number | null>(untrack(() => intParam(query.supplier)))
  let supplierOpen = $state(false)
  let supplierTyped = $state('')
  const supplier = $derived(suppliers.data?.find((s) => s.id === supplierId) ?? null)
  const supplierMatches = $derived.by(() => {
    const q = supplierTyped.trim().toLowerCase()
    return (suppliers.data ?? []).filter((s) => s.name.toLowerCase().includes(q) || (s.phone ?? '').includes(q))
  })

  let billNo = $state('')
  let billDate = $state(todayAd())

  let lines = $state<Line[]>([])
  let prefillError = $state('')
  let itemsOpen = $state(false)
  let itemTyped = $state('')
  let itemTerm = $state('')
  $effect(() => debounce(() => itemTyped, 250, (v) => (itemTerm = v)))

  const found = resource(async () => {
    const term = itemTerm
    if (!itemsOpen) return null
    return (await api.page<Item>('/items', { search: term, per_page: 50 })).data
  })

  let vatText = $state('')
  let paidText = $state('')
  let method = $state('cash')
  let note = $state('')

  function qtyOf(line: Line): number | null {
    const n = intParam(line.qty)
    return n !== null && n >= 1 && n <= 1000000 ? n : null
  }

  function costOf(line: Line): number | null {
    const paisa = toPaisa(line.cost)
    return paisa !== null && paisa <= 10000000000 ? paisa : null
  }

  function lineTotal(line: Line): number | null {
    const q = qtyOf(line)
    const c = costOf(line)
    if (q === null || c === null) return null
    const t = q * c
    return Number.isSafeInteger(t) ? t : null
  }

  const linesTotal = $derived(lines.reduce((sum, l) => sum + (lineTotal(l) ?? 0), 0))
  const vat = $derived(optionalPaisa(vatText))
  const paid = $derived(optionalPaisa(paidText))
  const total = $derived(linesTotal + (vat ?? 0))
  const balance = $derived(total - (paid ?? 0))

  const vatError = $derived(vat === null ? tr('Type the VAT as a number, for example 2,327.', 'भ्याट संख्यामा लेख्नुहोस्, जस्तै: २,३२७।') : null)
  const paidError = $derived(
    paid === null
      ? tr('Type the amount as a number.', 'रकम संख्यामा लेख्नुहोस्।')
      : paid > total
        ? tr(`Paid cannot be more than the total (${rs(total)}).`, `तिरेको रकम जम्मा (${rs(total)}) भन्दा बढी हुन सक्दैन।`)
        : null,
  )

  function payload() {
    if (supplierId === null || vat === null || paid === null || paid > total || lines.length === 0) return null
    const items: { item_id: number; quantity: number; unit_cost: number }[] = []
    for (const line of lines) {
      const quantity = qtyOf(line)
      const unit_cost = costOf(line)
      if (quantity === null || unit_cost === null) return null
      items.push({ item_id: line.item.id, quantity, unit_cost })
    }
    return {
      supplier_id: supplierId,
      bill_no: billNo.trim() || null,
      bill_date: billDate,
      vat_amount: vat,
      paid,
      method,
      note: note.trim() || null,
      items,
    }
  }

  const ready = $derived(payload() !== null)
  const save = action()
  let key = newKey()

  const problem = $derived(save.error ? (Object.values(save.error.errors)[0]?.[0] ?? save.error.message) : null)

  async function submit(): Promise<void> {
    const body = payload()
    if (!body) return
    const saved = await save.run(() => api.post<{ data: Purchase }>('/purchases', body, key))
    if (!saved) return
    key = newKey()
    toast(`Purchase saved. We owe ${rs(saved.data.balance)}.`, `खरिद सेभ भयो। हामीले ${rs(saved.data.balance)} तिर्नुपर्छ।`)
    navigate(`/purchases/${saved.data.id}`, true)
  }

  function pickSupplier(s: Supplier): void {
    supplierId = s.id
    supplierOpen = false
    supplierTyped = ''
  }

  function pickItem(item: Item): void {
    const existing = lines.find((l) => l.item.id === item.id)
    if (existing) existing.qty = String((qtyOf(existing) ?? 0) + 1)
    else lines.push({ item, qty: '1', cost: item.cost_price === null ? '' : fromPaisa(item.cost_price) })
    itemsOpen = false
    itemTyped = ''
  }

  function bump(line: Line, by: number): void {
    line.qty = String(Math.max(1, (qtyOf(line) ?? 0) + by))
  }

  function removeLine(id: number): void {
    lines = lines.filter((l) => l.item.id !== id)
  }

  async function prefillItems(text: string): Promise<void> {
    for (const pair of text.split(',')) {
      const [rawId, rawQty] = pair.split(':')
      const itemId = intParam(rawId)
      const quantity = intParam(rawQty)
      if (itemId === null || quantity === null || quantity < 1) continue
      try {
        const { data: item } = await api.get<{ data: Item }>(`/items/${itemId}`)
        if (lines.some((l) => l.item.id === item.id)) continue
        lines.push({ item, qty: String(quantity), cost: item.cost_price === null ? '' : fromPaisa(item.cost_price) })
      } catch {
        prefillError = tr('Some items could not be loaded. Add them again.', 'केहि सामान लोड भएनन्। फेरि थप्नुहोस्।')
      }
    }
  }

  const prefill = untrack(() => query.items)
  if (prefill) void prefillItems(prefill)
</script>

<div class="page narrow">
  <div class="section-title"><h3>{tr('Supplier', 'डिलर')}</h3></div>
  {#if suppliers.error}
    <ErrorCard error={suppliers.error} retry={suppliers.reload} />
  {:else}
    <div class="list">
      <button type="button" class="row" onclick={() => (supplierOpen = true)}>
        <span class="avatar info">{supplier ? initials(supplier.name) : '?'}</span>
        <div class="row-main">
          {#if supplier}
            <div class="row-title">{supplier.name}</div>
            <div class="row-sub">
              {tr(`We owe ${rs(supplier.we_owe ?? 0)} · tap to change`, `हामीले तिर्ने ${rs(supplier.we_owe ?? 0)} · फेर्न ट्याप गर्नुहोस्`)}
            </div>
          {:else}
            <div class="row-title">{tr('Pick a supplier', 'डिलर छान्नुहोस्')}</div>
            <div class="row-sub">{tr('Tap to choose who you bought from', 'कसबाट किनुभयो छान्न ट्याप गर्नुहोस्')}</div>
          {/if}
        </div>
        <span class="ms chev">chevron_right</span>
      </button>
    </div>
  {/if}

  <div class="section-title"><h3>{tr('Bill', 'बिल')}</h3></div>
  <div class="form-grid two">
    <Field label={tr('Bill number', 'बिल नम्बर')}>
      <input placeholder={tr('For example: INV-902', 'जस्तै: INV-902')} bind:value={billNo} />
    </Field>
    <div>
      <BsDatePicker bind:value={billDate} label={tr('Bill date (BS)', 'बिल मिति (BS)')} max={todayAd()} />
      <span class="field-hint">{tr('VAT counts in the month of the bill date.', 'VAT बिलको मितिको महिनामा गणना हुन्छ।')}</span>
    </div>
  </div>

  <div class="alert">
    <span class="ms">photo_camera</span>
    <div>{tr('A photo of the paper bill is not supported yet. Type the bill number and VAT instead.', 'कागजी बिलको फोटो अहिले राख्न मिल्दैन। बिल नम्बर र भ्याट लेख्नुहोस्।')}</div>
  </div>

  <div class="section-title">
    <h3>{tr('Items', 'सामान')}</h3>
    <button type="button" class="btn btn-tonal btn-sm" onclick={() => (itemsOpen = true)}><span class="ms">add</span><span>{tr('Add item', 'सामान थप्ने')}</span></button>
  </div>

  {#if prefillError}
    <div class="alert bad"><span class="ms">error</span><div>{prefillError}</div></div>
  {/if}

  {#if lines.length === 0}
    <p class="small muted center">{tr('No items yet. Tap Add item.', 'अहिलेसम्म सामान छैन। सामान थप्न ट्याप गर्नुहोस्।')}</p>
  {/if}

  {#each lines as line (line.item.id)}
    <div class="card">
      <div class="hstack between">
        <span class="bold">{line.item.name}</span>
        <div class="hstack">
          <span class="amount">{rs(lineTotal(line) ?? 0)}</span>
          <button type="button" class="btn btn-icon" aria-label={tr('Remove item', 'सामान हटाउने')} onclick={() => removeLine(line.item.id)}>
            <span class="ms">close</span>
          </button>
        </div>
      </div>
      <div class="hstack between" style="margin-top:10px;align-items:flex-start">
        <div class="stack-sm" style="gap:4px">
          <div class="stepper">
            <button type="button" aria-label={tr('One less', 'एउटा कम')} onclick={() => bump(line, -1)}><span class="ms">remove</span></button>
            <input class="qty" inputmode="numeric" aria-label={tr('Quantity', 'मात्रा')} bind:value={line.qty} />
            <button type="button" aria-label={tr('One more', 'एउटा थप')} onclick={() => bump(line, 1)}><span class="ms">add</span></button>
          </div>
          {#if qtyOf(line) === null}
            <span class="field-error">{tr('Type a quantity of 1 or more.', 'मात्रा १ वा बढी लेख्नुहोस्।')}</span>
          {/if}
        </div>
        <div style="width:150px">
          <Field
            label={tr('Unit cost', 'प्रति एकाइ मूल्य')}
            error={costOf(line) === null ? tr('Type the price in rupees.', 'मूल्य रुपैयामा लेख्नुहोस्।') : null}
            hint={tr('each, before VAT', 'प्रति एकाइ, भ्याट बाहेक')}
          >
            <div class="input-group"><span class="prefix">Rs</span><input inputmode="decimal" bind:value={line.cost} /></div>
          </Field>
        </div>
      </div>
    </div>
  {/each}

  {#if lines.length > 0}
    <div class="alert">
      <span class="ms">update</span>
      <div>{tr('The buying price of each item changes to this cost.', 'हरेक सामानको किन्ने मूल्य यो लागतमा बदलिन्छ।')}</div>
    </div>
  {/if}

  <Field label={tr('VAT on the bill', 'बिलमा भएको भ्याट')} error={vatError} hint={tr('Copy the VAT amount from the paper bill. Leave empty if there is none.', 'कागजी बिलमा लेखिएको भ्याट राख्नुहोस्। बिलमा नभए खाली छोड्नुहोस्।')}>
    <div class="input-group"><span class="prefix">Rs</span><input inputmode="decimal" bind:value={vatText} placeholder="0" /></div>
  </Field>

  <div class="card">
    <div class="kv">
      <div><span class="k">{tr('Lines total', 'सामानको जम्मा')}</span><span class="v">{rs(linesTotal)}</span></div>
      <div><span class="k">{tr('VAT (from bill)', 'भ्याट (बिलबाट)')}</span><span class="v">{rs(vat ?? 0)}</span></div>
      <div class="total"><span class="k">{tr('Total', 'जम्मा')}</span><span class="v">{rs(total)}</span></div>
    </div>
  </div>

  <Field label={tr('Paid now', 'अहिले तिरेको')} error={paidError}>
    <div class="input-group"><span class="prefix">Rs</span><input inputmode="decimal" bind:value={paidText} placeholder="0" /></div>
  </Field>
  <div class="seg block">
    {#each methods as m (m.key)}
      <button type="button" class:active={method === m.key} onclick={() => (method = m.key)}>
        <span class="ms">{m.icon}</span><span>{tr(m.en, m.ne)}</span>
      </button>
    {/each}
  </div>

  <div class="hstack between">
    <span class="bold">{tr('We owe after this', 'अब हामीले तिर्ने')}</span>
    <span class="stat-value warn" style="font-size:22px">{rs(Math.max(0, balance))}</span>
  </div>

  <Field label={tr('Note (optional)', 'नोट (ऐच्छिक)')}>
    <textarea rows="2" bind:value={note}></textarea>
  </Field>

  {#if problem}
    <div class="alert bad"><span class="ms">error</span><div>{problem}</div></div>
  {/if}

  <div class="bottom-bar">
    {#if !ready}
      <p class="small muted center" style="margin:0">{tr('Pick a supplier, add at least one item and check the amounts.', 'डिलर छान्नुहोस्, कम्तीमा एउटा सामान थप्नुहोस्, र रकम जाँच गर्नुहोस्।')}</p>
    {/if}
    <button class="btn btn-primary btn-lg btn-block" type="button" disabled={!ready || save.busy} onclick={submit}>
      <span class="ms">check</span><span>{save.busy ? tr('Saving…', 'सेभ हुँदैछ…') : tr('Save purchase', 'खरिद सेभ गर्ने')}</span>
    </button>
  </div>
</div>

<Sheet bind:open={supplierOpen} title={tr('Choose supplier', 'डिलर छान्नुहोस्')}>
  <label class="search">
    <span class="ms">search</span>
    <input placeholder={tr('Search supplier name or phone', 'डिलरको नाम वा फोन खोज्नुहोस्')} bind:value={supplierTyped} />
  </label>
  {#if suppliers.loading && !suppliers.data}
    <Skeleton rows={4} />
  {:else if supplierMatches.length === 0}
    <Empty icon="storefront" title={tr('No supplier found', 'डिलर भेटिएन')} text={tr('Add the supplier first from the Suppliers screen.', 'पहिले डिलर स्क्रिनबाट डिलर थप्नुहोस्।')} />
  {:else}
    <div class="list">
      {#each supplierMatches as s (s.id)}
        <button type="button" class="row" onclick={() => pickSupplier(s)}>
          <span class="avatar info">{initials(s.name)}</span>
          <div class="row-main">
            <div class="row-title">{s.name}</div>
            <div class="row-sub">{s.phone ?? ''}</div>
          </div>
          {#if (s.we_owe ?? 0) > 0}<span class="tiny warn">{rs(s.we_owe)}</span>{/if}
        </button>
      {/each}
    </div>
  {/if}
</Sheet>

<Sheet bind:open={itemsOpen} title={tr('Add item', 'सामान थप्ने')}>
  <label class="search">
    <span class="ms">search</span>
    <input placeholder={tr('Search item to add', 'थप्न सामान खोज्नुहोस्')} bind:value={itemTyped} />
  </label>
  {#if found.error}
    <ErrorCard error={found.error} retry={found.reload} />
  {:else if found.loading && !found.data}
    <Skeleton rows={4} />
  {:else if (found.data ?? []).length === 0}
    <Empty icon="inventory_2" title={tr('No item found', 'सामान भेटिएन')} text={tr('Try another word, or add the item first.', 'अर्को शब्द खोज्नुहोस्, वा पहिले सामान थप्नुहोस्।')} />
  {:else}
    <div class="list">
      {#each found.data ?? [] as item (item.id)}
        <button type="button" class="row" onclick={() => pickItem(item)}>
          <div class="row-main">
            <div class="row-title">{item.name}</div>
            <div class="row-sub">{tr(`${num(item.quantity)} ${item.unit} in stock`, `स्टकमा ${num(item.quantity)} ${item.unit}`)}</div>
          </div>
          {#if lines.some((l) => l.item.id === item.id)}<span class="badge good">{tr('Added', 'थपियो')}</span>{/if}
        </button>
      {/each}
    </div>
  {/if}
</Sheet>

<style>
  .qty {
    width: 56px;
    border: 0;
    background: transparent;
    text-align: center;
    font-weight: 700;
    font-size: 16px;
    padding: 0;
    color: inherit;
  }
</style>
