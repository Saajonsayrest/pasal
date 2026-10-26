<script lang="ts">
  import { api } from '../lib/api'
  import { action } from '../lib/resource.svelte'
  import { navigate } from '../lib/router.svelte'
  import { toast } from '../lib/toast.svelte'
  import { tr } from '../lib/i18n'
  import Field from '../components/Field.svelte'

  let { query }: { query: Record<string, string> } = $props()

  let password = $state('')
  let confirm = $state('')
  let show = $state(false)
  let tokenBad = $state(false)
  const save = action()

  const email = $derived(query.email ?? '')
  const token = $derived(query.token ?? '')
  const linkBad = $derived(!email || !token || tokenBad)

  const lengthError = $derived(
    password.length > 0 && (password.length < 10 || password.length > 100)
      ? tr('Use 10 to 100 characters.', 'कम्तीमा १० र बढीमा १०० अक्षर हुनुपर्छ।')
      : null,
  )
  const mismatch = $derived(confirm.length > 0 && confirm !== password ? tr('The two passwords do not match.', 'दुवै पासवर्ड मिलेनन्।') : null)
  const generalError = $derived(save.error && !save.error.field('password') && !save.error.field('token') ? save.error.message : null)

  async function submit(e: Event) {
    e.preventDefault()
    if (lengthError || mismatch) return
    const ok = await save.run(() => api.post('/reset-password', { email, token, password }))
    if (ok !== undefined) {
      toast('Password changed. Log in with the new one.', 'पासवर्ड बदलियो। नयाँ पासवर्डले लग इन गर्नुहोस्।')
      navigate('/login')
      return
    }
    if (save.error?.field('token')) tokenBad = true
  }
</script>

<form class="page narrow" onsubmit={submit}>
  <section class="stack-sm" style="margin-top:24px">
    <h1>{tr('Make a new password', 'नयाँ पासवर्ड बनाउने')}</h1>
    <p class="muted">{tr('Use at least 10 characters.', 'कम्तीमा १० अक्षर प्रयोग गर्नुहोस्।')}</p>
  </section>

  {#if linkBad}
    <div class="alert bad" style="margin-top:12px"><span class="ms">error</span><div>{tr('This link is wrong or expired', 'यो लिंक गलत वा म्याद सकिएको छ')}</div></div>
    <a class="btn btn-tonal btn-block" href="#/forgot-password">{tr('Ask for a new link', 'नयाँ लिंक माग्ने')}</a>
  {:else}
    <section class="card stack" style="margin-top:12px">
      <Field label={tr('New password', 'नयाँ पासवर्ड')} error={save.field('password') ?? lengthError}>
        <div class="input-group">
          <input type={show ? 'text' : 'password'} autocomplete="new-password" required bind:value={password} style="padding-right:96px" />
          <button class="btn btn-ghost btn-sm suffix" type="button" onclick={() => (show = !show)}>
            <span class="ms">{show ? 'visibility_off' : 'visibility'}</span><span>{show ? tr('Hide', 'लुकाउने') : tr('Show', 'देखाउने')}</span>
          </button>
        </div>
      </Field>
      <Field label={tr('Confirm new password', 'नयाँ पासवर्ड फेरि लेख्नुहोस्')} error={mismatch}>
        <input type={show ? 'text' : 'password'} autocomplete="new-password" required bind:value={confirm} />
      </Field>
      {#if generalError}
        <div class="alert bad"><span class="ms">error</span><div>{generalError}</div></div>
      {/if}
    </section>

    <div class="bottom-bar">
      <button class="btn btn-primary btn-lg btn-block" type="submit" disabled={save.busy || !password || !confirm}>
        <span class="ms">check</span><span>{save.busy ? tr('Saving…', 'सेभ हुँदैछ…') : tr('Save new password', 'नयाँ पासवर्ड सेभ गर्ने')}</span>
      </button>
    </div>
  {/if}
</form>
