const express = require('express');
const cors = require('cors');
const db = require('./database');

const path = require('path');
const app = express();
const PORT = process.env.PORT || 5000;

app.use(cors());
app.use(express.json({ limit: '20mb' }));
app.use(express.static(path.join(__dirname, '../admin_web')));
app.use('/uploads', express.static(path.join(__dirname, '../admin_web/uploads')));
app.use('/pos', express.static(path.join(__dirname, '../staff_mobile/build/web')));

// Helper for database queries with promises
function dbAll(query, params = []) {
  return new Promise((resolve, reject) => {
    db.all(query, params, (err, rows) => {
      if (err) reject(err);
      else resolve(rows);
    });
  });
}

function dbGet(query, params = []) {
  return new Promise((resolve, reject) => {
    db.get(query, params, (err, row) => {
      if (err) reject(err);
      else resolve(row);
    });
  });
}

function dbRun(query, params = []) {
  return new Promise((resolve, reject) => {
    db.run(query, params, function (err) {
      if (err) reject(err);
      else resolve({ lastID: this.lastID, changes: this.changes });
    });
  });
}

// ==================== 0. AUTHENTICATION & USERS ====================
app.post('/api/auth/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password are required' });
    }

    const user = await dbGet(
      'SELECT id, username, password, name, name_te, role, phone, is_active FROM users WHERE LOWER(username) = LOWER(?)',
      [username.trim()]
    );

    if (!user) {
      return res.status(401).json({ error: 'యూజర్ నేమ్ లేదా పాస్‌వర్డ్ తప్పు (Invalid username or password)' });
    }

    if (user.password !== password) {
      return res.status(401).json({ error: 'పాస్‌వర్డ్ సరిపోలలేదు (Invalid password)' });
    }

    if (!user.is_active) {
      return res.status(403).json({ error: 'ఖాతా నిలిపివేయబడింది (Account deactivated. Contact Admin)' });
    }

    const token = Buffer.from(`${user.id}:${user.username}:${Date.now()}`).toString('base64');

    res.json({
      success: true,
      token,
      user: {
        id: user.id,
        username: user.username,
        name: user.name,
        name_te: user.name_te,
        role: user.role,
        phone: user.phone
      }
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/auth/me', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader) {
      return res.status(401).json({ error: 'Not authenticated' });
    }
    const token = authHeader.replace(/^Bearer\s+/, '');
    const decoded = Buffer.from(token, 'base64').toString('utf-8');
    const [userId] = decoded.split(':');

    const user = await dbGet(
      'SELECT id, username, name, name_te, role, phone, is_active FROM users WHERE id = ?',
      [userId]
    );

    if (!user || !user.is_active) {
      return res.status(401).json({ error: 'User not found or inactive' });
    }

    res.json({
      user: {
        id: user.id,
        username: user.username,
        name: user.name,
        name_te: user.name_te,
        role: user.role,
        phone: user.phone
      }
    });
  } catch (err) {
    res.status(401).json({ error: 'Invalid session' });
  }
});

