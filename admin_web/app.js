const API_BASE = (window.location.origin && window.location.origin.startsWith('http')) 
  ? window.location.origin + '/api' 
  : 'http://localhost:5000/api';


// Toast Notification
function showToast(message, type = 'success') {
  const container = document.getElementById('toast-container');
  if (!container) return;
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  toast.innerHTML = `
    <span>${type === 'success' ? '✅' : '⚠️'}</span>
    <span>${message}</span>
  `;
  container.appendChild(toast);
  setTimeout(() => {
    toast.remove();
  }, 3500);
}

// Format Currency
function formatInr(val) {
  return '₹' + Number(val || 0).toLocaleString('en-IN', { maximumFractionDigits: 1 });
}

// Tab Switching
document.querySelectorAll('.nav-tab-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.nav-tab-btn').forEach(b => b.classList.remove('active'));
    document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));
    btn.classList.add('active');
    const tabId = btn.getAttribute('data-tab');
    const targetPane = document.getElementById(tabId);
    if (targetPane) targetPane.classList.add('active');

    // Trigger tab-specific refresh
    if (tabId === 'tab-overview') loadOverview();
    if (tabId === 'tab-production') loadBatches();
    if (tabId === 'tab-inventory') loadInventory();
    if (tabId === 'tab-milling') loadMillingRates();
    if (tabId === 'tab-cash-audit') loadCashAudit();
    if (tabId === 'tab-expenses') loadExpenses();
    if (tabId === 'tab-bills') loadBills();
    if (tabId === 'tab-khata') loadKhata();
    if (tabId === 'tab-users') loadUsers();
    if (tabId === 'tab-online-orders') loadOnlineOrdersAdmin();
  });
});

// Modal Management Helpers
function setupModal(modalId, triggerIds, closeSelectors = ['.modal-close', '.modal-cancel']) {
  const modal = document.getElementById(modalId);
  if (!modal) return;
  triggerIds.forEach(id => {
    const btn = document.getElementById(id);
    if (btn) btn.addEventListener('click', () => modal.classList.add('active'));
  });
  modal.querySelectorAll(closeSelectors.join(',')).forEach(btn => {
    btn.addEventListener('click', () => modal.classList.remove('active'));
  });
  modal.addEventListener('click', (e) => {
    if (e.target === modal) modal.classList.remove('active');
  });
}

setupModal('modal-batch', ['btn-open-batch-modal', 'btn-trigger-batch-modal']);
setupModal('modal-bottling', ['btn-open-bottling-modal', 'btn-trigger-bottling-modal']);
setupModal('modal-expense', ['btn-open-expense-modal', 'btn-trigger-expense-modal']);
setupModal('modal-stock', []);
setupModal('modal-item-photo', []);
setupModal('modal-new-product', ['btn-open-new-product-modal']);
setupModal('modal-receive-payment', []);
setupModal('modal-customer-ledger', []);
setupModal('modal-new-customer', ['btn-open-new-customer-modal']);
setupModal('modal-milling-service', ['btn-open-milling-modal']);
setupModal('modal-batch-cost-breakdown', []);
setupModal('modal-new-material', []);
setupModal('modal-material-purchase', []);

// ==================== 1. OVERVIEW & P&L ====================
async function loadOverview() {
  const range = document.getElementById('pnl-range-select').value;
  try {
    // 1. Fetch Today Summary
    const sumRes = await fetch(`${API_BASE}/sales/today-summary`);
    const sumData = await sumRes.json();
    const summary = sumData.summary;

    document.getElementById('stat-total-sales').textContent = formatInr(summary.total_sales);
    document.getElementById('stat-bills-count').textContent = summary.total_bills;
    document.getElementById('stat-cash-sales').textContent = formatInr(summary.total_cash);
    document.getElementById('stat-upi-sales').textContent = formatInr(summary.total_upi);
    if (sumData.khata) {
      const khataDueEl = document.getElementById('stat-khata-due');
      const khataCountEl = document.getElementById('stat-khata-count');
      if (khataDueEl) khataDueEl.textContent = formatInr(sumData.khata.total_market_due);
      if (khataCountEl) khataCountEl.textContent = sumData.khata.customers_with_due;
    }

    // Milling Revenue from breakdown
    let millingSum = 0;
    if (sumData.breakdown) {
      const millingRow = sumData.breakdown.find(b => b.item_type === 'MILLING');
      if (millingRow) millingSum = millingRow.total;
    }
    document.getElementById('stat-milling-income').textContent = formatInr(millingSum);

    // 2. Fetch P&L Report for selected range
    const pnlRes = await fetch(`${API_BASE}/reports/pnl?range=${range}`);
    const pnl = await pnlRes.json();

    document.getElementById('pnl-retail-rev').textContent = formatInr(pnl.revenue.retail_sales);
    document.getElementById('pnl-milling-rev').textContent = formatInr(pnl.revenue.milling_charges);
    document.getElementById('pnl-total-rev').textContent = formatInr(pnl.revenue.total_revenue);

    document.getElementById('pnl-cogs').textContent = formatInr(pnl.costs.cost_of_goods_sold);
    document.getElementById('pnl-expenses').textContent = formatInr(pnl.costs.operating_expenses);
    document.getElementById('pnl-total-costs').textContent = formatInr(pnl.costs.total_costs);

    const netProfit = pnl.profitability.net_profit;
    const margin = pnl.profitability.profit_margin_percentage;
    document.getElementById('stat-net-profit').textContent = formatInr(netProfit);
    document.getElementById('stat-profit-margin').textContent = `${margin}%`;
    document.getElementById('pnl-clean-net').textContent = formatInr(netProfit);
    document.getElementById('pnl-margin-badge').textContent = `${margin}%`;

    const banner = document.getElementById('pnl-net-banner');
    const statusBadge = document.getElementById('pnl-status-badge');
    if (netProfit >= 0) {
      banner.classList.remove('loss');
      statusBadge.className = 'badge badge-success';
      statusBadge.textContent = 'Profitable';
    } else {
      banner.classList.add('loss');
      statusBadge.className = 'badge badge-danger';
      statusBadge.textContent = 'Operating at Loss';
    }

    // Top selling list
    const topContainer = document.getElementById('top-selling-list');
    if (pnl.top_items && pnl.top_items.length > 0) {
      topContainer.innerHTML = pnl.top_items.map(item => `
        <div style="display: flex; justify-content: space-between; padding: 0.4rem 0; border-bottom: 1px dashed rgba(255,255,255,0.08);">
          <span>${item.name} (${item.total_qty} units)</span>
          <strong style="color: var(--primary);">${formatInr(item.total_amount)}</strong>
        </div>
      `).join('');
    } else {
      topContainer.innerHTML = '<span style="color: var(--text-dim);">No sales recorded yet for this period.</span>';
    }

  } catch (err) {
    console.error('Failed to load overview:', err);
  }
}

document.getElementById('pnl-range-select').addEventListener('change', loadOverview);

// ==================== 2. PRODUCTION BATCHES & BOTTLE COSTING ====================
async function loadBatches() {
  try {
    const res = await fetch(`${API_BASE}/production/oil-batches`);
    const batches = await res.json();
    const tbody = document.querySelector('#batches-table tbody');
    if (batches.length === 0) {
      tbody.innerHTML = `<tr><td colspan="8" style="text-align:center; color: var(--text-dim); padding: 2rem;">No crushing batches recorded yet. Click 'New Crushing Batch' above to log a batch.</td></tr>`;
      return;
    }

    tbody.innerHTML = batches.map(b => {
      const seedCost = (b.seed_input_kg * b.seed_cost_per_kg);
      const transportCost = Number(b.transport_cost || (b.seed_input_kg * 1.5));
      const procCost = Number(b.processing_cost || 150);
      const cakeRecovery = (b.cake_output_kg * 35);
      const grossCost = seedCost + transportCost + procCost;
      const netBulkCost = Math.max(0, grossCost - cakeRecovery);
      
      const grossOil = Number(b.oil_output_litres || 0);
      const pureLitres = Math.max(0.1, Number((grossOil * 0.96).toFixed(2)));
      const costPerLtr = pureLitres > 0 ? (netBulkCost / pureLitres).toFixed(1) : '0';
      const bottleCost1L = (Number(costPerLtr) + 12.50).toFixed(1);

      const runTimeStr = b.start_time && b.end_time 
        ? `${b.start_time} - ${b.end_time} (${b.duration_minutes || 105}m)`
        : `${b.duration_minutes || 105} mins (₹${procCost})`;

      return `
        <tr>
          <td>
            <strong>${b.batch_date}</strong><br>
            <small style="color: var(--text-dim); font-size: 0.75rem;">Batch #${b.id} • ${b.tin_label || 'Drum #' + b.id}</small>
          </td>
          <td><span class="badge badge-oil">${b.seed_name}</span></td>
          <td>
            <strong>${b.seed_input_kg} kg</strong><br>
            <small style="color: var(--text-muted); font-size: 0.78rem;">@ ₹${b.seed_cost_per_kg}/kg + ₹${transportCost.toFixed(0)} freight</small>
          </td>
          <td>
            <span style="font-size: 0.82rem; color: #38BDF8;">⏱️ ${runTimeStr}</span><br>
            <small style="color: var(--text-dim); font-size: 0.75rem;">5HP Power + Labor: ₹${procCost}</small>
          </td>
          <td>
            <strong style="color: var(--primary); font-size: 0.95rem;">${b.oil_output_litres.toFixed(1)} L Oil</strong><br>
            <small style="color: #34D399; font-size: 0.78rem;">${b.cake_output_kg} kg Cake (${b.extraction_percentage}% Yield)</small>
          </td>
          <td>
            <strong style="color: var(--brand-gold-bright); font-size: 1rem;">₹${costPerLtr} / L</strong><br>
            <small style="color: var(--text-dim); font-size: 0.72rem;">(Less Cake Rev ₹${cakeRecovery.toFixed(0)})</small>
          </td>
          <td>
            <strong style="color: var(--warning); font-size: 0.95rem;">₹${bottleCost1L}</strong><br>
            <small style="color: var(--success); font-weight: 600; font-size: 0.75rem;">Profit: ~₹55 - ₹72 / L</small>
          </td>
          <td>
            <button class="btn btn-secondary btn-sm" onclick="openBatchCostModal(${b.id})" style="padding: 0.4rem 0.75rem; font-size: 0.82rem; display: flex; align-items: center; gap: 0.35rem; border-color: rgba(211, 151, 21, 0.4);">
              <span>🔍 View Breakdown</span>
            </button>
          </td>
        </tr>
      `;
    }).join('');

    // Also update top Live Summary cards with latest batch if available
    if (batches.length > 0) {
      const latest = batches[0];
      fetch(`${API_BASE}/production/batch-cost-breakdown/${latest.id}`)
        .then(r => r.json())
        .then(d => {
          if (d.cost_1L && document.getElementById('summary-cost-1l')) {
            document.getElementById('summary-cost-1l').textContent = `₹${d.cost_1L.total_production_cost.toFixed(2)}`;
            document.getElementById('summary-mrp-1l').textContent = `₹${d.cost_1L.selling_price.toFixed(2)}`;
            document.getElementById('summary-profit-1l').textContent = `+₹${d.cost_1L.net_profit_per_bottle.toFixed(2)} (${d.cost_1L.margin_pct}% Margin)`;
          }
          if (d.cost_500ml && document.getElementById('summary-cost-500ml')) {
            document.getElementById('summary-cost-500ml').textContent = `₹${d.cost_500ml.total_production_cost.toFixed(2)}`;
            document.getElementById('summary-mrp-500ml').textContent = `₹${d.cost_500ml.selling_price.toFixed(2)}`;
            document.getElementById('summary-profit-500ml').textContent = `+₹${d.cost_500ml.net_profit_per_bottle.toFixed(2)} (${d.cost_500ml.margin_pct}% Margin)`;
          }
          if (d.cost_5L && document.getElementById('summary-cost-5l')) {
            document.getElementById('summary-cost-5l').textContent = `₹${d.cost_5L.total_production_cost.toFixed(2)}`;
            document.getElementById('summary-mrp-5l').textContent = `₹${d.cost_5L.selling_price.toFixed(2)}`;
            document.getElementById('summary-profit-5l').textContent = `+₹${d.cost_5L.net_profit_per_bottle.toFixed(2)} (${d.cost_5L.margin_pct}% Margin)`;
          }
        }).catch(err => console.error(err));
    }
  } catch (err) {
    console.error('Failed to load batches:', err);
  }
}

