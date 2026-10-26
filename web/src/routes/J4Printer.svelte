<script lang="ts">
  import { session } from '../lib/session.svelte'
  import { tr } from '../lib/i18n'
  import { rs } from '../lib/money'
</script>

<div class="page narrow">
  <div class="later-note">
    <span class="ms">schedule</span>
    <div>{tr('Planned after the first release. This is a preview only.', 'यो पहिलो रिलिजपछि आउनेछ। अहिले यो नमुना मात्र हो।')}</div>
  </div>

  <div class="alert info">
    <span class="ms">info</span>
    <div>
      {tr('You can print a bill from the browser today. Open a sale and use the Print button on its bill.', 'अहिले ब्राउजरबाट बिल प्रिन्ट गर्न सकिन्छ। बिक्री खोलेर बिलको प्रिन्ट बटन थिच्नुहोस्।')}
      <a href="#/sales">{tr('Open sales', 'बिक्री खोल्ने')}</a>
    </div>
  </div>

  <div class="section-title"><h3>{tr('Bluetooth printers', 'ब्लुटुथ प्रिन्टर')}</h3></div>
  <div class="list">
    <div class="row">
      <span class="icon-tile"><span class="ms">print</span></span>
      <div class="row-main"><div class="row-title">PR-58 Shop Printer</div><div class="row-sub">{tr('Paired, ready to print', 'जोडिएको, प्रिन्ट गर्न तयार')}</div></div>
      <span class="badge good">{tr('In use', 'चलिरहेको')}</span>
    </div>
    <div class="row">
      <span class="icon-tile"><span class="ms">print</span></span>
      <div class="row-main"><div class="row-title">CP-80 Counter Printer</div><div class="row-sub">{tr('Not paired yet', 'अहिलेसम्म जोडिएको छैन')}</div></div>
      <button class="btn btn-tonal btn-sm" type="button" disabled><span>{tr('Pair', 'जोड्ने')}</span></button>
    </div>
  </div>

  <section class="card stack">
    <h3>{tr('Paper size', 'कागजको साइज')}</h3>
    <div class="seg block">
      <button type="button" class="active" disabled>58mm</button>
      <button type="button" disabled>80mm</button>
    </div>
    <button class="btn btn-tonal btn-block btn-lg" type="button" disabled><span class="ms">print</span><span>{tr('Test print', 'टेस्ट प्रिन्ट')}</span></button>
  </section>

  <div class="section-title"><h3>{tr('Receipt preview', 'बिलको नमुना')}</h3></div>
  <section class="card" style="max-width:320px;margin:0 auto;width:100%">
    <div class="stack-sm" style="gap:2px;align-items:center;text-align:center">
      <span class="bold">{session.business?.name ?? 'PASAL'}</span>
      {#if session.business?.address}<span class="tiny muted">{session.business.address}</span>{/if}
      {#if session.business?.pan}<span class="tiny muted">PAN {session.business.pan}</span>{/if}
    </div>
    <div class="divider" style="margin:12px 0"></div>
    <div class="kv small">
      <div><span class="k">{tr('Bill', 'बिल')}</span><span class="v">S-0413</span></div>
      <div><span class="k">{tr('Basmati rice 5kg × 2', 'बासमती चामल ५ केजी × २')}</span><span class="v">{rs(210000)}</span></div>
      <div><span class="k">{tr('Sugar 1kg', 'चिनी १ केजी')}</span><span class="v">{rs(11500)}</span></div>
      <div><span class="k">{tr('VAT included', 'भ्याट सहित')}</span><span class="v">{rs(25482, { paisa: true })}</span></div>
      <div class="total"><span class="k">{tr('Total', 'जम्मा')}</span><span class="v">{rs(221500)}</span></div>
    </div>
    <p class="tiny muted center" style="margin-top:12px">{tr('Thank you. Please visit again.', 'धन्यवाद! फेरि आउनुहोस्।')}</p>
  </section>
</div>
