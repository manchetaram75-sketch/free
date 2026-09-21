const rates = [
  { code:'USD', name:'دلار آمریکا', price:92450, change:0.8, type:'fiat', icon:'$', iconClass:'usd-icon' },
  { code:'EUR', name:'یورو اروپا', price:108760, change:1.2, type:'fiat', icon:'€', iconClass:'euro-icon' },
  { code:'GBP', name:'پوند انگلیس', price:126340, change:-0.3, type:'fiat', icon:'£', iconClass:'pound-icon' },
  { code:'AED', name:'درهم امارات', price:25180, change:0.6, type:'fiat', icon:'د', iconClass:'aed-icon' },
  { code:'TRY', name:'لیر ترکیه', price:2710, change:-1.1, type:'fiat', icon:'₺', iconClass:'try-icon' },
  { code:'CNY', name:'یوان چین', price:12740, change:.4, type:'fiat', icon:'¥', iconClass:'cny-icon' },
  { code:'JPY', name:'ین ژاپن', price:620, change:-.2, type:'fiat', icon:'¥', iconClass:'jpy-icon' },
  { code:'CAD', name:'دلار کانادا', price:68120, change:.9, type:'fiat', icon:'C$', iconClass:'cad-icon' },
  { code:'AUD', name:'دلار استرالیا', price:60280, change:.5, type:'fiat', icon:'A$', iconClass:'aud-icon' },
  { code:'INR', name:'روپیه هند', price:1105, change:-.4, type:'fiat', icon:'₹', iconClass:'inr-icon' },
  { code:'RUB', name:'روبل روسیه', price:1010, change:1.1, type:'fiat', icon:'₽', iconClass:'rub-icon' },
  { code:'SAR', name:'ریال عربستان', price:24650, change:.3, type:'fiat', icon:'ر', iconClass:'sar-icon' },
  { code:'BTC', name:'بیت‌کوین', price:10480000000, change:2.4, type:'crypto', icon:'₿', iconClass:'btc-icon' },
  { code:'ETH', name:'اتریوم', price:486500000, change:1.7, type:'crypto', icon:'◆', iconClass:'eth-icon' },
  { code:'USDT', name:'تتر', price:92590, change:0.1, type:'crypto', icon:'₮', iconClass:'usdt-icon' },
  { code:'SOL', name:'سولانا', price:12740000, change:3.8, type:'crypto', icon:'≋', iconClass:'sol-icon' },
];
const tomanFormatter = new Intl.NumberFormat('fa-IR', { maximumFractionDigits: 0 });
const decimalFormatter = new Intl.NumberFormat('fa-IR', { maximumFractionDigits: 2 });
let activeView = 'home';
let activeFilter = 'all';
let selectedFrom = rates[0];

function toman(value) { return tomanFormatter.format(Math.round(value)); }
function number(value) { return decimalFormatter.format(Number(value) || 0); }
function signedChange(value) { return `${value >= 0 ? '+' : ''}${decimalFormatter.format(value)}٪`; }
function iconMarkup(item) { return `<span class="asset-icon ${item.iconClass}">${item.icon}</span>`; }

function renderRates() {
  const query = (document.querySelector('#rateSearch')?.value || '').trim().toLowerCase();
  const list = document.querySelector('#ratesList');
  const filtered = rates.filter(item => (activeFilter === 'all' || item.type === activeFilter) &&
    (!query || item.name.toLowerCase().includes(query) || item.code.toLowerCase().includes(query)));
  list.innerHTML = filtered.map((item, index) => `
    <article class="rate-row" style="animation-delay:${index * 45}ms">
      ${iconMarkup(item)}
      <div class="rate-info"><strong>${item.name}</strong><small>${item.code}</small></div>
      <div class="rate-change ${item.change >= 0 ? 'trend up' : 'trend down'}">${signedChange(item.change)}</div>
      <div class="rate-price"><strong>${toman(item.price)}</strong><small>تومان</small></div>
    </article>`).join('') || `<div class="empty-state">ارزی با این مشخصات پیدا نشد.</div>`;
}

function setView(view) {
  if (view === 'more') { showToast('بخش تنظیمات به‌زودی آماده می‌شود'); return; }
  activeView = view;
  document.querySelectorAll('.view').forEach(node => node.classList.remove('is-active'));
  const target = document.querySelector(`#${view}View`);
  if (target) target.classList.add('is-active');
  document.querySelectorAll('.nav-item').forEach(node => node.classList.toggle('is-active', node.dataset.view === view));
  window.scrollTo({ top: 0, behavior: 'smooth' });
  if (view === 'rates') renderRates();
}

function updateConverter() {
  const input = document.querySelector('#amountInput');
  const raw = Number(String(input.value).replace(/,/g, '')) || 0;
  const result = document.querySelector('#conversionResult');
  const unit = document.querySelector('#fromUnit');
  const line = document.querySelector('.converter-result em');
  const price = selectedFrom.price;
  unit.textContent = selectedFrom.code;
  result.innerHTML = `${toman(raw * price)} <small>تومان</small>`;
  line.textContent = `۱ ${selectedFrom.code} = ${toman(price)} تومان`;
  document.querySelector('#fromName').textContent = selectedFrom.name;
  document.querySelector('#fromCode').textContent = selectedFrom.code;
  const fromIcon = document.querySelector('#fromIcon');
  fromIcon.textContent = selectedFrom.icon;
  fromIcon.className = `asset-icon ${selectedFrom.iconClass}`;
}

function showToast(text) {
  const toast = document.querySelector('#toast');
  toast.textContent = text; toast.classList.add('show');
  clearTimeout(window.toastTimer); window.toastTimer = setTimeout(() => toast.classList.remove('show'), 2200);
}

document.querySelectorAll('[data-view]').forEach(button => button.addEventListener('click', () => setView(button.dataset.view)));
document.querySelectorAll('.segment').forEach(button => button.addEventListener('click', () => {
  document.querySelectorAll('.segment').forEach(item => item.classList.remove('is-selected'));
  button.classList.add('is-selected'); activeFilter = button.dataset.filter; renderRates();
}));
document.querySelector('#rateSearch').addEventListener('input', renderRates);
document.querySelector('#amountInput').addEventListener('input', updateConverter);
document.querySelectorAll('.quick-amounts button').forEach(button => button.addEventListener('click', () => {
  document.querySelector('#amountInput').value = button.dataset.amount;
  document.querySelectorAll('.quick-amounts button').forEach(item => item.classList.remove('is-selected'));
  button.classList.add('is-selected'); updateConverter();
}));
document.querySelector('#swapCurrencies').addEventListener('click', () => {
  if (selectedFrom.code === 'USD') selectedFrom = rates.find(item => item.code === 'BTC');
  else selectedFrom = rates[0];
  updateConverter(); showToast(`مبدا به ${selectedFrom.name} تغییر کرد`);
});
document.querySelectorAll('.swap-button').forEach(button => button.addEventListener('click', () => showToast('ارزها جابجا شدند')));
document.querySelector('#fromPicker').addEventListener('click', () => {
  const currentIndex = rates.findIndex(item => item.code === selectedFrom.code);
  selectedFrom = rates[(currentIndex + 1) % 5]; updateConverter(); showToast(`تبدیل از ${selectedFrom.name}`);
});
document.querySelector('.filter-button').addEventListener('click', () => showToast('فیلتر پیشرفته به‌زودی آماده می‌شود'));
document.querySelector('.notification-button').addEventListener('click', () => showToast('اعلان جدیدی ندارید'));
renderRates(); updateConverter();