// Track current viewing batch for 1-click sync
window.currentViewingBatchId = null;

// Open Cost Breakdown Modal
window.openBatchCostModal = async function(batchId) {
  try {
    window.currentViewingBatchId = batchId;
    const res = await fetch(`${API_BASE}/production/batch-cost-breakdown/${batchId}`);
    if (!res.ok) throw new Error('Failed to load breakdown');
    const data = await res.json();
    const b = data.batch;

    document.getElementById('cost-modal-title').innerHTML = `<span>🔍 Production Cost Breakdown (Batch #${b.id})</span>`;
    document.getElementById('cost-modal-subtitle').textContent = 
      `Date: ${b.batch_date} • Seed: ${b.seed_name} • Input: ${b.seed_input_kg} Kg • Drum: ${b.tin_label || 'Drum #' + b.id}`;

    document.getElementById('cost-detail-seed-badge').textContent = b.seed_name;
    document.getElementById('cost-detail-seeds').textContent = 
      `${b.seed_input_kg} kg × ₹${b.seed_cost_per_kg} = ₹${formatNum(data.raw_seeds_cost)}`;
    document.getElementById('cost-detail-transport').textContent = 
      `₹${formatNum(data.transport_cost)} (${(data.transport_cost / (b.seed_input_kg || 1)).toFixed(2)}/kg freight)`;

    document.getElementById('cost-detail-power').textContent = 
      `${data.power_units} Units = ₹${formatNum(data.power_cost)}`;
    document.getElementById('cost-detail-power-sub').textContent = 
      `5HP Motor (3.73 kW) @ ${data.duration_minutes} mins @ ₹10/unit power`;

    document.getElementById('cost-detail-labor').textContent = `₹${formatNum(data.labor_cost)}`;
    if (document.getElementById('cost-detail-labor-sub')) {
      document.getElementById('cost-detail-labor-sub').textContent = 
        `Labor: ₹400/day proportional for ${data.duration_minutes} mins`;
    }

    document.getElementById('cost-detail-gross-cost').textContent = `₹${formatNum(data.gross_cost)}`;

    document.getElementById('cost-detail-cake').textContent = 
      `${data.cake_output_kg} kg × ₹${data.cake_rate_per_kg} = -₹${formatNum(data.cake_recovery_value)}`;

    const grossLitres = Number(b.oil_output_litres || 0);
    document.getElementById('cost-detail-sludge').textContent = 
      `${grossLitres.toFixed(1)} L - ${data.sludge_litres} L sludge (4%) = ${data.pure_settled_litres} L Pure Oil`;

    document.getElementById('cost-detail-bulk-per-ltr').textContent = `₹${data.cost_per_bulk_litre} / Litre`;
    document.getElementById('cost-detail-bulk-math').textContent = 
      `(Net Cost ₹${formatNum(data.net_bulk_oil_cost)} ÷ ${data.pure_settled_litres} Litres Pure Oil)`;

    // Packaging matrix table rows
    const tbody = document.getElementById('cost-modal-pack-rows');
    const packs = [
      { name: '🍾 1 Litre Bottle', d: data.cost_1L, badge: 'badge-oil' },
      { name: '🧴 500 ml Bottle', d: data.cost_500ml, badge: 'badge-oil' },
      { name: '🛢️ 5 Litre Family Can', d: data.cost_5L, badge: 'badge-success' }
    ];

    tbody.innerHTML = packs.map(p => `
      <tr style="border-bottom: 1px solid rgba(255,255,255,0.06);">
        <td><strong style="color: var(--text-main); font-size: 0.95rem;">${p.name}</strong></td>
        <td>₹${formatNum(p.d.oil_cost)} <br><span style="font-size:0.75rem; color:var(--text-dim);">(${p.d.oil_volume} Oil)</span></td>
        <td>₹${formatNum(p.d.bottle_cap_cost)}</td>
        <td>₹${formatNum(p.d.label_cost)}</td>
        <td>₹${formatNum(p.d.packing_labor)}</td>
        <td><strong style="color: var(--warning); font-size: 1rem;">₹${formatNum(p.d.total_production_cost)}</strong></td>
        <td><strong style="color: var(--text-main); font-size: 0.95rem;">₹${formatNum(p.d.selling_price)}</strong></td>
        <td><strong style="color: var(--success); font-size: 1rem;">+₹${formatNum(p.d.net_profit_per_bottle)}</strong></td>
        <td><span class="badge ${p.d.margin_pct >= 20 ? 'badge-success' : 'badge-oil'}">${p.d.margin_pct}% Margin</span></td>
      </tr>
    `).join('');

    const modal = document.getElementById('modal-batch-cost-breakdown');
    if (modal) modal.classList.add('active');
  } catch (err) {
    console.error('Error loading cost breakdown:', err);
    showToast('Failed to load batch cost breakdown', 'error');
  }
};

window.syncCurrentBatchToInventory = async function() {
  if (!window.currentViewingBatchId) return;
  try {
    const res = await fetch(`${API_BASE}/production/sync-batch-cost-to-inventory/${window.currentViewingBatchId}`, {
      method: 'POST'
    });
    const data = await res.json();
    if (data.success) {
      showToast(data.message || 'Inventory cost price updated successfully!');
      loadInventory();
      loadBatches();
      loadOverview();
    } else {
      showToast(data.error || 'Failed to sync inventory costs', 'error');
    }
  } catch (err) {
    showToast('Failed to sync inventory costs', 'error');
  }
};

window.syncAllOilCostsToInventory = async function() {
  try {
    const res = await fetch(`${API_BASE}/production/sync-all-inventory-costs`, {
      method: 'POST'
    });
    const data = await res.json();
    if (data.success) {
      showToast(data.message || 'All oil production costs synced to inventory!');
      loadInventory();
      loadOverview();
    } else {
      showToast(data.error || 'Failed to sync mill costs', 'error');
    }
  } catch (err) {
    showToast('Failed to sync mill costs', 'error');
  }
};

window.printCostSheet = function() {
  window.print();
};

