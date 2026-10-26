<script lang="ts">
  import { api } from '../lib/api'
  import { action } from '../lib/resource.svelte'
  import { tr, num } from '../lib/i18n'
  import Field from '../components/Field.svelte'

  let email = $state('')
  let sent = $state(false)
  const save = action()

  async function submit(e: Event) {
    e.preventDefault()
    const ok = await save.run(() => api.post('/forgot-password', { email: email.trim() }))
    if (ok !== undefined) sent = true
  }
</script>

<div class="page narrow" style="padding-top:8px">
  <a class="btn btn-ghost btn-sm" href="#/login" style="align-self:flex-start;margin-left:-10px"><span class="ms">arrow_back</span><span>{tr('Back to log in', 'लग इनमा फर्कने')}</span></a>

  <section class="stack-sm">
    <h1>{tr('Forgot password?', 'पासवर्ड बिर्सनुभयो?')}</h1>
    <p class="muted">{tr('Enter your email. We will send a link to make a new password.', 'तपाईंको इमेल लेख्नुहोस्। हामी नयाँ पासवर्ड बनाउने लिंक पठाउँछौं।')}</p>
  </section>

  {#if sent}
    <div class="card stack" style="margin-top:12px">
      <div class="icon-tile good lg"><span class="ms">mark_email_read</span></div>
      <div class="stack-sm">
        <h2>{tr('Check your email', 'इमेल जाँच गर्नुहोस्')}</h2>
        <p class="muted">{tr('If the email has an account, a link is on its way.', 'इमेलसँग खाता भए, लिंक बाटोमा छ।')}</p>
        <p class="small muted">{tr(`The link works for ${num(60)} minutes.`, `लिंक ${num(60)} मिनेटसम्म चल्छ।`)}</p>
      </div>
      <a class="btn btn-tonal btn-block" href="#/login">{tr('Back to log in', 'लग इन गर्ने')}</a>
    </div>
  {:else}
    <form class="card stack" style="margin-top:12px" onsubmit={submit}>
      <Field label={tr('Email', 'इमेल')} error={save.field('email')}>
        <input type="email" autocomplete="username" required placeholder={tr('Your email', 'तपाईंको इमेल')} bind:value={email} />
      </Field>
      {#if save.message}
        <div class="alert bad"><span class="ms">error</span><div>{save.message}</div></div>
      {/if}
      <button class="btn btn-primary btn-lg btn-block" type="submit" disabled={save.busy || !email.trim()}>
        <span class="ms">send</span><span>{save.busy ? tr('Sending…', 'पठाउँदैछ…') : tr('Send reset link', 'रिसेट लिंक पठाउने')}</span>
      </button>
      <div class="alert"><span class="ms">info</span><div>{tr('Staff can also ask the shop owner to reset their password.', 'कर्मचारीले पनि पसलको मालिकलाई पासवर्ड रिसेट गर्न भन्न सक्नुहुन्छ।')}</div></div>
    </form>
  {/if}
</div>
