<script lang="ts">
  import { api } from '../lib/api'
  import { action, resource } from '../lib/resource.svelte'
  import { session } from '../lib/session.svelte'
  import { tr } from '../lib/i18n'
  import { fromPaisa, toPaisa } from '../lib/money'
  import { navigate } from '../lib/router.svelte'
  import { toast } from '../lib/toast.svelte'
  import type { Customer } from '../lib/types'
  import Field from '../components/Field.svelte'
  import Sheet from '../components/Sheet.svelte'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'

  let { params, query }: { params: Record<string, string>; query: Record<string, string> } = $props()

  const isEdit = $derived(Boolean(params.id))

  const existing = resource(async () => (params.id ? api.get<{ data: Customer }>(`/customers/${params.id}`) : null))

  let name = $state('')
  let phone = $state('')
  let address = $state('')
  let pan = $state('')
  let limit = $state('')
  let filled = $state(false)

  $effect(() => {
    const c = existing.data?.data
    if (c && !filled) {
      name = c.name
      phone = c.phone ?? ''
      address = c.address ?? ''
      pan = c.pan ?? ''
      limit = c.credit_limit === null ? '' : fromPaisa(c.credit_limit)
      filled = true
    }
  })

  let nameError = $state<string | null>(null)
  let limitError = $state<string | null>(null)
  const save = action()

  /** Paisa, null for no limit, or 'bad' for text that is not an amount. */
  function parseLimit(): number | null | 'bad' {
    if (limit.trim() === '') return null
    const paisa = toPaisa(limit)
    return paisa === null ? 'bad' : paisa
  }

  async function submit(e: Event) {
    e.preventDefault()
    nameError = name.trim() ? null : tr('Type the customer name.', 'ग्राहकको नाम लेख्नुहोस्।')
    const parsed = parseLimit()
    limitError = parsed === 'bad' ? tr('Type an amount, for example 10,000.', 'रकम लेख्नुहोस्, जस्तै 10,000।') : null
    if (nameError || parsed === 'bad') return

    const body: Record<string, unknown> = {
      name: name.trim(),
      phone: phone.trim() || null,
      address: address.trim() || null,
      pan: pan.trim() || null,
    }
    if (session.isOwner) body.credit_limit = parsed

    const saved = await save.run(() =>
      isEdit ? api.patch<{ data: Customer }>(`/customers/${params.id}`, body) : api.post<{ data: Customer }>('/customers', body),
    )
    if (!saved) return
    toast('Customer saved', 'ग्राहक सेभ भयो')
    if (!isEdit && query.next === 'checkout') navigate(`/sell/checkout?customer=${saved.data.id}`)
    else navigate(`/customers/${isEdit ? params.id : saved.data.id}`)
  }

  let confirmOpen = $state(false)
  const remove = action()

  async function deleteCustomer() {
    const done = await remove.run(() => api.delete<{ message: string }>(`/customers/${params.id}`))
    if (!done) return
    confirmOpen = false
    toast('Customer deleted. Old bills keep the name.', 'ग्राहक हटाइयो। पुराना बिलमा नाम रहन्छ।')
    navigate('/customers')
  }
</script>

<form class="page narrow" onsubmit={submit}>
  {#if isEdit && existing.error}
    <ErrorCard error={existing.error} retry={existing.reload} />
  {:else if isEdit && !filled}
    <Skeleton rows={4} />
  {:else}
    <div class="form-grid">
      <Field label={tr('Name (required)', 'नाम (आवश्यक)')} error={nameError ?? save.field('name')}>
        <input placeholder={tr('e.g. Hari Thapa', 'जस्तै: हरि थापा')} autocomplete="off" bind:value={name} />
      </Field>

      <Field label={tr('Phone', 'फोन')} error={save.field('phone')}>
        <input type="tel" inputmode="tel" placeholder="98000000xx" bind:value={phone} />
      </Field>

      <Field label={tr('Address', 'ठेगाना')} error={save.field('address')} full>
        <textarea rows="2" placeholder={tr('Tole, ward, area', 'टोल, वडा, क्षेत्र')} bind:value={address}></textarea>
      </Field>

      <Field
        label={tr('PAN number (optional)', 'PAN नम्बर (ऐच्छिक)')}
        error={save.field('pan')}
        hint={tr('Only needed when the customer wants a VAT bill.', 'VAT बिल चाहिएमा मात्र भर्नुहोस्।')}
      >
        <input inputmode="numeric" placeholder="600000000" bind:value={pan} />
      </Field>

      {#if session.isOwner}
        <Field
          label={tr('Credit limit', 'उधारो सीमा')}
          error={limitError ?? save.field('credit_limit')}
          hint={tr(
            'Credit above this is refused at the sale. Leave empty for no limit. 0 means cash only.',
            'यो रकमभन्दा बढी उधारो बिक्रीमा रोकिन्छ। खाली छोड्दा सीमा हुँदैन। ० भए नगद मात्र।',
          )}
        >
          <div class="input-group">
            <span class="prefix">Rs</span>
            <input inputmode="numeric" placeholder="10,000" bind:value={limit} />
          </div>
        </Field>
      {/if}
    </div>

    {#if save.message}
      <div class="alert bad" style="margin-top:16px"><span class="ms">error</span><div>{save.message}</div></div>
    {/if}

    {#if isEdit && session.isOwner}
      <div class="list" style="margin-top:20px">
        <button type="button" class="row" onclick={() => (confirmOpen = true)}>
          <span class="icon-tile bad"><span class="ms">delete</span></span>
          <div class="row-main">
            <div class="row-title" style="color:var(--bad)">{tr('Delete customer', 'ग्राहक हटाउने')}</div>
            <div class="row-sub">{tr('Old bills keep the name.', 'पुराना बिलमा नाम रहन्छ।')}</div>
          </div>
        </button>
      </div>
    {/if}

    <div class="bottom-bar">
      <button class="btn btn-primary btn-lg btn-block" type="submit" disabled={save.busy}>
        <span class="ms">check</span><span>{save.busy ? tr('Saving…', 'सेभ हुँदैछ…') : tr('Save', 'सेभ गर्ने')}</span>
      </button>
    </div>

    <Sheet bind:open={confirmOpen} title={tr('Delete customer?', 'ग्राहक हटाउने हो?')}>
      <p class="muted">{tr('The customer will be hidden from lists and new sales. Old bills keep the name.', 'ग्राहक सूची र नयाँ बिक्रीबाट हट्छ। पुराना बिलमा नाम रहन्छ।')}</p>
      {#if remove.message}
        <div class="alert bad"><span class="ms">error</span><div>{remove.message}</div></div>
      {/if}
      <div class="hstack" style="justify-content:flex-end">
        <button type="button" class="btn btn-tonal" onclick={() => (confirmOpen = false)}>{tr('Cancel', 'रद्द')}</button>
        <button type="button" class="btn btn-danger" disabled={remove.busy} onclick={deleteCustomer}>
          <span class="ms">delete</span><span>{remove.busy ? tr('Deleting…', 'हटाउँदै…') : tr('Delete', 'हटाउने')}</span>
        </button>
      </div>
    </Sheet>
  {/if}
</form>