function formatNum(val) {
  if (val === null || val === undefined || isNaN(val)) return '0.00';
  return Number(val).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

document.getElementById('form-batch').addEventListener('submit', async (e) => {
  e.preventDefault();
  const startTime = document.getElementById('batch-start-time')?.value || null;
  const endTime = document.getElementById('batch-end-time')?.value || null;
  let durationMins = null;
  if (startTime && endTime) {
    const [sh, sm] = startTime.split(':').map(Number);
    const [eh, em] = endTime.split(':').map(Number);
    durationMins = Math.max(10, (eh * 60 + em) - (sh * 60 + sm));
  }

  const payload = {
    seed_name: document.getElementById('batch-seed-name').value,
    seed_input_kg: document.getElementById('batch-seed-kg').value,
    seed_cost_per_kg: document.getElementById('batch-seed-cost').value,
    transport_cost: document.getElementById('batch-transport-cost')?.value || 30,
    oil_output_litres: document.getElementById('batch-oil-litres').value,
    cake_output_kg: document.getElementById('batch-cake-kg').value,
    processing_cost: document.getElementById('batch-proc-cost').value,
    start_time: startTime,
    end_time: endTime,
    duration_minutes: durationMins,
    notes: document.getElementById('batch-notes').value
  };

  try {
    const res = await fetch(`${API_BASE}/production/oil-batch`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    const data = await res.json();
    if (data.success) {
      showToast(`Oil crushing batch saved successfully! Extraction Yield: ${data.extraction_percentage}%`);
      document.getElementById('modal-batch').classList.remove('active');
      document.getElementById('form-batch').reset();
      loadBatches();
      loadInventory();
      loadOverview();
    }
  } catch (err) {
    showToast('Failed to record oil batch', 'error');
  }
});

// ==================== 3. INVENTORY & BOTTLING ====================
async function loadInventory() {
  try {
    // 1. Retail Items
    const res = await fetch(`${API_BASE}/items`);
    const items = await res.json();
    const tbody = document.querySelector('#inventory-table tbody');

    // Populate Bottling dropdown
    const bottlingSelect = document.getElementById('bottling-item-id');
    bottlingSelect.innerHTML = items.filter(i => i.category === 'OIL').map(i => `
      <option value="${i.id}">${i.name} - Current Stock: ${i.stock_qty} ${i.unit}</option>
    `).join('');

    tbody.innerHTML = items.map(item => {
      const margin = item.selling_price > 0 
        ? (((item.selling_price - item.cost_price) / item.selling_price) * 100).toFixed(0)
        : 0;
      const isLow = item.stock_qty <= item.low_stock_threshold;

      let catBadge = 'badge-oil';
      if (item.category === 'REPACK') catBadge = 'badge-repack';
      if (item.category === 'SNACK') catBadge = 'badge-snack';
      if (item.category === 'CAKE') catBadge = 'badge-cake';

      return `
        <tr>
          <td>
            <img src="${item.image_url || 'logo.png'}" alt="${item.name}" 
                 style="width: 44px; height: 44px; object-fit: cover; border-radius: 8px; border: 1px solid var(--border); cursor: pointer; display: block; background: #fff;" 
                 onclick="openPhotoModal(${item.id}, '${item.name.replace(/'/g, "\\'")}', '${item.image_url || ''}')"
                 onerror="this.src='logo.png'" title="Click to view/change photo">
          </td>
          <td>
            <strong>${item.name}</strong>
          </td>
          <td><span class="badge ${catBadge}">${item.category}</span></td>
          <td><strong>${formatInr(item.selling_price)}</strong></td>
          <td>
            <strong style="color: ${item.category === 'OIL' || item.category === 'CAKE' ? 'var(--brand-gold-bright)' : 'var(--text-main)'}; font-size: 0.95rem;">
              ${formatInr(item.cost_price)}
            </strong>
            ${(item.category === 'OIL' || item.category === 'CAKE') ? '<small style="display:block; color: #4ADE80; font-size: 0.72rem; font-weight:600;">✓ Mill Cost</small>' : ''}
          </td>
          <td>
            <span class="badge ${margin >= 20 ? 'badge-success' : 'badge-oil'}">
              +${margin}% <small>(+₹${(item.selling_price - item.cost_price).toFixed(0)})</small>
            </span>
          </td>
          <td>
            <strong style="font-size: 1rem; color: ${isLow ? 'var(--danger)' : 'var(--text-main)'};">
              ${item.stock_qty} ${item.unit}
            </strong>
          </td>
          <td>
            ${isLow ? '<span class="badge badge-danger">⚠️ Low Stock</span>' : '<span class="badge badge-success">In Stock</span>'}
          </td>
          <td>
            <div style="display: flex; gap: 0.35rem;">
              <button class="btn btn-secondary btn-sm" onclick="openStockEdit(${item.id}, '${item.name.replace(/'/g, "\\'")}', ${item.stock_qty}, ${item.selling_price}, ${item.cost_price})" title="Adjust Stock & Price">
                ✏️ Edit
              </button>
              <button class="btn btn-primary btn-sm" onclick="openPhotoModal(${item.id}, '${item.name.replace(/'/g, "\\'")}', '${item.image_url || ''}')" title="Change Photo">
                📷 Photo
              </button>
            </div>
          </td>
        </tr>
      `;
    }).join('');

    // 2. Raw Materials
    const rawRes = await fetch(`${API_BASE}/raw-materials`);
    window.allRawMaterialsList = await rawRes.json();
    renderRawMaterialsTable();

    // Populate purchase material dropdown
    const purchaseMatSelect = document.getElementById('purchase-mat-id');
    if (purchaseMatSelect) {
      purchaseMatSelect.innerHTML = window.allRawMaterialsList.map(r => `
        <option value="${r.id}">
          ${r.type === 'PACKAGING' ? '📦' : '🥜'} ${r.name} - In-Stock: ${r.stock_qty} ${r.unit} (@ ₹${r.avg_cost_per_unit})
        </option>
      `).join('');
    }

  } catch (err) {
    console.error('Failed to load inventory:', err);
  }
}

// Raw Materials State & Filter
window.allRawMaterialsList = [];
window.currentRawMaterialFilter = 'ALL';

function renderRawMaterialsTable() {
  const rawTbody = document.querySelector('#raw-materials-table tbody');
  if (!rawTbody) return;

  const filtered = (window.allRawMaterialsList || []).filter(r => {
    if (window.currentRawMaterialFilter === 'ALL') return true;
    return r.type === window.currentRawMaterialFilter;
  });

  if (filtered.length === 0) {
    rawTbody.innerHTML = `<tr><td colspan="6" style="text-align:center; color: var(--text-dim); padding: 2rem;">No raw materials found in this category. Click '➕ Add Material' above.</td></tr>`;
    return;
  }

  rawTbody.innerHTML = filtered.map(r => {
    let typeBadge = 'badge-oil';
    let typeLabel = '🥜 Oil Seeds';
    if (r.type === 'PACKAGING') {
      typeBadge = 'badge-repack';
      typeLabel = '📦 Packaging';
    } else if (r.type === 'BULK_FOOD') {
      typeBadge = 'badge-snack';
      typeLabel = '🌾 Grains & Pulses';
    }

    const totalValue = (Number(r.stock_qty || 0) * Number(r.avg_cost_per_unit || 0)).toFixed(2);
    const isLow = r.stock_qty <= (r.unit === 'piece' ? 50 : 20);

    return `
      <tr>
        <td>
          <strong style="color: var(--text-main); font-size: 0.95rem;">${r.name}</strong>
        </td>
        <td><span class="badge ${typeBadge}">${typeLabel}</span></td>
        <td>
          <strong style="color: ${isLow ? 'var(--danger)' : 'var(--primary)'}; font-size: 1rem;">
            ${r.stock_qty} ${r.unit}
          </strong>
          ${isLow ? '<small style="display:block; color:var(--danger); font-size:0.7rem; font-weight:600;">⚠️ Low Stock (Reorder)</small>' : ''}
        </td>
        <td>
          <strong style="color: var(--text-main);">₹${Number(r.avg_cost_per_unit || 0).toFixed(2)}</strong>
          <small style="color: var(--text-dim); font-size: 0.75rem;">/ ${r.unit}</small>
        </td>
        <td>
          <strong style="color: var(--brand-gold-bright);">₹${formatNum(totalValue)}</strong>
        </td>
        <td>
          <div style="display: flex; gap: 0.35rem; flex-wrap: wrap;">
            <button class="btn btn-secondary btn-sm" onclick="openMaterialPurchase(${r.id})" style="border-color: rgba(56, 189, 248, 0.45); color: #38BDF8; padding: 0.35rem 0.65rem;" title="Record Inward Purchase">
              📥 +Purchase
            </button>
            <button class="btn btn-secondary btn-sm" onclick="openMaterialEdit(${r.id})" style="padding: 0.35rem 0.65rem;" title="Edit Material Details">
              ✏️
            </button>
            <button class="btn btn-danger btn-sm" onclick="deleteMaterial(${r.id}, '${r.name.replace(/'/g, "\\'")}')" style="padding: 0.35rem 0.65rem;" title="Delete">
              🗑️
            </button>
          </div>
        </td>
      </tr>
    `;
  }).join('');
}

// Setup Raw Material Filter buttons
document.querySelectorAll('.mat-filter-btn').forEach(btn => {
  btn.addEventListener('click', (e) => {
    document.querySelectorAll('.mat-filter-btn').forEach(b => b.classList.remove('active'));
    e.target.classList.add('active');
    window.currentRawMaterialFilter = e.target.dataset.filter;
    renderRawMaterialsTable();
  });
});

window.openNewMaterialModal = function() {
  document.getElementById('form-new-material')?.reset();
  const editIdEl = document.getElementById('material-edit-id');
  if (editIdEl) editIdEl.value = '';
  const titleEl = document.getElementById('modal-material-title');
  if (titleEl) titleEl.textContent = '➕ Add Raw Material or Packaging Item';
  document.getElementById('modal-new-material')?.classList.add('active');
};

window.openMaterialPurchase = function(matId) {
  const modal = document.getElementById('modal-material-purchase');
  if (!modal) return;
  const select = document.getElementById('purchase-mat-id');
  if (select) {
    if (matId) {
      select.value = matId;
    } else if (select.value) {
      matId = Number(select.value);
    } else if (select.options.length > 0) {
      matId = Number(select.options[0].value);
      select.value = matId;
    }
  }
  document.getElementById('purchase-qty').value = '';
  document.getElementById('purchase-rate').value = '';
  document.getElementById('purchase-transport').value = '0';
  document.getElementById('purchase-supplier').value = '';
  document.getElementById('purchase-bill-no').value = '';
  const dateInput = document.getElementById('purchase-date');
  if (dateInput) dateInput.value = new Date().toISOString().slice(0, 10);
  document.getElementById('purchase-total-preview').textContent = '₹0.00';

  // If item selected, pre-fill current rate
  if (matId) {
    const mat = (window.allRawMaterialsList || []).find(m => m.id == matId);
    if (mat && mat.avg_cost_per_unit != null) {
      document.getElementById('purchase-rate').value = mat.avg_cost_per_unit;
    }
  }

  modal.classList.add('active');
};

document.getElementById('btn-open-new-material-modal')?.addEventListener('click', () => {
  window.openNewMaterialModal();
});

document.getElementById('btn-open-material-purchase-modal')?.addEventListener('click', () => {
  window.openMaterialPurchase();
});

document.getElementById('purchase-mat-id')?.addEventListener('change', (e) => {
  const selId = Number(e.target.value);
  const mat = (window.allRawMaterialsList || []).find(m => m.id === selId);
  if (mat && mat.avg_cost_per_unit != null) {
    document.getElementById('purchase-rate').value = mat.avg_cost_per_unit;
  }
  updatePurchasePreview();
});

window.openMaterialEdit = function(matId) {
  const mat = (window.allRawMaterialsList || []).find(m => m.id === matId);
  if (!mat) return;
  document.getElementById('material-edit-id').value = mat.id;
  document.getElementById('modal-material-title').textContent = '✏️ Edit Raw Material / Packaging Item';
  document.getElementById('material-name').value = mat.name;
  document.getElementById('material-name-te').value = mat.name_te || '';
  document.getElementById('material-type').value = mat.type;
  document.getElementById('material-unit').value = mat.unit;
  document.getElementById('material-stock-qty').value = mat.stock_qty;
  document.getElementById('material-cost-per-unit').value = mat.avg_cost_per_unit;
  document.getElementById('modal-new-material').classList.add('active');
};

window.deleteMaterial = async function(matId, name) {
  if (!confirm(`Are you sure you want to delete material: "${name}"?`)) return;
  try {
    const res = await fetch(`${API_BASE}/raw-materials/${matId}`, { method: 'DELETE' });
    if (res.ok) {
      showToast(`Material "${name}" deleted`);
      loadInventory();
    }
  } catch (err) {
    showToast('Failed to delete material', 'error');
  }
};

// Purchase modal live calculation preview
function updatePurchasePreview() {
  const qty = Number(document.getElementById('purchase-qty')?.value || 0);
  const rate = Number(document.getElementById('purchase-rate')?.value || 0);
  const transport = Number(document.getElementById('purchase-transport')?.value || 0);
  const total = (qty * rate) + transport;
  const preview = document.getElementById('purchase-total-preview');
  if (preview) {
    preview.textContent = `₹${formatNum(total)}`;
  }
}
['purchase-qty', 'purchase-rate', 'purchase-transport'].forEach(id => {
  const el = document.getElementById(id);
  if (el) el.addEventListener('input', updatePurchasePreview);
});

// Submit Form: New Raw Material
document.getElementById('form-new-material')?.addEventListener('submit', async (e) => {
  e.preventDefault();
  const editId = document.getElementById('material-edit-id').value;
  const payload = {
    name: document.getElementById('material-name').value,
    name_te: document.getElementById('material-name-te').value,
    type: document.getElementById('material-type').value,
    unit: document.getElementById('material-unit').value,
    stock_qty: Number(document.getElementById('material-stock-qty').value || 0),
    avg_cost_per_unit: Number(document.getElementById('material-cost-per-unit').value || 0)
  };

  try {
    const url = editId ? `${API_BASE}/raw-materials/${editId}` : `${API_BASE}/raw-materials`;
    const method = editId ? 'PUT' : 'POST';
    const res = await fetch(url, {
      method,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    if (res.ok) {
      showToast(editId ? 'Material updated successfully!' : 'New material saved successfully!');
      document.getElementById('modal-new-material').classList.remove('active');
      document.getElementById('form-new-material').reset();
      document.getElementById('material-edit-id').value = '';
      loadInventory();
    }
  } catch (err) {
    showToast('Failed to save raw material', 'error');
  }
});

// Submit Form: Record Material Purchase
document.getElementById('form-material-purchase')?.addEventListener('submit', async (e) => {
  e.preventDefault();
  const matId = document.getElementById('purchase-mat-id').value;
  const payload = {
    purchase_qty: document.getElementById('purchase-qty').value,
    purchase_rate: document.getElementById('purchase-rate').value,
    transport_cost: document.getElementById('purchase-transport').value,
    supplier_name: document.getElementById('purchase-supplier').value,
    bill_number: document.getElementById('purchase-bill-no').value,
    log_as_expense: document.getElementById('purchase-log-expense').checked
  };

  try {
    const res = await fetch(`${API_BASE}/raw-materials/${matId}/inward-purchase`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    const data = await res.json();
    if (data.success) {
      showToast(data.message || 'Inward purchase recorded successfully!');
      document.getElementById('modal-material-purchase').classList.remove('active');
      document.getElementById('form-material-purchase').reset();
      loadInventory();
      loadOverview();
    }
  } catch (err) {
    showToast('Failed to record material purchase', 'error');
  }
});

window.openStockEdit = function(id, name, currentQty, price, cost) {
  document.getElementById('stock-item-id').value = id;
  document.getElementById('stock-item-name').value = name;
  document.getElementById('stock-item-qty').value = currentQty;
  document.getElementById('stock-item-price').value = price || 0;
  document.getElementById('stock-item-cost').value = cost || 0;
  document.getElementById('modal-stock').classList.add('active');
};

document.getElementById('form-stock').addEventListener('submit', async (e) => {
  e.preventDefault();
  const id = document.getElementById('stock-item-id').value;
  const newQty = document.getElementById('stock-item-qty').value;
  const newPrice = document.getElementById('stock-item-price').value;
  const newCost = document.getElementById('stock-item-cost').value;
  try {
    const res = await fetch(`${API_BASE}/items/${id}/stock`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        stock_qty: Number(newQty),
        selling_price: Number(newPrice),
        cost_price: Number(newCost)
      })
    });
    if (res.ok) {
      showToast('Inventory stock & prices updated successfully');
      document.getElementById('modal-stock').classList.remove('active');
      loadInventory();
      loadOverview();
    }
  } catch (err) {
    showToast('Failed to update stock', 'error');
  }
});

// Photo Management Handlers
window.openPhotoModal = function(id, name, currentUrl) {
  document.getElementById('photo-item-id').value = id;
  document.getElementById('photo-item-name').textContent = name;
  document.getElementById('photo-url-input').value = currentUrl || '';
  document.getElementById('photo-preview').src = currentUrl || 'logo.png';
  document.getElementById('photo-file-input').value = '';
  document.getElementById('modal-item-photo').classList.add('active');
};

document.getElementById('photo-file-input').addEventListener('change', function(e) {
  const file = e.target.files[0];
  if (file) {
    const reader = new FileReader();
    reader.onload = function(evt) {
      document.getElementById('photo-preview').src = evt.target.result;
    };
    reader.readAsDataURL(file);
  }
});

document.getElementById('photo-url-input').addEventListener('input', function(e) {
  if (e.target.value) {
    document.getElementById('photo-preview').src = e.target.value;
  }
});

document.getElementById('form-item-photo').addEventListener('submit', async function(e) {
  e.preventDefault();
  const id = document.getElementById('photo-item-id').value;
  const fileInput = document.getElementById('photo-file-input');
  const urlInput = document.getElementById('photo-url-input');

  let payload = {};
  if (fileInput.files && fileInput.files[0]) {
    const file = fileInput.files[0];
    const base64 = await new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result);
      reader.onerror = reject;
      reader.readAsDataURL(file);
    });
    payload.image_data = base64;
  } else if (urlInput.value.trim()) {
    payload.image_url = urlInput.value.trim();
  } else {
    showToast('Please select a photo file or enter URL', 'error');
    return;
  }

  try {
    const res = await fetch(`${API_BASE}/items/${id}/image`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    const data = await res.json();
    if (data.success) {
      showToast('Product photo updated successfully!');
      document.getElementById('modal-item-photo').classList.remove('active');
      loadInventory();
    } else {
      showToast('Failed to update photo', 'error');
    }
  } catch (err) {
    showToast('Error uploading photo', 'error');
  }
});

