<script lang="ts">
  import { tr } from '../lib/i18n'
</script>

<div class="page narrow">
  <div class="later-note">
    <span class="ms">schedule</span>
    <div>{tr('Planned after the first release. Example only.', 'यो पहिलो रिलिजपछि आउने स्क्रिन हो। अहिले नमुना मात्र हो।')}</div>
  </div>

  <div class="alert info">
    <span class="ms">info</span>
    <div>{tr('Expiry dates need a change in the server first. The app does not save them yet.', 'म्याद मिति देखाउन पहिले सर्भरमा परिवर्तन चाहिन्छ। एपले अहिले मिति सुरक्षित गर्दैन।')}</div>
  </div>

  <div class="chips">
    <button class="chip" disabled>{tr('Expired', 'म्याद नाघेको')}</button>
    <button class="chip" disabled>{tr('This week', 'यो हप्ता')}</button>
    <button class="chip active" disabled>{tr('This month', 'यो महिना')}</button>
  </div>

  <div class="list">
    <div class="row">
      <span class="icon-tile emoji">🥛</span>
      <div class="row-main">
        <div class="row-title">{tr('Milk 500ml', 'दूध ५०० मिलि')}</div>
        <div class="row-sub">{tr('Batch MK-1182 · Expiry Kartik 5, 2083 · 22 Oct 2026', 'ब्याच MK-1182 · म्याद कात्तिक ५, २०८३ · 22 Oct 2026')}</div>
      </div>
      <div class="row-end"><span class="amount">{tr('6 pcs', '६ पिस')}</span><span class="badge bad">{tr('Expired', 'म्याद नाघ्यो')}</span></div>
    </div>
    <div class="row">
      <span class="icon-tile emoji">🍪</span>
      <div class="row-main">
        <div class="row-title">{tr('Biscuits', 'बिस्कुट')}</div>
        <div class="row-sub">{tr('Batch BS-0930 · Expiry Kartik 12, 2083 · 29 Oct 2026', 'ब्याच BS-0930 · म्याद कात्तिक १२, २०८३ · 29 Oct 2026')}</div>
      </div>
      <div class="row-end"><span class="amount">{tr('10 pcs', '१० पिस')}</span><span class="badge warn">{tr('3 days left', '३ दिन बाँकी')}</span></div>
    </div>
    <div class="row">
      <span class="icon-tile emoji">🥚</span>
      <div class="row-main">
        <div class="row-title">{tr('Eggs (tray of 30)', 'अण्डा (३० वटा)')}</div>
        <div class="row-sub">{tr('Batch EG-0717 · Expiry Kartik 20, 2083 · 6 Nov 2026', 'ब्याच EG-0717 · म्याद कात्तिक २०, २०८३ · 6 Nov 2026')}</div>
      </div>
      <div class="row-end"><span class="amount">{tr('4 pcs', '४ पिस')}</span><span class="tiny muted">{tr('11 days left', '११ दिन बाँकी')}</span></div>
    </div>
    <div class="row">
      <span class="icon-tile emoji">🍵</span>
      <div class="row-main">
        <div class="row-title">{tr('Tea leaves 500g', 'चियापत्ती ५०० ग्रा')}</div>
        <div class="row-sub">{tr('Batch TL-0601 · Expiry Kartik 30, 2083 · 16 Nov 2026', 'ब्याच TL-0601 · म्याद कात्तिक ३०, २०८३ · 16 Nov 2026')}</div>
      </div>
      <div class="row-end"><span class="amount">{tr('12 pcs', '१२ पिस')}</span><span class="tiny muted">{tr('21 days left', '२१ दिन बाँकी')}</span></div>
    </div>
  </div>
</div>

<style>
  .chip:disabled {
    opacity: 0.55;
    cursor: default;
  }
</style>
