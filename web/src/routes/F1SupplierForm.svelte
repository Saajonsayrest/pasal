<script lang="ts">
  import { api } from '../lib/api'
  import { resource, action } from '../lib/resource.svelte'
  import { navigate } from '../lib/router.svelte'
  import { toast } from '../lib/toast.svelte'
  import { tr } from '../lib/i18n'
  import type { Supplier } from '../lib/types'
  import Field from '../components/Field.svelte'
  import Sheet from '../components/Sheet.svelte'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'

  let { params }: { params: Record<string, string> } = $props()
  const id = $derived(params.id)

  const current = resource(async () => (id ? (await api.get<{ data: Supplier }>(`/suppliers/${id}`)).data : null))

  let name = $state('')
  let phone = $state('')
  let address = $state('')
  let pan = $state('')
  let note = $state('')
  let filled = false

  $effect(() => {
    const s = current.data
    if (!s || filled) return
    filled = true
    name = s.name
    phone = s.phone ?? ''
    address = s.address ?? ''
    pan = s.pan ?? ''
    note = s.note ?? ''
  })

  const ready = $derived(!id || !!current.data)
  const save = action()
  const removal = action()
  let confirmOpen = $state(false)

  function body() {
    return {
      name: name.trim(),
      phone: phone.trim() || null,
      address: address.trim() || null,
      pan: pan.trim() || null,
      note: note.trim() || null,
    }
  }

  async function submit(e: Event): Promise<void> {
    e.preventDefault()
    const saved = await save.run(() =>
      id ? api.patch<{ data: Supplier }>(`/suppliers/${id}`, body()) : api.post<{ data: Supplier }>('/suppliers', body()),
    )
    if (!saved) return
    toast('Supplier saved', 'डिलर सेभ भयो')
    navigate(`/suppliers/${saved.data.id}`, true)
  }

  async function remove(): Promise<void> {
    const done = await removal.run(() => api.delete<{ message: string }>(`/suppliers/${id}`))
    if (!done) return
    toast('Supplier deleted', 'डिलर हटाइयो')
    navigate('/suppliers', true)
  }
</script>

<form class="page narrow" onsubmit={submit}>
  {#if current.error}
    <ErrorCard error={current.error} retry={current.reload} />
  {:else if !ready}
    <Skeleton rows={4} />
  {:else}
    <div class="form-grid">
      <Field label={tr('Supplier name (required)', 'डिलरको नाम (आवश्यक)')} error={save.field('name')}>
        <input required placeholder={tr('For example: Everest Traders', 'जस्तै: एभरेस्ट ट्रेडर्स')} bind:value={name} />
      </Field>
      <Field label={tr('Phone', 'फोन')} error={save.field('phone')}>
        <input type="tel" inputmode="tel" placeholder="98000000xx" bind:value={phone} />
      </Field>
      <Field label={tr('Address', 'ठेगाना')} error={save.field('address')}>
        <textarea rows="2" bind:value={address}></textarea>
      </Field>
      <Field label={tr('PAN number (optional)', 'PAN नम्बर (ऐच्छिक)')} error={save.field('pan')}>
        <input inputmode="numeric" placeholder="600000000" bind:value={pan} />
      </Field>
      <Field label={tr('Note (optional)', 'नोट (ऐच्छिक)')} error={save.field('note')}>
        <textarea rows="2" placeholder={tr('For example: comes twice a week', 'जस्तै: हप्ताको दुई पटक आउँछन्')} bind:value={note}></textarea>
      </Field>
    </div>

    {#if save.message}
      <div class="alert bad"><span class="ms">error</span><div>{save.message}</div></div>
    {/if}

    {#if id}
      <div class="list" style="margin-top:20px">
        <button type="button" class="row" onclick={() => (confirmOpen = true)}>
          <span class="icon-tile bad"><span class="ms">delete</span></span>
          <div class="row-main">
            <div class="row-title" style="color:var(--bad)">{tr('Delete supplier', 'डिलर हटाउने')}</div>
            <div class="row-sub">{tr('Old purchases keep the name.', 'पुराना खरिदमा नाम रहन्छ।')}</div>
          </div>
        </button>
      </div>
    {/if}
  {/if}

  <div class="bottom-bar">
    <button class="btn btn-primary btn-lg btn-block" type="submit" disabled={save.busy || !ready || !name.trim()}>
      <span class="ms">check</span><span>{save.busy ? tr('Saving…', 'सेभ हुँदैछ…') : tr('Save', 'सेभ गर्ने')}</span>
    </button>
  </div>
</form>

<Sheet bind:open={confirmOpen} title={tr('Delete supplier?', 'डिलर हटाउने हो?')}>
  <p class="muted">{tr('The supplier will be hidden from lists and from new purchases. Old purchases keep the name.', 'डिलर सूचीबाट र नयाँ खरिदबाट लुक्नेछ। पुराना खरिदमा नाम रहन्छ।')}</p>
  {#if removal.message}
    <div class="alert bad"><span class="ms">error</span><div>{removal.message}</div></div>
  {/if}
  <button class="btn btn-danger btn-lg btn-block" type="button" disabled={removal.busy} onclick={remove}>
    <span class="ms">delete</span><span>{tr('Delete supplier', 'डिलर हटाउने')}</span>
  </button>
  <button class="btn btn-tonal btn-block" type="button" onclick={() => (confirmOpen = false)}>{tr('Keep supplier', 'डिलर राख्ने')}</button>
</Sheet>