// New Product Photo Preview & Form Submit
document.getElementById('new-prod-file-input').addEventListener('change', function(e) {
  const file = e.target.files[0];
  if (file) {
    const reader = new FileReader();
    reader.onload = function(evt) {
      document.getElementById('new-prod-preview').src = evt.target.result;
    };
    reader.readAsDataURL(file);
  }
});

document.getElementById('new-prod-url-input').addEventListener('input', function(e) {
  if (e.target.value) {
    document.getElementById('new-prod-preview').src = e.target.value;
  }
});

document.getElementById('form-new-product').addEventListener('submit', async function(e) {
  e.preventDefault();
  const fileInput = document.getElementById('new-prod-file-input');
  const urlInput = document.getElementById('new-prod-url-input');

  let imageData = null;
  if (fileInput.files && fileInput.files[0]) {
    imageData = await new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result);
      reader.onerror = reject;
      reader.readAsDataURL(fileInput.files[0]);
    });
  }

  const payload = {
    name: document.getElementById('new-prod-name').value.trim(),
    name_te: document.getElementById('new-prod-name-te').value.trim() || document.getElementById('new-prod-name').value.trim(),
    category: document.getElementById('new-prod-category').value,
    unit: document.getElementById('new-prod-unit').value,
    selling_price: Number(document.getElementById('new-prod-selling').value),
    cost_price: Number(document.getElementById('new-prod-cost').value),
    stock_qty: Number(document.getElementById('new-prod-stock').value),
    low_stock_threshold: Number(document.getElementById('new-prod-threshold').value || 10),
    image_url: urlInput.value.trim() || null,
    image_data: imageData
  };

  try {
    const res = await fetch(`${API_BASE}/items`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    const data = await res.json();
    if (data.success) {
      showToast(`Product "${payload.name}" created successfully with photo!`);
      document.getElementById('modal-new-product').classList.remove('active');
      document.getElementById('form-new-product').reset();
      document.getElementById('new-prod-preview').src = 'logo.png';
      loadInventory();
    } else {
      showToast('Failed to create product', 'error');
    }
  } catch (err) {
    showToast('Error creating product: ' + err.message, 'error');
  }
});