// Admin User Management
app.get('/api/users', async (req, res) => {
  try {
    const users = await dbAll('SELECT id, username, name, name_te, role, phone, is_active, created_at FROM users ORDER BY id');
    res.json(users);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/users', async (req, res) => {
  try {
    const { username, password, name, name_te, role, phone } = req.body;
    if (!username || !password || !name) {
      return res.status(400).json({ error: 'Username, password and name are required' });
    }
    const result = await dbRun(
      'INSERT INTO users (username, password, name, name_te, role, phone) VALUES (?, ?, ?, ?, ?, ?)',
      [username.trim(), password, name.trim(), name_te || null, role || 'STAFF', phone || null]
    );
    res.json({ id: result.lastID, success: true });
  } catch (err) {
    if (err.message && err.message.includes('UNIQUE constraint failed')) {
      return res.status(400).json({ error: 'Username already exists' });
    }
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/users/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { name, name_te, role, phone, password, is_active } = req.body;

    let query = 'UPDATE users SET name = ?, name_te = ?, role = ?, phone = ?, is_active = ?';
    let params = [name, name_te, role, phone, is_active ?? 1];

    if (password && password.trim().length > 0) {
      query += ', password = ?';
      params.push(password.trim());
    }

    query += ' WHERE id = ?';
    params.push(id);

    await dbRun(query, params);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/users/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const user = await dbGet('SELECT * FROM users WHERE id = ?', [id]);
    if (user && user.username === 'admin') {
      return res.status(400).json({ error: 'Primary admin user cannot be deleted' });
    }
    await dbRun('DELETE FROM users WHERE id = ?', [id]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ==================== 1. ITEMS / PRODUCTS ====================
app.get('/api/items', async (req, res) => {
  try {
    const { category } = req.query;
    let query = 'SELECT * FROM items WHERE is_active = 1';
    const params = [];
    if (category) {
      query += ' AND category = ?';
      params.push(category);
    }
    query += ' ORDER BY category, id';
    const items = await dbAll(query, params);
    res.json(items);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

function saveBase64Image(imageData, prefix = 'item') {
  if (!imageData || !imageData.startsWith('data:image')) return null;
  const matches = imageData.match(/^data:image\/([a-zA-Z0-9]+);base64,(.+)$/);
  if (!matches) return null;
  const ext = matches[1] === 'jpeg' ? 'jpg' : matches[1];
  const buffer = Buffer.from(matches[2], 'base64');
  const filename = `${prefix}_${Date.now()}_${Math.floor(Math.random() * 1000)}.${ext}`;
  const uploadsDir = path.join(__dirname, '../admin_web/uploads');
  if (!require('fs').existsSync(uploadsDir)) {
    require('fs').mkdirSync(uploadsDir, { recursive: true });
  }
  require('fs').writeFileSync(path.join(uploadsDir, filename), buffer);
  return `/uploads/${filename}`;
}

app.post('/api/items', async (req, res) => {
  try {
    const { name, name_te, category, unit, selling_price, cost_price, stock_qty, low_stock_threshold, image_url, image_data } = req.body;
    let finalUrl = image_url || null;
    if (image_data) {
      const saved = saveBase64Image(image_data, 'item');
      if (saved) finalUrl = saved;
    }

    const result = await dbRun(
      `INSERT INTO items (name, name_te, category, unit, selling_price, cost_price, stock_qty, low_stock_threshold, image_url)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [name, name_te, category, unit, selling_price, cost_price, stock_qty || 0, low_stock_threshold || 10, finalUrl]
    );
    res.json({ success: true, id: result.lastID, image_url: finalUrl });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/items/:id/image', async (req, res) => {
  try {
    const { id } = req.params;
    const { image_data, image_url } = req.body;
    let finalUrl = image_url;

    if (image_data && image_data.startsWith('data:image')) {
      const saved = saveBase64Image(image_data, `item_${id}`);
      if (saved) finalUrl = saved;
    }

    if (!finalUrl) {
      return res.status(400).json({ error: 'No image provided' });
    }

    await dbRun('UPDATE items SET image_url = ? WHERE id = ?', [finalUrl, id]);
    res.json({ success: true, image_url: finalUrl });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/items/:id/stock', async (req, res) => {
  try {
    const { stock_qty, selling_price, cost_price } = req.body;
    let updates = ['stock_qty = ?'];
    let params = [Number(stock_qty)];

    if (selling_price !== undefined && selling_price !== null && selling_price !== '') {
      updates.push('selling_price = ?');
      params.push(Number(selling_price));
    }
    if (cost_price !== undefined && cost_price !== null && cost_price !== '') {
      updates.push('cost_price = ?');
      params.push(Number(cost_price));
    }

    params.push(req.params.id);
    await dbRun(`UPDATE items SET ${updates.join(', ')} WHERE id = ?`, params);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ==================== 2. MILLING SERVICES ====================
app.get('/api/milling-services', async (req, res) => {
  try {
    const services = await dbAll('SELECT * FROM milling_services ORDER BY type, id');
    res.json(services);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/milling-services', async (req, res) => {
  try {
    const { name, name_te, type, rate_per_kg, unit } = req.body;
    if (!name || rate_per_kg === undefined) {
      return res.status(400).json({ error: 'Name and rate are required' });
    }
    const result = await dbRun(
      `INSERT INTO milling_services (name, name_te, type, rate_per_kg, unit)
       VALUES (?, ?, ?, ?, ?)`,
      [name, name_te || null, type || 'FLOUR', Number(rate_per_kg), unit || 'kg']
    );
    res.status(201).json({
      id: result.lastID,
      name,
      name_te,
      type: type || 'FLOUR',
      rate_per_kg: Number(rate_per_kg),
      unit: unit || 'kg'
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/milling-services/:id', async (req, res) => {
  try {
    const { name, name_te, type, rate_per_kg, unit } = req.body;
    const existing = await dbGet('SELECT * FROM milling_services WHERE id = ?', [req.params.id]);
    if (!existing) return res.status(404).json({ error: 'Milling service not found' });

    await dbRun(
      `UPDATE milling_services 
       SET name = ?, name_te = ?, type = ?, rate_per_kg = ?, unit = ?
       WHERE id = ?`,
      [
        name || existing.name,
        name_te !== undefined ? name_te : existing.name_te,
        type || existing.type,
        rate_per_kg !== undefined ? Number(rate_per_kg) : existing.rate_per_kg,
        unit || existing.unit,
        req.params.id
      ]
    );
    res.json({ success: true, message: 'Service updated successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/milling-services/:id', async (req, res) => {
  try {
    await dbRun('DELETE FROM milling_services WHERE id = ?', [req.params.id]);
    res.json({ success: true, message: 'Service deleted successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ==================== 3. RAW MATERIALS ====================
app.get('/api/raw-materials', async (req, res) => {
  try {
    const materials = await dbAll('SELECT * FROM raw_materials ORDER BY type, id');
    res.json(materials);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/raw-materials', async (req, res) => {
  try {
    const { name, name_te, type, unit, stock_qty, avg_cost_per_unit } = req.body;
    const result = await dbRun(
      `INSERT INTO raw_materials (name, name_te, type, unit, stock_qty, avg_cost_per_unit)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [name, name_te || null, type || 'SEEDS', unit || 'kg', Number(stock_qty || 0), Number(avg_cost_per_unit || 0)]
    );
    res.json({ success: true, id: result.lastID });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/raw-materials/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { name, name_te, type, unit, stock_qty, avg_cost_per_unit } = req.body;
    await dbRun(
      `UPDATE raw_materials 
       SET name = ?, name_te = ?, type = ?, unit = ?, stock_qty = ?, avg_cost_per_unit = ?
       WHERE id = ?`,
      [name, name_te || null, type, unit, Number(stock_qty || 0), Number(avg_cost_per_unit || 0), id]
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Record inward purchase of raw seeds or packaging containers
app.post('/api/raw-materials/:id/inward-purchase', async (req, res) => {
  try {
    const { id } = req.params;
    const { purchase_qty, purchase_rate, transport_cost, supplier_name, bill_number, log_as_expense } = req.body;
    const mat = await dbGet('SELECT * FROM raw_materials WHERE id = ?', [id]);
    if (!mat) return res.status(404).json({ error: 'Material not found' });

    const addedQty = Number(purchase_qty);
    const rate = Number(purchase_rate);
    const transport = Number(transport_cost || 0);
    const totalItemCost = Number(((addedQty * rate) + transport).toFixed(2));

    const currentQty = Number(mat.stock_qty || 0);
    const currentAvg = Number(mat.avg_cost_per_unit || 0);
    const newTotalQty = Number((currentQty + addedQty).toFixed(2));
    
    // Weighted average cost per unit
    const newAvgCost = newTotalQty > 0 
      ? Number((( (currentQty * currentAvg) + totalItemCost ) / newTotalQty).toFixed(2))
      : rate;

    await dbRun(
      'UPDATE raw_materials SET stock_qty = ?, avg_cost_per_unit = ? WHERE id = ?',
      [newTotalQty, newAvgCost, id]
    );

    // Optionally log in operating expenses
    if (log_as_expense) {
      const expCat = mat.type === 'PACKAGING' ? 'PACKAGING' : 'OTHER';
      const notes = `${mat.name} (${addedQty} ${mat.unit} @ ₹${rate} + ₹${transport} రవాణా) - ${supplier_name || 'వెండర్'} (బిల్: ${bill_number || 'N/A'})`;
      await dbRun(
        'INSERT INTO expenses (category, amount, notes) VALUES (?, ?, ?)',
        [expCat, totalItemCost, notes]
      );
    }

    res.json({
      success: true,
      id: Number(id),
      name: mat.name,
      added_qty: addedQty,
      new_stock_qty: newTotalQty,
      new_avg_cost: newAvgCost,
      total_purchase_amount: totalItemCost,
      message: `${mat.name} కొనుగోలు నిల్వ (${addedQty} ${mat.unit}) విజయవంతంగా అప్‌డేట్ చేయబడింది!`
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/raw-materials/:id', async (req, res) => {
  try {
    await dbRun('DELETE FROM raw_materials WHERE id = ?', [req.params.id]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ==================== 4. SALES & BILLING ====================
app.post('/api/sales', async (req, res) => {
  try {
    const { items, payment_mode, customer_phone, customer_name, customer_id, cash_paid, upi_paid, credit_amount, notes, created_by } = req.body;

    if (!items || items.length === 0) {
      return res.status(400).json({ error: 'No items in sale' });
    }

    let subtotal = 0;
    items.forEach(item => {
      subtotal += Number(item.rate) * Number(item.quantity);
    });

    const total_amount = subtotal;
    const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    const randomDigits = Math.floor(1000 + Math.random() * 9000);
    const bill_number = `BL-${dateStr}-${randomDigits}`;

    let finalCash = 0;
    let finalUpi = 0;
    let finalCredit = 0;

    if (payment_mode === 'CASH') {
      finalCash = total_amount;
    } else if (payment_mode === 'UPI') {
      finalUpi = total_amount;
    } else if (payment_mode === 'CREDIT') {
      finalCash = Number(cash_paid || 0);
      finalUpi = Number(upi_paid || 0);
      finalCredit = total_amount - finalCash - finalUpi;
      if (finalCredit < 0) finalCredit = 0;
    } else if (payment_mode === 'SPLIT') {
      finalCash = Number(cash_paid || 0);
      finalUpi = Number(upi_paid || 0);
      finalCredit = Number(credit_amount || 0);
    }

    let resolvedCustomerId = customer_id ? Number(customer_id) : null;
    let resolvedCustomerName = customer_name ? customer_name.trim() : null;

    // If there is credit amount, find or create the customer
    if (finalCredit > 0 || payment_mode === 'CREDIT') {
      if (resolvedCustomerId) {
        const cust = await dbGet('SELECT * FROM customers WHERE id = ?', [resolvedCustomerId]);
        if (cust) resolvedCustomerName = cust.name;
      } else if (customer_phone && customer_phone.trim()) {
        const phone = customer_phone.trim();
        let cust = await dbGet('SELECT * FROM customers WHERE phone = ?', [phone]);
        if (!cust) {
          const cName = resolvedCustomerName || `Customer (${phone})`;
          const cRes = await dbRun(
            'INSERT INTO customers (name, phone, total_credit_due) VALUES (?, ?, 0)',
            [cName, phone]
          );
          resolvedCustomerId = cRes.lastID;
          resolvedCustomerName = cName;
        } else {
          resolvedCustomerId = cust.id;
          resolvedCustomerName = cust.name;
        }
      } else if (resolvedCustomerName) {
        let cust = await dbGet('SELECT * FROM customers WHERE name = ?', [resolvedCustomerName]);
        if (!cust) {
          const cRes = await dbRun(
            'INSERT INTO customers (name, total_credit_due) VALUES (?, 0)',
            [resolvedCustomerName]
          );
          resolvedCustomerId = cRes.lastID;
        } else {
          resolvedCustomerId = cust.id;
        }
      }
    }

    const saleResult = await dbRun(
      `INSERT INTO sales (bill_number, subtotal, total_amount, payment_mode, cash_paid, upi_paid, credit_amount, customer_phone, customer_name, customer_id, created_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [bill_number, subtotal, total_amount, payment_mode, finalCash, finalUpi, finalCredit, customer_phone || null, resolvedCustomerName, resolvedCustomerId, created_by || 'Staff']
    );

    const saleId = saleResult.lastID;

    // If credit balance was added, record ledger entry and update customer balance
    if (finalCredit > 0 && resolvedCustomerId) {
      await dbRun(
        'UPDATE customers SET total_credit_due = total_credit_due + ? WHERE id = ?',
        [finalCredit, resolvedCustomerId]
      );

      const custRow = await dbGet('SELECT total_credit_due FROM customers WHERE id = ?', [resolvedCustomerId]);
      const newBal = custRow ? custRow.total_credit_due : finalCredit;

      await dbRun(
        `INSERT INTO customer_khata_transactions (customer_id, sale_id, type, amount, balance_after, notes)
         VALUES (?, ?, 'CREDIT_PURCHASE', ?, ?, ?)`,
        [resolvedCustomerId, saleId, finalCredit, newBal, notes || `Bill #${bill_number} (ఉద్దెర సరుకులు)`]
      );
    }

    // Insert sale items and update stock for products
    for (const item of items) {
      const lineTotal = Number(item.rate) * Number(item.quantity);
      await dbRun(
        `INSERT INTO sale_items (sale_id, item_type, reference_id, name, quantity, rate, total)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [saleId, item.item_type || 'PRODUCT', item.reference_id || null, item.name, item.quantity, item.rate, lineTotal]
      );

      // Decrement stock if product
      if (item.item_type === 'PRODUCT' && item.reference_id) {
        await dbRun(
          'UPDATE items SET stock_qty = stock_qty - ? WHERE id = ?',
          [item.quantity, item.reference_id]
        );
      }
    }

    res.json({
      success: true,
      sale_id: saleId,
      bill_number,
      total_amount,
      cash_paid: finalCash,
      upi_paid: finalUpi,
      credit_amount: finalCredit,
      customer_id: resolvedCustomerId,
      customer_name: resolvedCustomerName,
      payment_mode
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ==================== 5. CUSTOMER KHATA & CREDIT LEDGER ====================
app.get('/api/customers', async (req, res) => {
  try {
    const { search } = req.query;
    let query = 'SELECT * FROM customers';
    const params = [];
    if (search && search.trim()) {
      query += ' WHERE name LIKE ? OR phone LIKE ? OR name_te LIKE ?';
      const term = `%${search.trim()}%`;
      params.push(term, term, term);
    }
    query += ' ORDER BY total_credit_due DESC, name ASC';
    const customers = await dbAll(query, params);
    res.json(customers);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/customers', async (req, res) => {
  try {
    const { name, name_te, phone, address, credit_limit } = req.body;
    if (!name || !name.trim()) return res.status(400).json({ error: 'Name is required' });
    const result = await dbRun(
      `INSERT INTO customers (name, name_te, phone, address, credit_limit, total_credit_due)
       VALUES (?, ?, ?, ?, ?, 0)`,
      [name.trim(), name_te ? name_te.trim() : name.trim(), phone ? phone.trim() : null, address || null, credit_limit || 5000]
    );
    res.json({ success: true, id: result.lastID });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/customers/:id/ledger', async (req, res) => {
  try {
    const { id } = req.params;
    const customer = await dbGet('SELECT * FROM customers WHERE id = ?', [id]);
    if (!customer) return res.status(404).json({ error: 'Customer not found' });

    const transactions = await dbAll(
      `SELECT t.*, s.bill_number 
       FROM customer_khata_transactions t
       LEFT JOIN sales s ON t.sale_id = s.id
       WHERE t.customer_id = ?
       ORDER BY t.created_at DESC, t.id DESC`,
      [id]
    );
    res.json({ customer, transactions });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/customers/:id/payment', async (req, res) => {
  try {
    const { id } = req.params;
    const { amount, payment_mode, notes } = req.body;
    const payAmt = Number(amount);
    if (!payAmt || payAmt <= 0) {
      return res.status(400).json({ error: 'Valid payment amount is required' });
    }

    const customer = await dbGet('SELECT * FROM customers WHERE id = ?', [id]);
    if (!customer) return res.status(404).json({ error: 'Customer not found' });

    const newBalance = Math.max(0, customer.total_credit_due - payAmt);

    await dbRun(
      'UPDATE customers SET total_credit_due = ? WHERE id = ?',
      [newBalance, id]
    );

    const txResult = await dbRun(
      `INSERT INTO customer_khata_transactions (customer_id, type, amount, payment_mode, balance_after, notes)
       VALUES (?, 'PAYMENT_RECEIVED', ?, ?, ?, ?)`,
      [id, payAmt, payment_mode || 'CASH', newBalance, notes || `Khata payment received via ${payment_mode || 'CASH'}`]
    );

    res.json({
      success: true,
      transaction_id: txResult.lastID,
      paid_amount: payAmt,
      previous_balance: customer.total_credit_due,
      new_balance: newBalance
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/reports/khata-summary', async (req, res) => {
  try {
    const totals = await dbGet(`
      SELECT 
        COALESCE(SUM(total_credit_due), 0) as total_market_due,
        COUNT(CASE WHEN total_credit_due > 0 THEN 1 END) as customers_with_due,
        COUNT(*) as total_customers
      FROM customers
    `);

    const topDefaulters = await dbAll(`
      SELECT * FROM customers WHERE total_credit_due > 0 ORDER BY total_credit_due DESC LIMIT 10
    `);

    res.json({
      summary: totals,
      top_customers: topDefaulters
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Sales for today summary
app.get('/api/sales/today-summary', async (req, res) => {
  try {
    const today = new Date().toISOString().slice(0, 10);
    const summary = await dbGet(`
      SELECT 
        COUNT(*) as total_bills,
        COALESCE(SUM(total_amount), 0) as total_sales,
        COALESCE(SUM(cash_paid), 0) as total_cash,
        COALESCE(SUM(upi_paid), 0) as total_upi,
        COALESCE(SUM(credit_amount), 0) as total_credit
      FROM sales
      WHERE DATE(sale_time, 'localtime') = DATE('now', 'localtime')
    `);

    // Milling vs Retail breakdown
    const breakdown = await dbAll(`
      SELECT 
        si.item_type,
        COUNT(si.id) as count,
        COALESCE(SUM(si.total), 0) as total
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      WHERE DATE(s.sale_time, 'localtime') = DATE('now', 'localtime')
      GROUP BY si.item_type
    `);

    const khataTotals = await dbGet(`
      SELECT 
        COALESCE(SUM(total_credit_due), 0) as total_market_due,
        COUNT(CASE WHEN total_credit_due > 0 THEN 1 END) as customers_with_due
      FROM customers
    `);

    res.json({
      summary: summary || { total_bills: 0, total_sales: 0, total_cash: 0, total_upi: 0, total_credit: 0 },
      breakdown,
      khata: khataTotals || { total_market_due: 0, customers_with_due: 0 }
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Recent sales
app.get('/api/sales', async (req, res) => {
  try {
    const limit = req.query.limit || 50;
    const sales = await dbAll(`
      SELECT * FROM sales ORDER BY sale_time DESC LIMIT ?
    `, [limit]);
    res.json(sales);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Sale details with items
app.get('/api/sales/:id', async (req, res) => {
  try {
    const sale = await dbGet('SELECT * FROM sales WHERE id = ?', [req.params.id]);
    if (!sale) return res.status(404).json({ error: 'Sale not found' });
    const items = await dbAll('SELECT * FROM sale_items WHERE sale_id = ?', [req.params.id]);
    res.json({ ...sale, items });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ==================== 5. OIL EXTRACTION PRODUCTION ====================
app.post('/api/production/oil-batch', async (req, res) => {
  try {
    const { seed_name, seed_input_kg, seed_cost_per_kg, oil_output_litres, oil_output_kg, cake_output_kg, processing_cost, notes } = req.body;

    const inputKg = Number(seed_input_kg);
    let oilKg = Number(oil_output_kg || 0);
    let oilL = Number(oil_output_litres || 0);

    if (oilKg > 0 && (!oilL || oilL === 0)) {
      oilL = Number((oilKg / 0.91).toFixed(2));
    } else if (oilL > 0 && (!oilKg || oilKg === 0)) {
      oilKg = Number((oilL * 0.91).toFixed(2));
    }

    const cakeKg = Number(cake_output_kg);
    const wastageKg = Math.max(0, inputKg - (oilKg + cakeKg));
    const extractionPct = Number(((oilKg / inputKg) * 100).toFixed(2));

    const { start_time, end_time, duration_minutes, transport_cost } = req.body;
    const tinLabel = req.body.tin_label || `డ్రమ్ / టిన్ #${new Date().toLocaleDateString('en-GB')}`;
    const result = await dbRun(
      `INSERT INTO oil_batches 
       (seed_name, seed_input_kg, seed_cost_per_kg, oil_output_litres, oil_output_kg, cake_output_kg, wastage_kg, extraction_percentage, processing_cost, notes, status, tin_label, settled_oil_litres_remaining, start_time, end_time, duration_minutes, transport_cost)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'IN_TIN', ?, ?, ?, ?, ?, ?)`,
      [seed_name, inputKg, Number(seed_cost_per_kg), oilL, oilKg, cakeKg, Number(wastageKg.toFixed(2)), extractionPct, Number(processing_cost || 0), notes || null, tinLabel, oilL, start_time || null, end_time || null, duration_minutes ? Number(duration_minutes) : null, Number(transport_cost || 0)]
    );

    // Auto-update Oil Cake in item stock (Cake is ready immediately on crushing day!)
    await dbRun(
      `UPDATE items SET stock_qty = stock_qty + ? WHERE category = 'CAKE' LIMIT 1`,
      [cakeKg]
    );

    // Deduct seeds from raw materials if matching
    await dbRun(
      `UPDATE raw_materials SET stock_qty = MAX(0, stock_qty - ?) WHERE type = 'SEEDS' AND name LIKE ?`,
      [inputKg, `%${seed_name}%`]
    );

    // Auto-sync calculated batch production cost to inventory items cost_price (Purchase Cost)
    const newBatch = await dbGet('SELECT * FROM oil_batches WHERE id = ?', [result.lastID]);
    let syncedCostInfo = null;
    if (newBatch) {
      try {
        const syncRes = await syncBatchCostToInventory(newBatch);
        syncedCostInfo = syncRes.updatedItems;
      } catch (e) {
        console.error('Auto sync inventory cost failed:', e);
      }
    }

    res.json({
      success: true,
      batch_id: result.lastID,
      tin_label: tinLabel,
      oil_output_kg: oilKg,
      oil_output_litres: oilL,
      cake_output_kg: cakeKg,
      extraction_percentage: extractionPct,
      synced_costs: syncedCostInfo,
      wastage_kg: Number(wastageKg.toFixed(2))
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/production/pending-tins', async (req, res) => {
  try {
    const tins = await dbAll(`
      SELECT 
        id, 
        batch_date, 
        seed_name, 
        oil_output_kg, 
        oil_output_litres, 
        COALESCE(settled_oil_litres_remaining, oil_output_litres) AS settled_oil_litres_remaining,
        status, 
        COALESCE(tin_label, 'టిన్ / డ్రమ్ #' || id) AS tin_label,
        CAST(ROUND(JULIANDAY('now') - JULIANDAY(batch_date)) AS INTEGER) AS days_settled,
        created_at
      FROM oil_batches 
      WHERE (status = 'IN_TIN' OR status IS NULL)
        AND COALESCE(settled_oil_litres_remaining, oil_output_litres) > 0.1
      ORDER BY batch_date ASC, id ASC
    `);
    res.json(tins);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/production/oil-batches', async (req, res) => {
  try {
    const batches = await dbAll('SELECT * FROM oil_batches ORDER BY batch_date DESC, id DESC LIMIT 50');
    res.json(batches);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

async function calculateBatchCostBreakdown(batch) {
  const seedInputKg = Number(batch.seed_input_kg || 0);
  const seedCostPerKg = Number(batch.seed_cost_per_kg || 0);
  const rawSeedsCost = seedInputKg * seedCostPerKg;

  // Transport (stored or estimated ~₹1.50/kg)
  const transportCost = Number(batch.transport_cost !== null && batch.transport_cost !== undefined ? batch.transport_cost : (seedInputKg * 1.5));
  const processingCost = Number(batch.processing_cost || 0);

  // Machine duration details
  let durationMins = Number(batch.duration_minutes || 0);
  if (!durationMins && processingCost > 0) {
    durationMins = Math.round(processingCost / 1.45) || 90;
  } else if (!durationMins) {
    durationMins = Math.round((seedInputKg / 20) * 105);
  }

  // Single phase 5HP motor = 3.73 kW
  // Power bill @ ₹10 / unit (commercial tariff)
  const powerUnits = Number(((3.73 * (durationMins / 60))).toFixed(2));
  const powerCost = Number((powerUnits * 10.0).toFixed(2));
  // Labor wage @ ₹400 / 8-hr day (₹50/hr or ₹0.833/min)
  const laborCost = Number(((durationMins / 480) * 400).toFixed(2));

  const totalProcessingCost = processingCost > 0 ? processingCost : Number((powerCost + laborCost).toFixed(2));
  const grossCost = Number((rawSeedsCost + transportCost + totalProcessingCost).toFixed(2));

  // Oil cake recovery (market rate: ₹35/kg)
  const cakeOutputKg = Number(batch.cake_output_kg || 0);
  const cakeRate = 35.0;
  const cakeRecoveryValue = Number((cakeOutputKg * cakeRate).toFixed(2));

  // Net Bulk Oil Cost
  const netBulkOilCost = Math.max(0, Number((grossCost - cakeRecoveryValue).toFixed(2)));

  // Pure Settled Oil Litres (sludge loss ~4% or ~0.4L per 20kg batch)
  const grossOilLitres = Number(batch.oil_output_litres || 0);
  const sludgeLitres = Number((grossOilLitres * 0.04).toFixed(2));
  const pureSettledLitres = Math.max(0.1, Number((grossOilLitres - sludgeLitres).toFixed(2)));

  // Cost per Pure Bulk Litre
  const costPerBulkLitre = Number((netBulkOilCost / pureSettledLitres).toFixed(2));

  // Dynamic Selling Prices from items table
  const seedSearch = (batch.seed_name || '').split('/')[0].trim();
  const item1L = await dbGet("SELECT selling_price FROM items WHERE (name LIKE ? OR name_te LIKE ?) AND (name LIKE '%1L%' OR name LIKE '%1 L%') LIMIT 1", [`%${seedSearch}%`, `%${seedSearch}%`]);
  const item500ml = await dbGet("SELECT selling_price FROM items WHERE (name LIKE ? OR name_te LIKE ?) AND (name LIKE '%500ml%' OR name LIKE '%500 ml%') LIMIT 1", [`%${seedSearch}%`, `%${seedSearch}%`]);
  const item5L = await dbGet("SELECT selling_price FROM items WHERE (name LIKE ? OR name_te LIKE ?) AND (name LIKE '%5L%' OR name LIKE '%5 L%') LIMIT 1", [`%${seedSearch}%`, `%${seedSearch}%`]);

  const isSesame = (batch.seed_name || '').includes('Sesame') || (batch.seed_name || '').includes('నువ్వు');
  const price1L = item1L ? Number(item1L.selling_price) : (isSesame ? 340 : 240);
  const price500ml = item500ml ? Number(item500ml.selling_price) : (isSesame ? 175 : 125);
  const price5L = item5L ? Number(item5L.selling_price) : Math.round(price1L * 4.8);

  // Packaging Specs:
  // 1 Litre Bottle
  const packagingCost1L = 9.00 + 1.50 + 2.00; // ₹12.50
  const totalCost1L = Number((costPerBulkLitre * 1.0 + packagingCost1L).toFixed(2));
  const profit1L = Number((price1L - totalCost1L).toFixed(2));
  const margin1L = Number(((profit1L / price1L) * 100).toFixed(1));

  const cost1L = {
    oil_volume: '1.0 Ltr',
    oil_cost: Number((costPerBulkLitre * 1.0).toFixed(2)),
    bottle_cap_cost: 9.00,
    label_cost: 1.50,
    packing_labor: 2.00,
    packaging_total: packagingCost1L,
    total_production_cost: totalCost1L,
    selling_price: price1L,
    net_profit_per_bottle: profit1L,
    margin_pct: margin1L
  };

  // 500 ml Bottle
  const packagingCost500ml = 7.00 + 1.50 + 1.50; // ₹10.00
  const totalCost500ml = Number((costPerBulkLitre * 0.5 + packagingCost500ml).toFixed(2));
  const profit500ml = Number((price500ml - totalCost500ml).toFixed(2));
  const margin500ml = Number(((profit500ml / price500ml) * 100).toFixed(1));

  const cost500ml = {
    oil_volume: '500 ml',
    oil_cost: Number((costPerBulkLitre * 0.5).toFixed(2)),
    bottle_cap_cost: 7.00,
    label_cost: 1.50,
    packing_labor: 1.50,
    packaging_total: packagingCost500ml,
    total_production_cost: totalCost500ml,
    selling_price: price500ml,
    net_profit_per_bottle: profit500ml,
    margin_pct: margin500ml
  };

  // 5 Litre Can
  const packagingCost5L = 35.00 + 2.00 + 5.00; // ₹42.00
  const totalCost5L = Number((costPerBulkLitre * 5.0 + packagingCost5L).toFixed(2));
  const profit5L = Number((price5L - totalCost5L).toFixed(2));
  const margin5L = Number(((profit5L / price5L) * 100).toFixed(1));

  const cost5L = {
    oil_volume: '5.0 Ltr Can',
    oil_cost: Number((costPerBulkLitre * 5.0).toFixed(2)),
    bottle_cap_cost: 35.00,
    label_cost: 2.00,
    packing_labor: 5.00,
    packaging_total: packagingCost5L,
    total_production_cost: totalCost5L,
    selling_price: price5L,
    net_profit_per_bottle: profit5L,
    margin_pct: margin5L
  };

  return {
    raw_seeds_cost: rawSeedsCost,
    transport_cost: transportCost,
    processing_cost: totalProcessingCost,
    duration_minutes: durationMins,
    power_units: powerUnits,
    power_cost: powerCost,
    labor_cost: laborCost,
    gross_cost: grossCost,
    cake_output_kg: cakeOutputKg,
    cake_rate_per_kg: cakeRate,
    cake_recovery_value: cakeRecoveryValue,
    net_bulk_oil_cost: netBulkOilCost,
    gross_oil_litres: grossOilLitres,
    sludge_litres: sludgeLitres,
    pure_settled_litres: pureSettledLitres,
    cost_per_bulk_litre: costPerBulkLitre,
    cost_1L: cost1L,
    cost_500ml: cost500ml,
    cost_5L: cost5L
  };
}

// Helper to sync calculated batch cost into items table cost_price (Purchase Cost)
async function syncBatchCostToInventory(batch) {
  const breakdown = await calculateBatchCostBreakdown(batch);
  const seedName = batch.seed_name || '';
  const isGroundnut = seedName.includes('Groundnut') || seedName.includes('వేరుశనగ') || seedName.includes('పల్లీ');
  const isSesame = seedName.includes('Sesame') || seedName.includes('నువ్వు');
  const isMustard = seedName.includes('Mustard') || seedName.includes('ఆవాలు');
  const isCoconut = seedName.includes('Coconut') || seedName.includes('కొబ్బరి');

  const updatedItems = [];

  async function updateItemCost(nameFilter, newCost) {
    const item = await dbGet("SELECT id, name, cost_price FROM items WHERE (name LIKE ? OR name_te LIKE ?) LIMIT 1", [nameFilter, nameFilter]);
    if (item && newCost > 0) {
      await dbRun("UPDATE items SET cost_price = ? WHERE id = ?", [newCost, item.id]);
      updatedItems.push({ id: item.id, name: item.name, old_cost: item.cost_price, new_cost: newCost });
    }
  }

  if (isGroundnut) {
    await updateItemCost('%Groundnut%1L%', breakdown.cost_1L.total_production_cost);
    await updateItemCost('%Groundnut%500ml%', breakdown.cost_500ml.total_production_cost);
    await updateItemCost('%Groundnut%5L%', breakdown.cost_5L.total_production_cost);
    await updateItemCost('%Cake%1Kg%', breakdown.cake_rate_per_kg || 25);
  } else if (isSesame) {
    await updateItemCost('%Sesame%1L%', breakdown.cost_1L.total_production_cost);
    await updateItemCost('%Sesame%500ml%', breakdown.cost_500ml.total_production_cost);
  } else if (isMustard) {
    await updateItemCost('%Mustard%1L%', breakdown.cost_1L.total_production_cost);
    await updateItemCost('%Mustard%500ml%', breakdown.cost_500ml.total_production_cost);
  } else if (isCoconut) {
    await updateItemCost('%Coconut%1L%', breakdown.cost_1L.total_production_cost);
    await updateItemCost('%Coconut%500ml%', breakdown.cost_500ml.total_production_cost);
  }

  return { updatedItems, breakdown };
}

app.get('/api/production/batch-cost-breakdown/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const batch = await dbGet('SELECT * FROM oil_batches WHERE id = ?', [id]);
    if (!batch) {
      return res.status(404).json({ error: 'Batch not found' });
    }

    const breakdown = await calculateBatchCostBreakdown(batch);
    res.json({
      batch,
      ...breakdown
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Sync a specific batch's calculated production costs to inventory Purchase Cost
app.post('/api/production/sync-batch-cost-to-inventory/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const batch = await dbGet('SELECT * FROM oil_batches WHERE id = ?', [id]);
    if (!batch) return res.status(404).json({ error: 'Batch not found' });

    const result = await syncBatchCostToInventory(batch);
    res.json({
      success: true,
      message: `బ్యాచ్ #${id} ప్రకారం ఇన్వెంటరీలో ${result.updatedItems.length} ప్రొడక్టుల పర్చేజ్ కాస్ట్ అప్‌డేట్ చేయబడింది!`,
      updated: result.updatedItems
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Sync all latest oil batches to inventory
app.post('/api/production/sync-all-inventory-costs', async (req, res) => {
  try {
    const batches = await dbAll('SELECT * FROM oil_batches ORDER BY id DESC');
    const processedSeeds = new Set();
    const allUpdated = [];

    for (const b of batches) {
      const seedKey = (b.seed_name || '').split('/')[0].trim();
      if (!processedSeeds.has(seedKey)) {
        processedSeeds.add(seedKey);
        const { updatedItems } = await syncBatchCostToInventory(b);
        allUpdated.push(...updatedItems);
      }
    }

    res.json({
      success: true,
      message: `తాజా గానుగ బ్యాచుల ప్రకారం ఇన్వెంటరీలో ${allUpdated.length} ప్రొడక్టుల పర్చేజ్ కాస్ట్ అప్‌డేట్ చేయబడింది!`,
      updated: allUpdated
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ==================== 6. BOTTLING ====================
app.post('/api/production/bottling', async (req, res) => {
  try {
    const { item_id, bottles_packed, bulk_oil_litres_used, bottle_cost_per_unit, label_cost_per_unit, packs, sludge_waste_litres, batch_id, notes } = req.body;

    if (packs && Array.isArray(packs)) {
      // Multi-pack entry (e.g. 1L: 15, 500ml: 10, sludge discarded: 1.0)
      let totalPacked = 0;
      let totalLitres = 0;
      const results = [];

      for (const p of packs) {
        const pItemId = Number(p.item_id);
        const pCount = Number(p.bottles_packed || 0);
        const pLitres = Number(p.bulk_oil_litres_used || 0);
        if (pCount <= 0) continue;

        totalPacked += pCount;
        totalLitres += pLitres;

        const logRes = await dbRun(
          `INSERT INTO bottling_logs (item_id, bottles_packed, bulk_oil_litres_used, bottle_cost_per_unit, label_cost_per_unit, batch_id)
           VALUES (?, ?, ?, ?, ?, ?)`,
          [pItemId, pCount, pLitres, Number(p.bottle_cost_per_unit || 9), Number(p.label_cost_per_unit || 1.5), batch_id || null]
        );
        results.push(logRes.lastID);

        // Increase finished bottle stock
        await dbRun('UPDATE items SET stock_qty = stock_qty + ? WHERE id = ?', [pCount, pItemId]);

        // Deduct specific empty bottles from raw_materials
        const item = await dbGet('SELECT * FROM items WHERE id = ?', [pItemId]);
        if (item) {
          const is500ml = item.name.includes('500ml') || (item.name_te && item.name_te.includes('500'));
          const is5L = item.name.includes('5L') || (item.name_te && item.name_te.includes('5'));
          let matPattern = '%1L%';
          if (is500ml) matPattern = '%500ml%';
          else if (is5L) matPattern = '%5L%';

          await dbRun(
            `UPDATE raw_materials SET stock_qty = MAX(0, stock_qty - ?) WHERE type = 'PACKAGING' AND name LIKE ?`,
            [pCount, matPattern]
          );
        }
      }

      // Deduct label stickers (1 sticker per bottle packed)
      await dbRun(
        `UPDATE raw_materials SET stock_qty = MAX(0, stock_qty - ?) WHERE type = 'PACKAGING' AND (name LIKE '%Label%' OR name LIKE '%లేబుల్%')`,
        [totalPacked]
      );

      // If a specific tin batch was selected, update its remaining oil and status
      if (batch_id) {
        const batch = await dbGet('SELECT * FROM oil_batches WHERE id = ?', [batch_id]);
        if (batch) {
          const prevRem = Number(batch.settled_oil_litres_remaining !== null && batch.settled_oil_litres_remaining !== undefined ? batch.settled_oil_litres_remaining : batch.oil_output_litres);
          const usedTotal = totalLitres + Number(sludge_waste_litres || 0);
          const newRem = Math.max(0, Number((prevRem - usedTotal).toFixed(2)));
          if (newRem <= 0.5) {
            await dbRun(
              `UPDATE oil_batches SET status = 'BOTTLED', settled_oil_litres_remaining = 0, bottled_at = CURRENT_TIMESTAMP WHERE id = ?`,
              [batch_id]
            );
          } else {
            await dbRun(
              `UPDATE oil_batches SET settled_oil_litres_remaining = ?, notes = COALESCE(notes, '') || ' [పాక్షికంగా ప్యాక్ చేయబడింది / Partially bottled]' WHERE id = ?`,
              [newRem, batch_id]
            );
          }

          // Auto-sync calculated batch production costs to items purchase cost
          try {
            await syncBatchCostToInventory(batch);
          } catch (e) {
            console.error('Auto sync inventory cost on bottling:', e);
          }
        }
      }

      return res.json({
        success: true,
        total_bottles_packed: totalPacked,
        total_oil_litres_used: totalLitres,
        sludge_waste_litres: Number(sludge_waste_litres || 0),
        message: 'బాట్లింగ్ పూర్తయింది! ఫినిష్డ్ బాటిల్స్ స్టాక్ మరియు ఖాళీ బాటిల్స్/లేబుల్స్ అప్‌డేట్ అయ్యాయి.'
      });
    }

    // Single item fallback
    const result = await dbRun(
      `INSERT INTO bottling_logs (item_id, bottles_packed, bulk_oil_litres_used, bottle_cost_per_unit, label_cost_per_unit)
       VALUES (?, ?, ?, ?, ?)`,
      [item_id, bottles_packed, bulk_oil_litres_used, bottle_cost_per_unit || 0, label_cost_per_unit || 0]
    );

    // Increase packed bottle stock in items
    await dbRun('UPDATE items SET stock_qty = stock_qty + ? WHERE id = ?', [bottles_packed, item_id]);

    // Deduct empty packaging bottles & labels
    await dbRun(
      `UPDATE raw_materials SET stock_qty = MAX(0, stock_qty - ?) WHERE type = 'PACKAGING' LIMIT 1`,
      [bottles_packed]
    );

    res.json({ success: true, log_id: result.lastID });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ==================== 7. DAY-END CASH TALLY ====================
app.post('/api/day-end', async (req, res) => {
  try {
    const { actual_cash_counted, notes } = req.body;
    const today = new Date().toISOString().slice(0, 10);

    // Get today's system totals
    const system = await dbGet(`
      SELECT 
        COALESCE(SUM(total_amount), 0) as total_sales,
        COALESCE(SUM(cash_paid), 0) as cash_sales,
        COALESCE(SUM(upi_paid), 0) as upi_sales
      FROM sales
      WHERE DATE(sale_time, 'localtime') = DATE('now', 'localtime')
    `);

    const expectedCash = system.cash_sales;
    const upiSales = system.upi_sales;
    const totalSales = system.total_sales;
    const countedCash = Number(actual_cash_counted);
    const difference = countedCash - expectedCash;

    // Check if tally already exists for today
    const existing = await dbGet('SELECT id FROM day_end_tallies WHERE tally_date = ?', [today]);
    if (existing) {
      await dbRun(
        `UPDATE day_end_tallies 
         SET system_cash_sales = ?, system_upi_sales = ?, system_total_sales = ?, 
             actual_cash_counted = ?, cash_difference = ?, notes = ?, verified_at = CURRENT_TIMESTAMP
         WHERE id = ?`,
        [expectedCash, upiSales, totalSales, countedCash, difference, notes || null, existing.id]
      );
    } else {
      await dbRun(
        `INSERT INTO day_end_tallies 
         (tally_date, system_cash_sales, system_upi_sales, system_total_sales, actual_cash_counted, cash_difference, notes)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [today, expectedCash, upiSales, totalSales, countedCash, difference, notes || null]
      );
    }

    res.json({
      success: true,
      tally_date: today,
      system_cash_sales: expectedCash,
      system_upi_sales: upiSales,
      system_total_sales: totalSales,
      actual_cash_counted: countedCash,
      cash_difference: difference,
      status: difference === 0 ? 'PERFECT_MATCH' : (difference < 0 ? 'SHORTAGE' : 'EXCESS')
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/day-end/today', async (req, res) => {
  try {
    const today = new Date().toISOString().slice(0, 10);
    const tally = await dbGet('SELECT * FROM day_end_tallies WHERE tally_date = ?', [today]);
    res.json(tally || null);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/day-end/history', async (req, res) => {
  try {
    const history = await dbAll('SELECT * FROM day_end_tallies ORDER BY tally_date DESC LIMIT 30');
    res.json(history);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ==================== 8. EXPENSES ====================
app.get('/api/expenses', async (req, res) => {
  try {
    const expenses = await dbAll('SELECT * FROM expenses ORDER BY expense_date DESC, id DESC LIMIT 50');
    res.json(expenses);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/expenses', async (req, res) => {
  try {
    const { category, amount, notes, expense_date } = req.body;
    const date = expense_date || new Date().toISOString().slice(0, 10);
    const result = await dbRun(
      'INSERT INTO expenses (expense_date, category, amount, notes) VALUES (?, ?, ?, ?)',
      [date, category, Number(amount), notes || null]
    );
    res.json({ success: true, id: result.lastID });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ==================== 9. REAL PROFIT & LOSS (P&L) REPORT ====================
app.get('/api/reports/pnl', async (req, res) => {
  try {
    const { range } = req.query; // 'today', 'week', 'month', 'all'
    let dateCondition = "1=1";
    if (range === 'today') {
      dateCondition = "DATE(s.sale_time, 'localtime') = DATE('now', 'localtime')";
    } else if (range === 'week') {
      dateCondition = "DATE(s.sale_time, 'localtime') >= DATE('now', 'localtime', '-7 days')";
    } else if (range === 'month') {
      dateCondition = "DATE(s.sale_time, 'localtime') >= DATE('now', 'localtime', '-30 days')";
    }

    // 1. Total Sales Breakdown (Retail vs Milling)
    const salesData = await dbAll(`
      SELECT 
        si.item_type,
        COALESCE(SUM(si.total), 0) as revenue,
        COUNT(si.id) as item_count
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      WHERE ${dateCondition}
      GROUP BY si.item_type
    `);

    let productRevenue = 0;
    let millingRevenue = 0;
    salesData.forEach(row => {
      if (row.item_type === 'PRODUCT') productRevenue = row.revenue;
      if (row.item_type === 'MILLING') millingRevenue = row.revenue;
    });

    const totalRevenue = productRevenue + millingRevenue;

    // 2. Cost of Goods Sold (COGS) for products sold
    const cogsData = await dbGet(`
      SELECT 
        COALESCE(SUM(si.quantity * i.cost_price), 0) as total_cogs
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      LEFT JOIN items i ON si.reference_id = i.id
      WHERE si.item_type = 'PRODUCT' AND ${dateCondition}
    `);
    const cogs = cogsData ? cogsData.total_cogs : 0;

    // Gross Profit
    const grossProfit = totalRevenue - cogs;

    // 3. Operating Expenses for range
    let expCondition = "1=1";
    if (range === 'today') {
      expCondition = "expense_date = DATE('now', 'localtime')";
    } else if (range === 'week') {
      expCondition = "expense_date >= DATE('now', 'localtime', '-7 days')";
    } else if (range === 'month') {
      expCondition = "expense_date >= DATE('now', 'localtime', '-30 days')";
    }

    const expensesTotal = await dbGet(`
      SELECT COALESCE(SUM(amount), 0) as total_expenses FROM expenses WHERE ${expCondition}
    `);
    const totalExpenses = expensesTotal ? expensesTotal.total_expenses : 0;

    // Net Profit
    const netProfit = grossProfit - totalExpenses;
    const profitMarginPct = totalRevenue > 0 ? Number(((netProfit / totalRevenue) * 100).toFixed(1)) : 0;

    // Top Selling Items
    const topItems = await dbAll(`
      SELECT 
        si.name,
        SUM(si.quantity) as total_qty,
        SUM(si.total) as total_amount
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      WHERE ${dateCondition}
      GROUP BY si.name
      ORDER BY total_amount DESC
      LIMIT 5
    `);

    res.json({
      range: range || 'today',
      revenue: {
        retail_sales: productRevenue,
        milling_charges: millingRevenue,
        total_revenue: totalRevenue
      },
      costs: {
        cost_of_goods_sold: cogs,
        operating_expenses: totalExpenses,
        total_costs: cogs + totalExpenses
      },
      profitability: {
        gross_profit: grossProfit,
        net_profit: netProfit,
        profit_margin_percentage: profitMarginPct
      },
      top_items: topItems
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ==================== 13. ONLINE CUSTOMER ORDERING APIS ====================

// Get all products available for online customer ordering
app.get('/api/customer/products', async (req, res) => {
  try {
    const products = await dbAll(`
      SELECT id, name, name_te, category, unit, selling_price, stock_qty, 
             image_url, group_name, group_name_te, variant_name, variant_name_te
      FROM items
      WHERE is_active = 1
      ORDER BY category ASC, name ASC
    `);
    res.json(products);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Place a new online order from customer app/store
app.post('/api/customer/orders', async (req, res) => {
  try {
    const {
      customer_name,
      customer_phone,
      delivery_type,
      delivery_address,
      payment_mode,
      notes,
      items
    } = req.body;

    if (!customer_name || !customer_phone || !items || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'Customer name, phone, and items are required' });
    }

    const calcTotal = items.reduce((sum, it) => {
      const uPrice = Number(it.unit_price != null ? it.unit_price : (it.price != null ? it.price : (it.selling_price || 0)));
      const q = Number(it.quantity || 1);
      return sum + (uPrice * q);
    }, 0);
    const total_amount = req.body.total_amount != null ? Number(req.body.total_amount) : calcTotal;
    const order_number = 'ORD-' + Math.floor(100000 + Math.random() * 900000);

    const orderRes = await dbRun(`
      INSERT INTO online_orders (
        order_number, customer_name, customer_phone, delivery_type,
        delivery_address, total_amount, payment_mode, payment_status,
        order_status, notes
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'NEW', ?)
    `, [
      order_number,
      customer_name.trim(),
      customer_phone.trim(),
      delivery_type || 'DELIVERY',
      delivery_address ? delivery_address.trim() : null,
      total_amount,
      payment_mode || 'COD',
      payment_mode === 'UPI' ? 'PAID' : (payment_mode === 'KHATA' ? 'KHATA' : 'PENDING'),
      notes || null
    ]);

    const orderId = orderRes.lastID;

    // Insert order items
    for (const it of items) {
      const uPrice = Number(it.unit_price != null ? it.unit_price : (it.price != null ? it.price : (it.selling_price || 0)));
      const q = Number(it.quantity || 1);
      const itemTotal = it.total_price != null ? Number(it.total_price) : (uPrice * q);

      await dbRun(`
        INSERT INTO online_order_items (
          order_id, item_id, name, name_te, variant, unit_price, quantity, total_price, image_url
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `, [
        orderId,
        it.item_id || it.product_id || null,
        it.name,
        it.name_te || null,
        it.variant || null,
        uPrice,
        q,
        itemTotal,
        it.image_url || null
      ]);
    }

    // Upsert customer in customers table if not exists
    try {
      const existingCust = await dbGet('SELECT id FROM customers WHERE phone = ?', [customer_phone.trim()]);
      if (!existingCust) {
        await dbRun(`
          INSERT INTO customers (name, name_te, phone, address)
          VALUES (?, ?, ?, ?)
        `, [customer_name.trim(), customer_name.trim(), customer_phone.trim(), delivery_address || '']);
      }
    } catch (_) {}

    res.json({
      success: true,
      message: 'ఆర్డర్ విజయవంతంగా నమోదైంది (Order placed successfully!)',
      order: {
        id: orderId,
        order_number,
        customer_name,
        total_amount,
        delivery_type: delivery_type || 'DELIVERY',
        order_status: 'NEW'
      }
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Customer track orders by phone
app.get('/api/customer/orders/:phone', async (req, res) => {
  try {
    const phone = req.params.phone.trim();
    const orders = await dbAll(`
      SELECT * FROM online_orders
      WHERE customer_phone = ?
      ORDER BY created_at DESC
    `, [phone]);

    for (let ord of orders) {
      ord.items = await dbAll(`
        SELECT * FROM online_order_items WHERE order_id = ?
      `, [ord.id]);
    }

    res.json(orders);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Customer: Check Khata account balance by phone
app.get('/api/customer/khata-check/:phone', async (req, res) => {
  try {
    const phone = req.params.phone.trim();
    const customer = await dbGet('SELECT id, name, name_te, phone, total_credit_due FROM customers WHERE phone = ?', [phone]);
    if (customer) {
      res.json({
        found: true,
        customer_id: customer.id,
        name: customer.name,
        name_te: customer.name_te,
        total_credit_due: customer.total_credit_due || 0
      });
    } else {
      res.json({ found: false, total_credit_due: 0 });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Staff & Admin: Get all online orders with Customer Khata status
app.get('/api/orders/online', async (req, res) => {
  try {
    const { status } = req.query;
    let query = `
      SELECT o.*, c.total_credit_due as customer_khata_due, c.id as customer_db_id
      FROM online_orders o
      LEFT JOIN customers c ON o.customer_phone = c.phone
    `;
    const params = [];

    if (status) {
      query += ' WHERE o.order_status = ?';
      params.push(status);
    }
    query += ' ORDER BY o.created_at DESC';

    const orders = await dbAll(query, params);
    for (let ord of orders) {
      ord.items = await dbAll('SELECT * FROM online_order_items WHERE order_id = ?', [ord.id]);
    }
    res.json(orders);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Staff & Admin: Update online order status (with Khata posting support)
app.patch('/api/orders/online/:id/status', async (req, res) => {
  try {
    const { status, payment_status, payment_mode, add_to_khata } = req.body;
    const { id } = req.params;

    if (!status) {
      return res.status(400).json({ error: 'Status is required' });
    }

    const order = await dbGet('SELECT * FROM online_orders WHERE id = ?', [id]);
    if (!order) return res.status(404).json({ error: 'Order not found' });

    let query = 'UPDATE online_orders SET order_status = ?, updated_at = CURRENT_TIMESTAMP';
    const params = [status];

    const isKhata = add_to_khata === true || payment_status === 'KHATA' || payment_mode === 'KHATA';

    if (isKhata) {
      query += ', payment_mode = ?, payment_status = ?';
      params.push('KHATA', 'KHATA');
    } else {
      if (payment_mode) {
        query += ', payment_mode = ?';
        params.push(payment_mode);
      }
      if (payment_status) {
        query += ', payment_status = ?';
        params.push(payment_status);
      }
    }

    query += ' WHERE id = ?';
    params.push(id);

    await dbRun(query, params);

    let updatedBalance = 0;
    // If marked as Khata, record ledger entry and update customer balance
    if (isKhata) {
      const phone = order.customer_phone ? order.customer_phone.trim() : '';
      const name = order.customer_name ? order.customer_name.trim() : 'Customer';
      const address = order.delivery_address || '';
      const amount = Number(order.total_amount || 0);

      let customer = await dbGet('SELECT * FROM customers WHERE phone = ?', [phone]);
      let customerId;
      if (!customer) {
        const insRes = await dbRun(
          'INSERT INTO customers (name, name_te, phone, address, total_credit_due) VALUES (?, ?, ?, ?, ?)',
          [name, name, phone, address, amount]
        );
        customerId = insRes.lastID;
        updatedBalance = amount;
      } else {
        customerId = customer.id;
        await dbRun('UPDATE customers SET total_credit_due = total_credit_due + ? WHERE id = ?', [amount, customerId]);
        const custRow = await dbGet('SELECT total_credit_due FROM customers WHERE id = ?', [customerId]);
        updatedBalance = custRow ? custRow.total_credit_due : (customer.total_credit_due + amount);
      }

      await dbRun(
        `INSERT INTO customer_khata_transactions (customer_id, type, amount, balance_after, notes)
         VALUES (?, 'CREDIT_PURCHASE', ?, ?, ?)`,
        [customerId, amount, updatedBalance, `ఆన్‌లైన్ ఆర్డర్ #${order.order_number} (ఉద్దెర / ఖాతా బాకీ)`]
      );
    }

    res.json({
      success: true,
      message: isKhata
        ? `ఆర్డర్ #${order.order_number} డెలివరీ అయింది & మొత్తం ₹${order.total_amount} ఖాతాలో చేర్చబడింది! (కొత్త బాకీ: ₹${updatedBalance})`
        : `Order #${order.order_number} status updated to ${status}`,
      is_khata: isKhata,
      customer_due: updatedBalance
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'healthy', shop: 'Sri Lakshmi Oil & Flour Mill ERP' });
});

app.listen(PORT, () => {
  console.log(`Backend server running on http://localhost:${PORT}`);
});
