<script lang="ts">
  import { tr } from '../lib/i18n'
  import { rs } from '../lib/money'

  const reasons = [
    { en: 'Damaged', ne: 'क्षति भएको' },
    { en: 'Expired', ne: 'म्याद सकिएको' },
    { en: 'Wrong item', ne: 'गलत सामान' },
  ]
</script>

<div class="page narrow">
  <div class="later-note">
    <span class="ms">schedule</span>
    <span>{tr('Planned after the first release. Shown for review only.', 'यो पहिलो रिलिजपछि बन्ने योजना हो। अहिले समीक्षाका लागि मात्र।')}</span>
  </div>

  <div class="alert warn">
    <span class="ms">construction</span>
    <div>
      {tr('Purchase returns need a change on the server first. Until then, fix the stock by hand from the item page.', 'खरिद फिर्ताका लागि पहिले सर्भरमा परिवर्तन चाहिन्छ। तबसम्म सामानको पेजबाट स्टक हातले मिलाउनुहोस्।')}
    </div>
  </div>

  <a class="btn btn-tonal btn-block" href="#/items"><span class="ms">inventory_2</span><span>{tr('Go to items', 'सामानमा जाने')}</span></a>

  <div class="list">
    <button type="button" class="row" disabled>
      <span class="icon-tile info"><span class="ms">receipt_long</span></span>
      <div class="row-main">
        <div class="row-title">{tr('Choose purchase', 'खरिद छान्नुहोस्')}</div>
        <div class="row-sub">{tr('The bill with the goods to send back', 'फिर्ता पठाउने सामान भएको बिल')}</div>
      </div>
      <span class="ms chev">chevron_right</span>
    </button>
  </div>

  <div class="section-title"><h3>{tr('Items to send back', 'फिर्ता पठाउने सामान')}</h3></div>
  <div class="card">
    <p class="small muted center" style="margin:0">{tr('Items from the chosen bill appear here.', 'छानेको बिलका सामान यहाँ देखिन्छन्।')}</p>
  </div>

  <div class="section-title"><h3>{tr('Reason', 'कारण')}</h3></div>
  <div class="chips">
    {#each reasons as r, i (r.en)}
      <button type="button" class="chip" class:active={i === 0} disabled>{tr(r.en, r.ne)}</button>
    {/each}
  </div>

  <section class="card">
    <div class="kv">
      <div><span class="k">{tr('Goods value (before VAT)', 'सामानको मूल्य (भ्याट बाहेक)')}</span><span class="v">{rs(0)}</span></div>
      <div><span class="k">{tr('VAT', 'भ्याट')}</span><span class="v">{rs(0)}</span></div>
      <div class="total"><span class="k">{tr('We owe less', 'हामीले कम तिर्ने')}</span><span class="v good">{rs(0)}</span></div>
    </div>
  </section>

  <div class="alert warn">
    <span class="ms">inventory_2</span>
    <div>
      <div class="alert-title">{tr('Stock goes down', 'स्टक घट्छ')}</div>
      <div>{tr('Stock of the returned items goes down when you save.', 'सेभ गरेपछि फिर्ता गरिएका सामानको स्टक घट्छ।')}</div>
    </div>
  </div>

  <div class="bottom-bar">
    <button class="btn btn-primary btn-lg btn-block" type="button" disabled>
      <span class="ms">check</span><span>{tr('Save return', 'फिर्ता सेभ गर्ने')}</span>
    </button>
  </div>
</div>