// Bottling Form Submit
document.getElementById('form-bottling').addEventListener('submit', async (e) => {
  e.preventDefault();
  const payload = {
    item_id: document.getElementById('bottling-item-id').value,
    bottles_packed: Number(document.getElementById('bottling-count').value),
    bulk_oil_litres_used: Number(document.getElementById('bottling-litres').value),
    bottle_cost_per_unit: Number(document.getElementById('bottling-cap-cost').value),
    label_cost_per_unit: Number(document.getElementById('bottling-label-cost').value)
  };

  try {
    const res = await fetch(`${API_BASE}/production/bottling`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    if (res.ok) {
      showToast(`Bottles successfully added to inventory! (+${payload.bottles_packed} units)`);
      document.getElementById('modal-bottling').classList.remove('active');
      document.getElementById('form-bottling').reset();
      loadInventory();
      loadOverview();
    }
  } catch (err) {
    showToast('Failed to record bottling entry', 'error');
  }
});

// ==================== 4. MILLING SERVICES RATES ====================
let currentMillingServices = [];

async function loadMillingRates() {
  try {
    const res = await fetch(`${API_BASE}/milling-services`);
    currentMillingServices = await res.json();
    const tbody = document.querySelector('#milling-rates-table tbody');

    if (!currentMillingServices || currentMillingServices.length === 0) {
      tbody.innerHTML = `<tr><td colspan="5" style="text-align:center; color: var(--text-dim); padding: 2rem;">No milling services added yet. Click 'Add New Service' above.</td></tr>`;
      return;
    }

    tbody.innerHTML = currentMillingServices.map(s => `
      <tr>
        <td><strong>${s.name}</strong></td>
        <td><span style="color: var(--primary); font-weight: 600;">${s.name_te || '-'}</span></td>
        <td><span class="badge badge-milling">${s.type}</span></td>
        <td>
          <input type="number" step="0.5" class="form-control" style="width: 100px; display:inline-block; font-weight: bold;" 
                 value="${s.rate_per_kg}" id="rate-input-${s.id}"> ₹ / ${s.unit || 'kg'}
        </td>
        <td style="white-space: nowrap;">
          <button class="btn btn-secondary btn-sm" onclick="updateMillingRate(${s.id})" title="Save rate directly">💾 Save</button>
          <button class="btn btn-secondary btn-sm" onclick="openEditMillingModal(${s.id})" title="Edit service details">✏️ Edit</button>
          <button class="btn btn-danger btn-sm" onclick="deleteMillingService(${s.id})" title="Delete service">🗑️</button>
        </td>
      </tr>
    `).join('');
  } catch (err) {
    console.error('Failed to load milling rates:', err);
  }
}

window.updateMillingRate = async function(id) {
  const newRate = document.getElementById(`rate-input-${id}`).value;
  try {
    const res = await fetch(`${API_BASE}/milling-services/${id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ rate_per_kg: Number(newRate) })
    });
    if (res.ok) {
      showToast('Milling rate updated successfully!');
      loadMillingRates();
    } else {
      showToast('Failed to update milling rate', 'error');
    }
  } catch (err) {
    showToast('Failed to update milling rate', 'error');
  }
};

window.openEditMillingModal = function(id) {
  const s = currentMillingServices.find(item => item.id === id);
  if (!s) return;
  document.getElementById('modal-milling-title').textContent = '✏️ Edit Milling Service';
  document.getElementById('milling-edit-id').value = s.id;
  document.getElementById('milling-name').value = s.name;
  document.getElementById('milling-name-te').value = s.name_te || '';
  document.getElementById('milling-type').value = s.type;
  document.getElementById('milling-rate').value = s.rate_per_kg;
  document.getElementById('milling-unit').value = s.unit || 'kg';
  document.getElementById('btn-save-milling-service').textContent = 'Update Service';
  document.getElementById('modal-milling-service').classList.add('active');
};

window.deleteMillingService = async function(id) {
  const s = currentMillingServices.find(item => item.id === id);
  const name = s ? (s.name || s.name_te) : 'service';
  if (!confirm(`Are you sure you want to delete '${name}'? Staff will no longer see this in the mobile POS app.`)) return;
  try {
    const res = await fetch(`${API_BASE}/milling-services/${id}`, { method: 'DELETE' });
    if (res.ok) {
      showToast(`'${name}' deleted successfully!`);
      loadMillingRates();
    } else {
      showToast('Failed to delete service', 'error');
    }
  } catch (err) {
    showToast('Server error while deleting service', 'error');
  }
};

document.getElementById('btn-open-milling-modal')?.addEventListener('click', () => {
  document.getElementById('modal-milling-title').textContent = '➕ Add New Milling Service';
  document.getElementById('milling-edit-id').value = '';
  document.getElementById('milling-name').value = '';
  document.getElementById('milling-name-te').value = '';
  document.getElementById('milling-type').value = 'FLOUR';
  document.getElementById('milling-rate').value = '';
  document.getElementById('milling-unit').value = 'kg';
  document.getElementById('btn-save-milling-service').textContent = 'Add Service';
});

document.getElementById('form-milling-service')?.addEventListener('submit', async (e) => {
  e.preventDefault();
  const id = document.getElementById('milling-edit-id').value;
  const name = document.getElementById('milling-name').value.trim();
  const name_te = document.getElementById('milling-name-te').value.trim();
  const type = document.getElementById('milling-type').value;
  const rate_per_kg = parseFloat(document.getElementById('milling-rate').value);
  const unit = document.getElementById('milling-unit').value.trim() || 'kg';

  if (!name || isNaN(rate_per_kg)) {
    showToast('Please enter service name and rate', 'error');
    return;
  }

  try {
    const url = id ? `${API_BASE}/milling-services/${id}` : `${API_BASE}/milling-services`;
    const method = id ? 'PUT' : 'POST';
    const res = await fetch(url, {
      method,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name, name_te, type, rate_per_kg, unit })
    });

    if (res.ok) {
      showToast(id ? 'Milling service updated successfully!' : '✅ New milling service added!');
      document.getElementById('modal-milling-service').classList.remove('active');
      loadMillingRates();
    } else {
      showToast('Failed to save milling service', 'error');
    }
  } catch (err) {
    showToast('Server error while saving service', 'error');
  }
});

// ==================== 5. CASH AUDIT & DAY-END TALLIES ====================
async function loadCashAudit() {
  try {
    const res = await fetch(`${API_BASE}/day-end/history`);
    const tallies = await res.json();
    const tbody = document.querySelector('#tallies-table tbody');
    if (tallies.length === 0) {
      tbody.innerHTML = `<tr><td colspan="7" style="text-align:center; color: var(--text-dim); padding: 2rem;">No cash tallies recorded yet. Staff closing tallies from the mobile app will automatically display here.</td></tr>`;
      return;
    }

    tbody.innerHTML = tallies.map(t => {
      const isMatch = t.cash_difference === 0;
      const isShort = t.cash_difference < 0;

      let badge = '<span class="badge badge-success">Balanced (₹0 Diff)</span>';
      if (isShort) {
        badge = `<span class="badge badge-danger">⚠️ ₹${Math.abs(t.cash_difference)} Shortage</span>`;
      } else if (!isMatch) {
        badge = `<span class="badge badge-warning">➕ ₹${t.cash_difference} Excess</span>`;
      }

      return `
        <tr>
          <td><strong>${t.tally_date}</strong></td>
          <td>${formatInr(t.system_cash_sales)}</td>
          <td>${formatInr(t.system_upi_sales)}</td>
          <td><strong>${formatInr(t.system_total_sales)}</strong></td>
          <td><strong style="color: var(--primary); font-size: 1rem;">${formatInr(t.actual_cash_counted)}</strong></td>
          <td style="color: ${isShort ? 'var(--danger)' : (isMatch ? 'var(--success)' : 'var(--primary)')}; font-weight:700;">
            ${formatInr(t.cash_difference)}
          </td>
          <td>${badge}</td>
        </tr>
      `;
    }).join('');
  } catch (err) {
    console.error('Failed to load cash audit:', err);
  }
}

// ==================== 6. EXPENSES ====================
async function loadExpenses() {
  try {
    const res = await fetch(`${API_BASE}/expenses`);
    const expenses = await res.json();
    const tbody = document.querySelector('#expenses-table tbody');
    if (expenses.length === 0) {
      tbody.innerHTML = `<tr><td colspan="4" style="text-align:center; color: var(--text-dim); padding: 2rem;">No expenses recorded yet. Click 'Record Expense' above to log an expense.</td></tr>`;
      return;
    }

    tbody.innerHTML = expenses.map(e => `
      <tr>
        <td><strong>${e.expense_date}</strong></td>
        <td><span class="badge badge-danger">${e.category}</span></td>
        <td><strong style="color: var(--danger); font-size: 1rem;">${formatInr(e.amount)}</strong></td>
        <td>${e.notes || '-'}</td>
      </tr>
    `).join('');
  } catch (err) {
    console.error('Failed to load expenses:', err);
  }
}

document.getElementById('form-expense').addEventListener('submit', async (e) => {
  e.preventDefault();
  const payload = {
    category: document.getElementById('expense-category').value,
    amount: document.getElementById('expense-amount').value,
    notes: document.getElementById('expense-notes').value
  };

  try {
    const res = await fetch(`${API_BASE}/expenses`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    if (res.ok) {
      showToast('Expense recorded successfully');
      document.getElementById('modal-expense').classList.remove('active');
      document.getElementById('form-expense').reset();
      loadExpenses();
      loadOverview();
    }
  } catch (err) {
    showToast('Failed to record expense', 'error');
  }
});

// ==================== 7. BILLS / SALES ====================
async function loadBills() {
  try {
    const res = await fetch(`${API_BASE}/sales?limit=50`);
    const sales = await res.json();
    const tbody = document.querySelector('#bills-table tbody');
    if (sales.length === 0) {
      tbody.innerHTML = `<tr><td colspan="7" style="text-align:center; color: var(--text-dim); padding: 2rem;">No sales invoices recorded yet. Issue bills from the Staff Mobile POS.</td></tr>`;
      return;
    }

    tbody.innerHTML = sales.map(s => `
      <tr>
        <td><strong>${s.bill_number}</strong></td>
        <td>${s.sale_time ? s.sale_time.slice(0, 16) : '-'}</td>
        <td><span class="badge ${s.payment_mode === 'CASH' ? 'badge-success' : 'badge-repack'}">${s.payment_mode}</span></td>
        <td>${formatInr(s.cash_paid)}</td>
        <td>${formatInr(s.upi_paid)}</td>
        <td><strong style="color: var(--primary); font-size: 1rem;">${formatInr(s.total_amount)}</strong></td>
        <td>
          <button class="btn btn-secondary btn-sm" onclick="viewBillDetails(${s.id})">🔍 View</button>
        </td>
      </tr>
    `).join('');
  } catch (err) {
    console.error('Failed to load bills:', err);
  }
}

window.viewBillDetails = async function(id) {
  try {
    const res = await fetch(`${API_BASE}/sales/${id}`);
    const sale = await res.json();
    let msg = `Invoice: ${sale.bill_number}\nTotal: ${formatInr(sale.total_amount)} (${sale.payment_mode})\n\nItems:\n`;
    sale.items.forEach(i => {
      msg += `• ${i.name} - ${i.quantity} @ ${formatInr(i.rate)} = ${formatInr(i.total)}\n`;
    });
    alert(msg);
  } catch (err) {
    alert('Failed to retrieve invoice details');
  }
};

// ==================== 8. CUSTOMER KHATA & CREDIT LEDGER ====================
async function loadKhata() {
  try {
    const searchVal = document.getElementById('khata-search-input')?.value.trim() || '';
    const res = await fetch(`${API_BASE}/customers${searchVal ? `?search=${encodeURIComponent(searchVal)}` : ''}`);
    const customers = await res.json();

    const sumRes = await fetch(`${API_BASE}/reports/khata-summary`);
    const sumData = await sumRes.json();

    if (sumData.summary) {
      document.getElementById('khata-total-due').textContent = formatInr(sumData.summary.total_market_due);
      document.getElementById('khata-due-count').textContent = sumData.summary.customers_with_due;
      document.getElementById('khata-total-customers').textContent = sumData.summary.total_customers;
    }

    const tbody = document.querySelector('#customers-khata-table tbody');
    if (!tbody) return;

    if (customers.length === 0) {
      tbody.innerHTML = `<tr><td colspan="7" style="text-align:center; color: var(--text-dim); padding: 2rem;">No Khata customers found. Click "+ Add New Customer" to register one.</td></tr>`;
      return;
    }

    tbody.innerHTML = customers.map(c => {
      const hasDue = Number(c.total_credit_due) > 0;
      return `
        <tr>
          <td>
            <strong>${c.name}</strong><br>
            <small style="color: var(--text-dim);">${c.name_te || ''}</small>
          </td>
          <td>
            <strong>${c.phone || '-'}</strong>
          </td>
          <td>${c.address || '-'}</td>
          <td>
            <strong style="font-size: 1.05rem; color: ${hasDue ? 'var(--danger)' : 'var(--primary)'};">
              ${formatInr(c.total_credit_due)}
            </strong>
          </td>
          <td style="color: var(--text-muted);">${formatInr(c.credit_limit)}</td>
          <td>
            <span class="badge ${hasDue ? 'badge-danger' : 'badge-success'}">
              ${hasDue ? 'Pending Due' : 'All Clear'}
            </span>
          </td>
          <td>
            <div style="display: flex; gap: 0.35rem; flex-wrap: wrap;">
              ${hasDue ? `
                <button class="btn btn-primary btn-sm" onclick="openReceivePaymentModal(${c.id}, '${c.name.replace(/'/g, "\\'")}', '${c.phone || ''}', ${c.total_credit_due})">
                  💵 Pay
                </button>
              ` : ''}
              <button class="btn btn-secondary btn-sm" onclick="openCustomerLedger(${c.id})">
                📜 Statement
              </button>
              ${c.phone ? `
                <button class="btn btn-sm" style="background: #25D366; color: #fff; padding: 0.3rem 0.6rem; border-radius: 6px;" onclick="sendKhataWhatsApp('${c.name.replace(/'/g, "\\'")}', '${c.phone}', ${c.total_credit_due})">
                  📲 WA
                </button>
              ` : ''}
            </div>
          </td>
        </tr>
      `;
    }).join('');
  } catch (err) {
    console.error('Failed to load Khata customers:', err);
  }
}

// Receive Payment Modal Open
window.openReceivePaymentModal = function(id, name, phone, due) {
  document.getElementById('pay-customer-id').value = id;
  document.getElementById('pay-customer-name').textContent = name;
  document.getElementById('pay-customer-phone').textContent = phone ? `Phone: ${phone}` : '';
  document.getElementById('pay-customer-due').textContent = formatInr(due);
  document.getElementById('pay-amount-input').value = due;
  document.getElementById('pay-notes-input').value = '';
  document.getElementById('modal-receive-payment').classList.add('active');
};

// Customer Ledger Modal Open
window.openCustomerLedger = async function(id) {
  try {
    const res = await fetch(`${API_BASE}/customers/${id}/ledger`);
    const data = await res.json();
    const c = data.customer;

    document.getElementById('ledger-customer-name').textContent = `${c.name} ${c.name_te ? `(${c.name_te})` : ''}`;
    document.getElementById('ledger-customer-info').textContent = `${c.phone || 'No Phone'} • ${c.address || 'No Address'}`;
    document.getElementById('ledger-customer-balance').textContent = formatInr(c.total_credit_due);

    // Setup WhatsApp button in ledger
    const waBtn = document.getElementById('btn-ledger-whatsapp');
    if (c.phone) {
      waBtn.style.display = 'inline-block';
      waBtn.onclick = () => sendKhataWhatsApp(c.name, c.phone, c.total_credit_due);
    } else {
      waBtn.style.display = 'none';
    }

    const tbody = document.querySelector('#ledger-transactions-table tbody');
    if (data.transactions.length === 0) {
      tbody.innerHTML = `<tr><td colspan="6" style="text-align: center; color: var(--text-dim); padding: 1.5rem;">No transaction entries recorded yet.</td></tr>`;
    } else {
      tbody.innerHTML = data.transactions.map(t => {
        const isPurchase = t.type === 'CREDIT_PURCHASE';
        return `
          <tr>
            <td>${t.created_at ? t.created_at.slice(0, 16) : '-'}</td>
            <td>
              <span class="badge ${isPurchase ? 'badge-danger' : 'badge-success'}">
                ${isPurchase ? '🛒 Goods Credit' : '💵 Paid'}
              </span>
            </td>
            <td>
              <strong style="color: ${isPurchase ? 'var(--danger)' : 'var(--primary)'};">
                ${isPurchase ? '+' : '-'}${formatInr(t.amount)}
              </strong>
            </td>
            <td>${t.payment_mode || '-'}</td>
            <td><strong>${formatInr(t.balance_after)}</strong></td>
            <td><small>${t.bill_number ? `Bill #${t.bill_number}` : ''} ${t.notes || ''}</small></td>
          </tr>
        `;
      }).join('');
    }

    document.getElementById('modal-customer-ledger').classList.add('active');
  } catch (err) {
    showToast('Failed to load customer statement', 'error');
  }
};

// WhatsApp Reminder Sender
window.sendKhataWhatsApp = function(name, phone, due) {
  if (!phone) {
    showToast('No phone number for this customer', 'error');
    return;
  }
  const cleanPhone = phone.replace(/[^0-9]/g, '');
  const targetPhone = cleanPhone.length === 10 ? `91${cleanPhone}` : cleanPhone;
  const msg = `Dear ${name}, greeting from UNIK NATURALS. Your outstanding account balance is ₹${due}. Kindly clear the balance via Cash or UPI (PhonePe/GPay) at your earliest convenience. Thank you!`;
  const url = `https://api.whatsapp.com/send?phone=${targetPhone}&text=${encodeURIComponent(msg)}`;
  window.open(url, '_blank');
};

// Form: Receive Payment Submit
document.getElementById('form-receive-payment').addEventListener('submit', async function(e) {
  e.preventDefault();
  const id = document.getElementById('pay-customer-id').value;
  const amount = Number(document.getElementById('pay-amount-input').value);
  const payment_mode = document.getElementById('pay-mode-select').value;
  const notes = document.getElementById('pay-notes-input').value.trim();

  try {
    const res = await fetch(`${API_BASE}/customers/${id}/payment`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ amount, payment_mode, notes })
    });
    const data = await res.json();
    if (data.success) {
      showToast(`Payment of ₹${amount} received successfully! New Due: ₹${data.new_balance}`);
      document.getElementById('modal-receive-payment').classList.remove('active');
      loadKhata();
      loadOverview();
    } else {
      showToast('Failed to record payment: ' + (data.error || ''), 'error');
    }
  } catch (err) {
    showToast('Error recording payment: ' + err.message, 'error');
  }
});

