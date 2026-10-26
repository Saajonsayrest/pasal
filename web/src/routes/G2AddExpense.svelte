<script lang="ts">
  import { api, newKey } from '../lib/api'
  import { action } from '../lib/resource.svelte'
  import { navigate } from '../lib/router.svelte'
  import { toast } from '../lib/toast.svelte'
  import { tr } from '../lib/i18n'
  import { toPaisa } from '../lib/money'
  import { todayAd } from '../lib/bs'
  import AmountPad from '../components/AmountPad.svelte'
  import BsDatePicker from '../components/BsDatePicker.svelte'
  import Field from '../components/Field.svelte'

  const PRESETS = [
    { en: 'Bills', ne: 'बिल', icon: 'bolt' },
    { en: 'Rent', ne: 'भाडा', icon: 'home' },
    { en: 'Salary', ne: 'तलब', icon: 'payments' },
    { en: 'Transport', ne: 'यातायात', icon: 'directions_bus' },
    { en: 'Repair', ne: 'मर्मत', icon: 'build' },
    { en: 'Tea and snacks', ne: 'चिया र खाजा', icon: 'local_cafe' },
    { en: 'Other', ne: 'अन्य', icon: 'more_horiz' },
  ]

  let amount = $state('')
  let title = $state('')
  let category = $state('')
  let spentAt = $state(todayAd())
  let tried = $state(false)
  const save = action()
  let key = newKey()

  const paisa = $derived(toPaisa(amount))
  const amountError = $derived(
    tried && (paisa === null || paisa < 1) ? tr('Type the amount in rupees', 'रकम रुपैयाँमा लेख्नुहोस्') : save.field('amount'),
  )
  const titleError = $derived(tried && !title.trim() ? tr('Write what it was for', 'किन खर्च भयो लेख्नुहोस्') : save.field('title'))

  async function submit(e: Event): Promise<void> {
    e.preventDefault()
    tried = true
    const value = toPaisa(amount)
    if (value === null || value < 1 || !title.trim()) return
    const ok = await save.run(() =>
      api.post(
        '/expenses',
        {
          title: title.trim(),
          category: category.trim().toLowerCase() || null,
          amount: value,
          spent_at: spentAt,
        },
        key,
      ),
    )
    if (ok) {
      key = newKey()
      toast('Expense saved', 'खर्च सेभ भयो')
      navigate('/expenses')
    }
  }
</script>

<form class="page narrow" onsubmit={submit}>
  <section class="card">
    <AmountPad bind:value={amount} />
    {#if amountError}
      <span class="field-error"><span class="ms" style="font-size:16px">error</span><span>{amountError}</span></span>
    {/if}
  </section>

  <div class="form-grid">
    <Field label={tr('What was it for?', 'यो किन खर्च भयो?')} error={titleError}>
      <input bind:value={title} maxlength="150" placeholder={tr('For example: Electricity', 'उदाहरण: बिजुली')} />
    </Field>

    <Field label={tr('Category', 'वर्ग')} error={save.field('category')} hint={tr('Pick one or type your own', 'एउटा छान्नुहोस् वा आफैँ लेख्नुहोस्')}>
      <input bind:value={category} maxlength="50" placeholder={tr('Type a category', 'वर्ग लेख्नुहोस्')} />
    </Field>
    <div class="chips wrap">
      {#each PRESETS as p (p.en)}
        <button type="button" class="chip" class:active={category.trim().toLowerCase() === p.en.toLowerCase()} onclick={() => (category = p.en)}>
          <span class="ms">{p.icon}</span><span>{tr(p.en, p.ne)}</span>
        </button>
      {/each}
    </div>

    <BsDatePicker bind:value={spentAt} label={tr('Date', 'मिति')} max={todayAd()} />
    {#if save.field('spent_at')}
      <span class="field-error"><span class="ms" style="font-size:16px">error</span><span>{save.field('spent_at')}</span></span>
    {/if}
  </div>

  {#if save.message}
    <div class="alert bad"><span class="ms">error</span><div>{save.message}</div></div>
  {/if}

  <div class="bottom-bar">
    <a class="btn btn-outline btn-lg" href="#/expenses" style="flex:1"><span>{tr('Back', 'फर्कनुहोस्')}</span></a>
    <button class="btn btn-primary btn-lg" type="submit" style="flex:1.4" disabled={save.busy}>
      <span class="ms">check</span><span>{save.busy ? tr('Saving…', 'सेभ हुँदैछ…') : tr('Save expense', 'खर्च सेभ गर्ने')}</span>
    </button>
  </div>
</form>