// Form: Create New Customer Submit
document.getElementById('form-new-customer').addEventListener('submit', async function(e) {
  e.preventDefault();
  const payload = {
    name: document.getElementById('new-cust-name').value.trim(),
    name_te: document.getElementById('new-cust-name-te').value.trim() || null,
    phone: document.getElementById('new-cust-phone').value.trim() || null,
    address: document.getElementById('new-cust-address').value.trim() || null,
    credit_limit: Number(document.getElementById('new-cust-limit').value || 5000)
  };

  try {
    const res = await fetch(`${API_BASE}/customers`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    const data = await res.json();
    if (data.success) {
      showToast(`Customer "${payload.name}" created successfully!`);
      document.getElementById('modal-new-customer').classList.remove('active');
      document.getElementById('form-new-customer').reset();
      loadKhata();
    } else {
      showToast('Failed to create customer: ' + (data.error || ''), 'error');
    }
  } catch (err) {
    showToast('Error creating customer: ' + err.message, 'error');
  }
});

// Search input debounce for Khata
let khataSearchTimeout;
document.getElementById('khata-search-input')?.addEventListener('input', function() {
  clearTimeout(khataSearchTimeout);
  khataSearchTimeout = setTimeout(() => {
    loadKhata();
  }, 300);
});

// Refresh button
document.getElementById('btn-refresh').addEventListener('click', () => {
  loadOverview();
  showToast('Dashboard data refreshed!');
});

// ==================== AUTHENTICATION & SESSION MANAGEMENT ====================

function getAuthToken() {
  return localStorage.getItem('unik_auth_token') || sessionStorage.getItem('unik_auth_token');
}

function getCurrentUser() {
  const userJson = localStorage.getItem('unik_auth_user') || sessionStorage.getItem('unik_auth_user');
  try {
    return userJson ? JSON.parse(userJson) : null;
  } catch (_) {
    return null;
  }
}

function setSession(token, user, remember = true) {
  const storage = remember ? localStorage : sessionStorage;
  storage.setItem('unik_auth_token', token);
  storage.setItem('unik_auth_user', JSON.stringify(user));
}

function clearSession() {
  localStorage.removeItem('unik_auth_token');
  localStorage.removeItem('unik_auth_user');
  sessionStorage.removeItem('unik_auth_token');
  sessionStorage.removeItem('unik_auth_user');
}

function updateAuthUI() {
  const user = getCurrentUser();
  const authModal = document.getElementById('auth-modal');
  const userProfileBadge = document.getElementById('user-profile-badge');
  const navBtnUsers = document.getElementById('nav-btn-users');
  const logoutBtn = document.getElementById('btn-header-logout');

  if (!user) {
    if (authModal) authModal.classList.remove('hidden');
    if (userProfileBadge) {
      userProfileBadge.style.display = 'inline-flex';
      const avatarEl = document.getElementById('header-user-avatar');
      const nameEl = document.getElementById('header-user-name');
      const roleEl = document.getElementById('header-user-role');
      if (avatarEl) avatarEl.textContent = '🔒';
      if (nameEl) nameEl.textContent = 'లాగిన్ అవ్వండి';
      if (roleEl) {
        roleEl.textContent = 'GUEST';
        roleEl.className = 'user-role-tag';
      }
    }
    if (logoutBtn) {
      logoutBtn.innerHTML = '<span>🔑</span><span style="font-weight: 700;">లాగిన్ / Login</span>';
      logoutBtn.style.background = 'linear-gradient(135deg, #D39715 0%, #A6730A 100%)';
    }
    return;
  }

  // Hide login modal
  if (authModal) authModal.classList.add('hidden');

  // Display user badge in header
  if (userProfileBadge) {
    userProfileBadge.style.display = 'inline-flex';
    const avatarEl = document.getElementById('header-user-avatar');
    const nameEl = document.getElementById('header-user-name');
    const roleEl = document.getElementById('header-user-role');

    if (avatarEl) avatarEl.textContent = user.role === 'ADMIN' ? '👑' : '👤';
    if (nameEl) nameEl.textContent = user.name || user.username;
    if (roleEl) {
      roleEl.textContent = user.role === 'ADMIN' ? 'OWNER' : 'STAFF';
      roleEl.className = `user-role-tag ${user.role === 'ADMIN' ? 'admin' : 'staff'}`;
    }
  }

  if (logoutBtn) {
    logoutBtn.innerHTML = '<span>🚪</span><span style="font-weight: 700;">లాగౌట్ / Logout</span>';
    logoutBtn.style.background = 'linear-gradient(135deg, #DC2626 0%, #991B1B 100%)';
  }

  // Role permissions
  if (user.role === 'STAFF') {
    if (navBtnUsers) navBtnUsers.style.display = 'none';
    const activeTab = document.querySelector('.nav-tab-btn.active')?.getAttribute('data-tab');
    if (activeTab === 'tab-users') {
      document.querySelector('[data-tab="tab-bills"]')?.click();
    }
  } else {
    if (navBtnUsers) navBtnUsers.style.display = 'inline-flex';
  }
}

// Password visibility toggle
document.getElementById('btn-toggle-pw')?.addEventListener('click', () => {
  const pwInput = document.getElementById('login-password');
  const btn = document.getElementById('btn-toggle-pw');
  if (!pwInput) return;
  if (pwInput.type === 'password') {
    pwInput.type = 'text';
    btn.textContent = '🙈';
  } else {
    pwInput.type = 'password';
    btn.textContent = '👁️';
  }
});

// Demo autofill buttons
document.getElementById('btn-demo-admin')?.addEventListener('click', () => {
  const userIn = document.getElementById('login-username');
  const passIn = document.getElementById('login-password');
  if (userIn) userIn.value = 'admin';
  if (passIn) passIn.value = 'admin123';
  document.getElementById('auth-form')?.dispatchEvent(new Event('submit'));
});

document.getElementById('btn-demo-staff')?.addEventListener('click', () => {
  const userIn = document.getElementById('login-username');
  const passIn = document.getElementById('login-password');
  if (userIn) userIn.value = 'staff';
  if (passIn) passIn.value = 'staff123';
  document.getElementById('auth-form')?.dispatchEvent(new Event('submit'));
});

// Handle Login Form Submission
document.getElementById('auth-form')?.addEventListener('submit', async (e) => {
  e.preventDefault();
  const username = document.getElementById('login-username').value.trim();
  const password = document.getElementById('login-password').value;
  const remember = document.getElementById('login-remember')?.checked ?? true;
  const errEl = document.getElementById('auth-error');
  const submitBtn = document.getElementById('btn-login-submit');

  if (errEl) errEl.style.display = 'none';
  if (submitBtn) {
    submitBtn.disabled = true;
    submitBtn.textContent = '⏳ ధృవీకరిస్తోంది... / Logging in...';
  }

  try {
    const res = await fetch(`${API_BASE}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password })
    });
    const data = await res.json();

    if (res.ok && data.success) {
      setSession(data.token, data.user, remember);

      if (data.user.role === 'STAFF') {
        if (submitBtn) {
          submitBtn.textContent = '✅ POS బిల్లింగ్ ఓపెన్ అవుతోంది...';
        }
        window.location.href = '/pos/';
        return;
      }

      updateAuthUI();
      showToast(`స్వాగతం (Welcome), ${data.user.name}!`);
      loadOverview();
    } else {
      if (errEl) {
        errEl.textContent = '⚠️ ' + (data.error || 'Login failed. Check credentials.');
        errEl.style.display = 'flex';
      }
    }
  } catch (err) {
    if (errEl) {
      errEl.textContent = '⚠️ Server connection error: ' + err.message;
      errEl.style.display = 'flex';
    }
  } finally {
    if (submitBtn) {
      submitBtn.disabled = false;
      submitBtn.textContent = '🚀 లాగిన్ అవ్వండి / Login';
    }
  }
});

// Logout / Login Action Handler
function triggerAuthAction() {
  const user = getCurrentUser();
  if (user) {
    clearSession();
    updateAuthUI();
    showToast(`విజయవంతంగా లాగౌట్ అయ్యారు (${user.name || user.username})!`, 'info');
  } else {
    const authModal = document.getElementById('auth-modal');
    if (authModal) authModal.classList.remove('hidden');
  }
}

document.getElementById('btn-header-logout')?.addEventListener('click', triggerAuthAction);
document.getElementById('btn-logout')?.addEventListener('click', triggerAuthAction);
document.getElementById('user-profile-badge')?.addEventListener('click', triggerAuthAction);

// ==================== USER MANAGEMENT TAB & CRUD ====================

async function loadUsers() {
  const tbody = document.querySelector('#users-table tbody');
  if (!tbody) return;
  tbody.innerHTML = '<tr><td colspan="8" style="text-align: center; padding: 1.5rem;">⏳ Loading users list...</td></tr>';

  try {
    const res = await fetch(`${API_BASE}/users`);
    const users = await res.json();

    if (!Array.isArray(users) || users.length === 0) {
      tbody.innerHTML = '<tr><td colspan="8" style="text-align: center; color: var(--text-dim); padding: 1.5rem;">No user accounts found.</td></tr>';
      return;
    }

    tbody.innerHTML = users.map(u => {
      const isOwner = u.role === 'ADMIN';
      const roleBadge = isOwner 
        ? `<span class="badge badge-role-admin">👑 ADMIN (OWNER)</span>`
        : `<span class="badge badge-role-staff">👤 STAFF (CASHIER)</span>`;

      const statusBadge = u.is_active 
        ? `<span class="badge" style="background: rgba(52, 211, 153, 0.15); color: #34d399;">Active</span>`
        : `<span class="badge" style="background: rgba(248, 113, 113, 0.15); color: #f87171;">Disabled</span>`;

      const dateStr = u.created_at ? new Date(u.created_at).toLocaleDateString() : 'Initial';

      return `
        <tr>
          <td><strong>#${u.id}</strong></td>
          <td><strong style="color: var(--brand-gold-bright);">${u.username}</strong></td>
          <td>
            <div>${u.name}</div>
            ${u.name_te ? `<small style="color: var(--text-muted);">${u.name_te}</small>` : ''}
          </td>
          <td>${roleBadge}</td>
          <td>${u.phone || '<span style="color: var(--text-dim);">-</span>'}</td>
          <td>${statusBadge}</td>
          <td style="font-size: 0.8rem; color: var(--text-dim);">${dateStr}</td>
          <td>
            <div style="display: flex; gap: 0.35rem;">
              <button class="btn btn-secondary btn-sm" onclick="openEditUserModal(${u.id}, '${escapeHtml(u.username)}', '${escapeHtml(u.name)}', '${escapeHtml(u.name_te || '')}', '${u.role}', '${u.phone || ''}', ${u.is_active})">✏️ Edit</button>
              ${u.username !== 'admin' ? `
                <button class="btn btn-danger btn-sm" onclick="deleteUser(${u.id}, '${escapeHtml(u.username)}')">🗑️</button>
              ` : ''}
            </div>
          </td>
        </tr>
      `;
    }).join('');
  } catch (err) {
    tbody.innerHTML = `<tr><td colspan="8" style="color: var(--danger); text-align: center; padding: 1rem;">Failed to load users: ${err.message}</td></tr>`;
  }
}

function escapeHtml(str) {
  if (!str) return '';
  return String(str).replace(/'/g, "\\'").replace(/"/g, '&quot;');
}

window.openEditUserModal = function(id, username, name, name_te, role, phone, isActive) {
  document.getElementById('modal-user-title').textContent = `✏️ Edit User (${username})`;
  document.getElementById('user-id').value = id;
  const usernameInput = document.getElementById('user-username');
  usernameInput.value = username;
  usernameInput.readOnly = (username === 'admin');

  document.getElementById('user-fullname').value = name;
  document.getElementById('user-name-te').value = name_te;
  document.getElementById('user-role').value = role;
  document.getElementById('user-phone').value = phone;
  document.getElementById('user-password').value = '';
  document.getElementById('password-hint').textContent = '(Leave empty to keep existing password)';
  document.getElementById('label-user-password').textContent = 'Reset Password (పాస్‌వర్డ్ మార్పు):';
  document.getElementById('user-is-active').checked = Boolean(isActive);

  document.getElementById('modal-user').classList.add('active');
};

window.deleteUser = async function(id, username) {
  if (!confirm(`Are you sure you want to remove user "${username}"?`)) return;
  try {
    const res = await fetch(`${API_BASE}/users/${id}`, { method: 'DELETE' });
    const data = await res.json();
    if (data.success) {
      showToast(`User "${username}" deleted.`);
      loadUsers();
    } else {
      showToast('Error: ' + (data.error || 'Failed to delete'), 'error');
    }
  } catch (err) {
    showToast('Failed to delete user: ' + err.message, 'error');
  }
};

// Open New User Modal
document.getElementById('btn-open-user-modal')?.addEventListener('click', () => {
  document.getElementById('modal-user-title').textContent = '👤 Add New Staff / User';
  document.getElementById('user-id').value = '';
  const usernameInput = document.getElementById('user-username');
  usernameInput.value = '';
  usernameInput.readOnly = false;
  document.getElementById('user-fullname').value = '';
  document.getElementById('user-name-te').value = '';
  document.getElementById('user-role').value = 'STAFF';
  document.getElementById('user-phone').value = '';
  document.getElementById('user-password').value = '';
  document.getElementById('user-password').required = true;
  document.getElementById('password-hint').textContent = '(Min 4 characters recommended)';
  document.getElementById('label-user-password').textContent = 'Password / పాస్‌వర్డ్:';
  document.getElementById('user-is-active').checked = true;
  document.getElementById('modal-user').classList.add('active');
});

// Setup User modal close buttons
setupModal('modal-user', [], ['.modal-close', '.modal-cancel']);

// Save User (POST or PUT)
document.getElementById('form-user')?.addEventListener('submit', async (e) => {
  e.preventDefault();
  const userId = document.getElementById('user-id').value;
  const username = document.getElementById('user-username').value.trim();
  const name = document.getElementById('user-fullname').value.trim();
  const name_te = document.getElementById('user-name-te').value.trim();
  const role = document.getElementById('user-role').value;
  const phone = document.getElementById('user-phone').value.trim();
  const password = document.getElementById('user-password').value;
  const is_active = document.getElementById('user-is-active').checked ? 1 : 0;

  const saveBtn = document.getElementById('btn-save-user');
  saveBtn.disabled = true;
  saveBtn.textContent = '⏳ Saving...';

  try {
    let res;
    if (userId) {
      res = await fetch(`${API_BASE}/users/${userId}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, name_te, role, phone, password, is_active })
      });
    } else {
      if (!password) {
        showToast('Password is required for new user', 'error');
        saveBtn.disabled = false;
        saveBtn.textContent = '💾 Save User';
        return;
      }
      res = await fetch(`${API_BASE}/users`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password, name, name_te, role, phone })
      });
    }

    const data = await res.json();
    if (res.ok && data.success) {
      showToast(`User "${username}" saved successfully!`);
      document.getElementById('modal-user').classList.remove('active');
      loadUsers();
    } else {
      showToast('Error: ' + (data.error || 'Failed to save user'), 'error');
    }
  } catch (err) {
    showToast('Failed to save user: ' + err.message, 'error');
  } finally {
    saveBtn.disabled = false;
    saveBtn.textContent = '💾 Save User';
  }
});

// ==================== 10. ONLINE ORDERS MANAGEMENT ====================
let allOnlineOrders = [];
let activeOnlineFilter = 'ALL';

async function loadOnlineOrdersAdmin() {
  const tbody = document.getElementById('online-orders-table-body');
  if (!tbody) return;

  try {
    const res = await fetch(`${API_BASE}/orders/online`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    allOnlineOrders = await res.json();

    // Compute metrics
    let newCount = 0;
    let acceptedCount = 0;
    let packingCount = 0;
    let outCount = 0;
    let deliveredCount = 0;
    let deliveredRevenue = 0;

    allOnlineOrders.forEach(o => {
      const st = (o.order_status || '').toUpperCase();
      const tot = Number(o.total_amount || 0);
      if (st === 'NEW') newCount++;
      if (st === 'ACCEPTED') acceptedCount++;
      if (st === 'PACKING') packingCount++;
      if (st === 'OUT_FOR_DELIVERY') outCount++;
      if (st === 'DELIVERED') {
        deliveredCount++;
        deliveredRevenue += tot;
      }
    });

    const totalOrdersEl = document.getElementById('stat-online-total-orders');
    const newOrdersEl = document.getElementById('stat-online-new-orders');
    const transitOrdersEl = document.getElementById('stat-online-transit-orders');
    const revenueEl = document.getElementById('stat-online-revenue');

    if (totalOrdersEl) totalOrdersEl.textContent = allOnlineOrders.length;
    if (newOrdersEl) newOrdersEl.textContent = newCount;
    if (transitOrdersEl) transitOrdersEl.textContent = packingCount + outCount;
    if (revenueEl) revenueEl.textContent = formatInr(deliveredRevenue);

    const cntNewEl = document.getElementById('filter-cnt-new');
    const cntAccEl = document.getElementById('filter-cnt-accepted');
    const cntPackEl = document.getElementById('filter-cnt-packing');
    const cntOutEl = document.getElementById('filter-cnt-out');
    const cntDelEl = document.getElementById('filter-cnt-delivered');

    if (cntNewEl) cntNewEl.textContent = newCount;
    if (cntAccEl) cntAccEl.textContent = acceptedCount;
    if (cntPackEl) cntPackEl.textContent = packingCount;
    if (cntOutEl) cntOutEl.textContent = outCount;
    if (cntDelEl) cntDelEl.textContent = deliveredCount;

    renderOnlineOrdersAdmin();
  } catch (err) {
    tbody.innerHTML = `<tr><td colspan="8" style="text-align: center; color: var(--danger); padding: 2rem;">Error loading online orders: ${err.message}</td></tr>`;
  }
}

function renderOnlineOrdersAdmin() {
  const tbody = document.getElementById('online-orders-table-body');
  if (!tbody) return;

  const filtered = activeOnlineFilter === 'ALL'
    ? allOnlineOrders
    : allOnlineOrders.filter(o => (o.order_status || '').toUpperCase() === activeOnlineFilter);

  if (filtered.length === 0) {
    tbody.innerHTML = `<tr><td colspan="8" style="text-align: center; color: var(--text-muted); padding: 2rem;">No online orders found for filter: "${activeOnlineFilter}".</td></tr>`;
    return;
  }

  tbody.innerHTML = filtered.map(o => {
    const status = (o.order_status || 'NEW').toUpperCase();
    const isPickup = o.delivery_type === 'PICKUP';
    const total = Number(o.total_amount || 0);
    const payMode = o.payment_mode || 'COD';
    const payStatus = (o.payment_status || 'PENDING').toUpperCase();

    // Format items
    const itemsHtml = (o.items || []).map(it => `
      <div style="font-size: 0.82rem; margin-bottom: 2px;">
        <span style="font-weight: 700; color: var(--primary);">${it.quantity}x</span>
        ${escapeHtml(it.name_te || it.name)}
        ${it.variant ? `<span style="color: var(--text-muted);">(${escapeHtml(it.variant)})</span>` : ''}
        - <strong>₹${it.total_price}</strong>
      </div>
    `).join('');

    // Status badge style
    let statusText = status;
    let statusColor = '#4B5563';
    let statusBg = '#F3F4F6';

    if (status === 'NEW') {
      statusText = '🟡 New (కొత్తది)';
      statusColor = '#B45309';
      statusBg = '#FEF3C7';
    } else if (status === 'ACCEPTED') {
      statusText = '🔵 Accepted (ఆమోదించినది)';
      statusColor = '#1D4ED8';
      statusBg = '#DBEAFE';
    } else if (status === 'PACKING') {
      statusText = '🟠 Packing (ప్యాకింగ్)';
      statusColor = '#C2410C';
      statusBg = '#FFEDD5';
    } else if (status === 'OUT_FOR_DELIVERY') {
      statusText = '🚚 Out for Delivery (డెలివరీలో)';
      statusColor = '#7E22CE';
      statusBg = '#F3E8FF';
    } else if (status === 'DELIVERED') {
      statusText = '🟢 Delivered (పూర్తయింది)';
      statusColor = '#15803D';
      statusBg = '#DCFCE7';
    } else if (status === 'CANCELLED') {
      statusText = '❌ Cancelled (రద్దు)';
      statusColor = '#B91C1C';
      statusBg = '#FEE2E2';
    }

    const dateStr = o.created_at ? new Date(o.created_at).toLocaleString('en-IN', {
      day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit'
    }) : '-';

    return `
      <tr>
        <td>
          <strong style="color: var(--brand-gold-bright); font-size: 0.95rem;">${escapeHtml(o.order_number)}</strong>
        </td>
        <td style="font-size: 0.82rem; color: var(--text-muted);">${dateStr}</td>
        <td>
          <div style="font-weight: 700;">${escapeHtml(o.customer_name)}</div>
          <div style="font-size: 0.82rem; color: var(--text-muted);">
            <a href="tel:${o.customer_phone}" style="color: inherit; text-decoration: none;">📞 ${escapeHtml(o.customer_phone)}</a>
          </div>
          ${(o.customer_khata_due !== undefined && o.customer_khata_due !== null) || o.payment_mode === 'KHATA' ? `
            <div style="margin-top: 4px; display: inline-block; padding: 2px 6px; border-radius: 4px; font-size: 0.72rem; font-weight: 700; background: #EFF6FF; color: #1D4ED8; border: 1px solid #BFDBFE;">
              📒 ఖాతాదారుడు (బాకీ: ${formatInr(o.customer_khata_due || 0)})
            </div>
          ` : ''}
          ${o.notes ? `<div style="font-size: 0.78rem; color: var(--brand-gold); margin-top: 3px;">📝 ${escapeHtml(o.notes)}</div>` : ''}
        </td>
        <td>
          <span style="display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 0.75rem; font-weight: 700; background: ${isPickup ? '#EFF6FF; color: #1D4ED8;' : '#ECFDF5; color: #047857;'} margin-bottom: 4px;">
            ${isPickup ? '🏪 Store Pickup' : '🚚 Home Delivery'}
          </span>
          ${!isPickup && o.delivery_address ? `<div style="font-size: 0.82rem; max-width: 220px; color: var(--text-main);">📍 ${escapeHtml(o.delivery_address)}</div>` : ''}
        </td>
        <td>
          <div style="max-height: 80px; overflow-y: auto;">${itemsHtml}</div>
        </td>
        <td>
          <div style="font-weight: 900; font-size: 1rem; color: var(--primary);">${formatInr(total)}</div>
          <div style="font-size: 0.8rem; margin-top: 2px;">
            ${payMode === 'KHATA' ? '<span style="color: #1E40AF; font-weight: 700;">📒 KHATA</span>' : payMode} • 
            <span style="font-weight: 700; color: ${payStatus === 'PAID' ? '#16A34A' : (payStatus === 'KHATA' ? '#1D4ED8' : '#D97706')};">
              ${payStatus === 'PAID' ? 'PAID ✅' : (payStatus === 'KHATA' ? 'IN KHATA 📒' : 'PENDING ⏳')}
            </span>
          </div>
        </td>
        <td>
          <span style="display: inline-block; padding: 3px 10px; border-radius: 12px; font-size: 0.8rem; font-weight: 700; color: ${statusColor}; background: ${statusBg};">
            ${statusText}
          </span>
        </td>
        <td>
          <div style="display: flex; gap: 4px; flex-wrap: wrap;">
            ${status === 'NEW' ? `
              <button class="btn btn-primary btn-sm" onclick="updateOnlineOrderStatusAdmin(${o.id}, 'ACCEPTED')">✅ Accept</button>
              <button class="btn btn-secondary btn-sm" style="color: var(--danger);" onclick="updateOnlineOrderStatusAdmin(${o.id}, 'CANCELLED')">❌ Cancel</button>
            ` : ''}
            ${status === 'ACCEPTED' ? `
              <button class="btn btn-sm" style="background: #D97706; color: #fff;" onclick="updateOnlineOrderStatusAdmin(${o.id}, 'PACKING')">📦 Packing</button>
            ` : ''}
            ${status === 'PACKING' ? `
              <button class="btn btn-sm" style="background: #7C3AED; color: #fff;" onclick="updateOnlineOrderStatusAdmin(${o.id}, 'OUT_FOR_DELIVERY')">🚚 Delivery</button>
            ` : ''}
            ${status === 'OUT_FOR_DELIVERY' ? `
              <button class="btn btn-sm" style="background: #16A34A; color: #fff;" onclick="updateOnlineOrderStatusAdmin(${o.id}, 'DELIVERED', 'PAID')">🟢 Paid & Delivered</button>
              <button class="btn btn-sm" style="background: #1E40AF; color: #fff;" onclick="promptKhataDeliverAdmin(${o.id}, '${escapeHtml(o.customer_name)}', '${o.customer_phone}', ${total}, ${o.customer_khata_due || 0})">📒 Add to Khata</button>
            ` : ''}
            ${o.customer_phone ? `
              <button class="btn btn-sm" style="background: #25D366; color: #fff; padding: 0.25rem 0.5rem;" title="Notify Customer on WhatsApp" onclick="sendOnlineOrderWhatsApp('${escapeHtml(o.customer_name)}', '${o.customer_phone}', '${escapeHtml(o.order_number)}', ${total}, '${status}')">💬 WhatsApp</button>
            ` : ''}
          </div>
        </td>
      </tr>
    `;
  }).join('');
}

window.promptKhataDeliverAdmin = async function(orderId, name, phone, total, currentDue) {
  const newDue = currentDue + total;
  const conf = confirm(
    `📒 కస్టమర్ ఖాతాలో రాయాలా? (Add to Khata)\n\n` +
    `కస్టమర్: ${name} (${phone})\n` +
    `ఈ ఆర్డర్ మొత్తం: ₹${total}\n` +
    `మునుపటి బాకీ: ₹${currentDue}\n` +
    `కొత్త మొత్తం బాకీ: ₹${newDue}\n\n` +
    `ఈ మొత్తాన్ని కస్టమర్ ఖాతా పుస్తకంలో బాకీగా నమోదు చేసి, ఆర్డర్‌ను డెలివరీ చేయాలా?`
  );
  if (!conf) return;

  await updateOnlineOrderStatusAdmin(orderId, 'DELIVERED', 'KHATA', true);
  sendOnlineOrderWhatsApp(name, phone, '', total, 'KHATA');
};

window.updateOnlineOrderStatusAdmin = async function(orderId, newStatus, paymentStatus = null, addToKhata = false) {
  try {
    const payload = { status: newStatus };
    if (paymentStatus) payload.payment_status = paymentStatus;
    if (addToKhata) payload.add_to_khata = true;

    const res = await fetch(`${API_BASE}/orders/online/${orderId}/status`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });

    const data = await res.json();
    if (res.ok && data.success) {
      showToast(addToKhata ? `Order delivered and ₹${data.order ? data.order.total_amount : ''} added to customer Khata!` : `Order status updated to ${newStatus}`);
      loadOnlineOrdersAdmin();
    } else {
      showToast('Error: ' + (data.error || 'Failed to update status'), 'error');
    }
  } catch (err) {
    showToast('Failed to update order status: ' + err.message, 'error');
  }
};

window.sendOnlineOrderWhatsApp = function(name, phone, orderNum, total, currentStatus) {
  if (!phone) {
    showToast('Customer has no phone number', 'error');
    return;
  }
  const cleanPhone = phone.replace(/[^0-9]/g, '');
  const target = cleanPhone.length === 10 ? `91${cleanPhone}` : cleanPhone;

  let msg = `నమస్తే ${name} గారూ, UNIK NATURALS నుండి మీ ఆర్డర్ #${orderNum} (₹${total}) అప్డేట్: `;
  if (currentStatus === 'KHATA') {
    msg = `నమస్తే ${name} గారూ, మీ UNIK NATURALS ఆర్డర్ (₹${total}) డెలివరీ పూర్తయింది. ఈ మొత్తం మీ ఖాతా పుస్తకంలో (Khata Ledger) బాకీగా నమోదు చేయబడింది. ధన్యవాదాలు!`;
  } else if (currentStatus === 'NEW' || currentStatus === 'ACCEPTED') {
    msg += `మీ ఆర్డర్ ఆమోదించబడింది, మేము త్వరలోనే సిద్ధం చేస్తున్నాము.`;
  } else if (currentStatus === 'PACKING') {
    msg += `మీ ఆర్డర్ ప్యాకింగ్ అవుతోంది, త్వరలోనే డెలివరీకి పంపుతాము.`;
  } else if (currentStatus === 'OUT_FOR_DELIVERY') {
    msg += `మీ ఆర్డర్ డెలివరీకి బయలుదేరింది! దయచేసి అందుబాటులో ఉండండి.`;
  } else if (currentStatus === 'DELIVERED') {
    msg += `మీ ఆర్డర్ విజయవంతంగా డెలివరీ పూర్తయింది. ధన్యవాదాలు!`;
  } else {
    msg += `ప్రస్తుత స్టేటస్: ${currentStatus}.`;
  }

  const url = `https://api.whatsapp.com/send?phone=${target}&text=${encodeURIComponent(msg)}`;
  window.open(url, '_blank');
};

// Initial boot
function initApp() {
  const user = getCurrentUser();
  if (user && user.role === 'ADMIN') {
    updateAuthUI();
    loadOverview();
  } else if (user && user.role === 'STAFF') {
    window.location.href = '/pos/';
  } else {
    updateAuthUI();
  }
}

initApp();

// Hook up online orders filter buttons & refresh
const filterBar = document.getElementById('online-orders-filter-bar');
if (filterBar) {
  filterBar.querySelectorAll('.online-filter-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      filterBar.querySelectorAll('.online-filter-btn').forEach(b => {
        b.classList.remove('active', 'btn-primary');
        b.classList.add('btn-secondary');
      });
      btn.classList.add('active', 'btn-primary');
      btn.classList.remove('btn-secondary');
      activeOnlineFilter = btn.getAttribute('data-status') || 'ALL';
      renderOnlineOrdersAdmin();
    });
  });
}

const refreshOnlineBtn = document.getElementById('btn-refresh-online-orders');
if (refreshOnlineBtn) {
  refreshOnlineBtn.addEventListener('click', () => {
    loadOnlineOrdersAdmin();
    showToast('Online orders refreshed');
  });
}


