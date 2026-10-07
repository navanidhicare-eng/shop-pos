const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.resolve(__dirname, 'shop.db');
const db = new sqlite3.Database(dbPath, (err) => {
  if (err) {
    console.error('Error connecting to SQLite database:', err.message);
  } else {
    console.log('Connected to local SQLite database at:', dbPath);
  }
});

function initDatabase() {
  db.serialize(() => {
    // Enable WAL mode & performance optimizations for high-concurrency multi-user support
    db.run('PRAGMA journal_mode = WAL;');
    db.run('PRAGMA busy_timeout = 5000;');
    db.run('PRAGMA synchronous = NORMAL;');
    db.run('PRAGMA cache_size = -64000;');
    db.run('PRAGMA temp_store = MEMORY;');

    // 1. Items (Finished Goods & Retail Products)
    db.run(`
      CREATE TABLE IF NOT EXISTS items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        name_te TEXT,
        category TEXT NOT NULL, -- 'OIL', 'REPACK', 'SNACK', 'CAKE'
        unit TEXT NOT NULL,     -- 'bottle', 'packet', 'kg', 'can'
        selling_price REAL NOT NULL,
        cost_price REAL NOT NULL,
        stock_qty REAL DEFAULT 0,
        low_stock_threshold REAL DEFAULT 10,
        is_active INTEGER DEFAULT 1,
        image_url TEXT
      )
    `);

    // Ensure image_url column exists for existing DB
    db.run("ALTER TABLE items ADD COLUMN image_url TEXT", (err) => {
      // Column might already exist, ignore error
      // Populate photos for existing seed items if image_url is null
      db.run("UPDATE items SET image_url = '/uploads/groundnut_oil.jpg' WHERE name LIKE '%Groundnut Oil%' AND image_url IS NULL");
      db.run("UPDATE items SET image_url = '/uploads/sesame_oil.jpg' WHERE name LIKE '%Sesame%' AND image_url IS NULL");
      db.run("UPDATE items SET image_url = '/uploads/deepam_oil.jpg' WHERE name LIKE '%Deepam%' AND image_url IS NULL");
      db.run("UPDATE items SET image_url = '/uploads/oil_cake.jpg' WHERE name LIKE '%Cake%' AND image_url IS NULL");
      db.run("UPDATE items SET image_url = '/uploads/repack_peanuts.jpg' WHERE (name LIKE '%Groundnuts%' OR name LIKE '%Toor Dal%') AND image_url IS NULL");
      db.run("UPDATE items SET image_url = '/uploads/snack_mixture.jpg' WHERE (name LIKE '%Mixture%' OR name LIKE '%Murukku%') AND image_url IS NULL");
    });

    db.run("ALTER TABLE items ADD COLUMN group_name TEXT", () => {});
    db.run("ALTER TABLE items ADD COLUMN group_name_te TEXT", () => {});
    db.run("ALTER TABLE items ADD COLUMN variant_name TEXT", () => {});
    db.run("ALTER TABLE items ADD COLUMN variant_name_te TEXT", () => {});
    db.run("ALTER TABLE oil_batches ADD COLUMN oil_output_kg REAL", () => {});
    db.run("ALTER TABLE oil_batches ADD COLUMN status TEXT DEFAULT 'IN_TIN'", () => {});
    db.run("ALTER TABLE oil_batches ADD COLUMN tin_label TEXT", () => {});
    db.run("ALTER TABLE oil_batches ADD COLUMN settled_oil_litres_remaining REAL", () => {});
    db.run("ALTER TABLE oil_batches ADD COLUMN bottled_at DATETIME", () => {});
    db.run("ALTER TABLE bottling_logs ADD COLUMN batch_id INTEGER", () => {});
    db.run("UPDATE oil_batches SET status = 'IN_TIN' WHERE status IS NULL", () => {});
    db.run("UPDATE oil_batches SET tin_label = 'టిన్ / డ్రమ్ #' || id WHERE tin_label IS NULL", () => {});
    db.run("ALTER TABLE oil_batches ADD COLUMN start_time TEXT", () => {});
    db.run("ALTER TABLE oil_batches ADD COLUMN end_time TEXT", () => {});
    db.run("ALTER TABLE oil_batches ADD COLUMN duration_minutes INTEGER", () => {});
    db.run("ALTER TABLE oil_batches ADD COLUMN transport_cost REAL DEFAULT 0", () => {});
    db.run("INSERT OR IGNORE INTO raw_materials (name, name_te, type, unit, stock_qty, avg_cost_per_unit) SELECT 'Label Stickers (Front & Back)', 'బాటిల్ లేబుల్ స్టిక్కర్లు', 'PACKAGING', 'piece', 500, 1.5 WHERE NOT EXISTS (SELECT 1 FROM raw_materials WHERE name LIKE '%Label Stickers%')", () => {});

    // 2. Milling Services (Job Work Rates)
    db.run(`
      CREATE TABLE IF NOT EXISTS milling_services (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        name_te TEXT,
        type TEXT NOT NULL, -- 'FLOUR', 'OIL_CRUSH', 'SPICE'
        rate_per_kg REAL NOT NULL,
        unit TEXT DEFAULT 'kg'
      )
    `);

    // 3. Raw Materials (Seeds, Empty Bottles, Packaging Pouches)
    db.run(`
      CREATE TABLE IF NOT EXISTS raw_materials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        name_te TEXT,
        type TEXT NOT NULL, -- 'SEEDS', 'PACKAGING', 'BULK_FOOD'
        unit TEXT NOT NULL, -- 'kg', 'piece'
        stock_qty REAL DEFAULT 0,
        avg_cost_per_unit REAL DEFAULT 0
      )
    `);

    // 4. Sales Orders
    db.run(`
      CREATE TABLE IF NOT EXISTS sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bill_number TEXT UNIQUE NOT NULL,
        sale_time DATETIME DEFAULT CURRENT_TIMESTAMP,
        subtotal REAL NOT NULL,
        discount REAL DEFAULT 0,
        total_amount REAL NOT NULL,
        payment_mode TEXT NOT NULL, -- 'CASH', 'UPI', 'SPLIT'
        cash_paid REAL DEFAULT 0,
        upi_paid REAL DEFAULT 0,
        customer_phone TEXT
      )
    `);

    // 5. Sale Items
    db.run(`
      CREATE TABLE IF NOT EXISTS sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        item_type TEXT NOT NULL, -- 'PRODUCT', 'MILLING'
        reference_id INTEGER,
        name TEXT NOT NULL,
        quantity REAL NOT NULL,
        rate REAL NOT NULL,
        total REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
      )
    `);

    // 6. Oil Extraction Batches (Raw Seeds -> Bulk Oil + Oil Cake)
    db.run(`
      CREATE TABLE IF NOT EXISTS oil_batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batch_date DATE DEFAULT (DATE('now')),
        seed_name TEXT NOT NULL,
        seed_input_kg REAL NOT NULL,
        seed_cost_per_kg REAL NOT NULL,
        oil_output_litres REAL NOT NULL,
        cake_output_kg REAL NOT NULL,
        wastage_kg REAL DEFAULT 0,
        extraction_percentage REAL,
        processing_cost REAL DEFAULT 0, -- Electricity + labor estimate
        notes TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // 7. Bottling Logs (Bulk Oil -> 500ml, 1L, 5L Finished Bottles)
    db.run(`
      CREATE TABLE IF NOT EXISTS bottling_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        log_date DATE DEFAULT (DATE('now')),
        item_id INTEGER NOT NULL,
        bottles_packed INTEGER NOT NULL,
        bulk_oil_litres_used REAL NOT NULL,
        bottle_cost_per_unit REAL DEFAULT 0,
        label_cost_per_unit REAL DEFAULT 0,
        FOREIGN KEY (item_id) REFERENCES items (id)
      )
    `);

    // 8. Day-End Cash Tallies (Evening Drawer Settlement)
    db.run(`
      CREATE TABLE IF NOT EXISTS day_end_tallies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tally_date DATE UNIQUE NOT NULL,
        system_cash_sales REAL NOT NULL,
        system_upi_sales REAL NOT NULL,
        system_total_sales REAL NOT NULL,
        actual_cash_counted REAL NOT NULL,
        cash_difference REAL NOT NULL, -- actual - system
        notes TEXT,
        verified_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // 9. Expenses (Daily shop & mill expenses)
    db.run(`
      CREATE TABLE IF NOT EXISTS expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        expense_date DATE DEFAULT (DATE('now')),
        category TEXT NOT NULL, -- 'ELECTRICITY', 'RENT', 'LABOR', 'MAINTENANCE', 'TEA_SNACKS', 'OTHER'
        amount REAL NOT NULL,
        notes TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // 10. Customers (Khata / Credit Customers)
    db.run(`
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        name_te TEXT,
        phone TEXT UNIQUE,
        address TEXT,
        total_credit_due REAL DEFAULT 0,
        credit_limit REAL DEFAULT 5000,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // 11. Customer Khata Ledger Transactions
    db.run(`
      CREATE TABLE IF NOT EXISTS customer_khata_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        sale_id INTEGER,
        type TEXT NOT NULL, -- 'CREDIT_PURCHASE', 'PAYMENT_RECEIVED'
        amount REAL NOT NULL,
        payment_mode TEXT, -- 'CASH', 'UPI' (for repayments)
        balance_after REAL NOT NULL,
        notes TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE SET NULL
      )
    `);

    // Migrations for existing sales table
    db.run("ALTER TABLE sales ADD COLUMN customer_name TEXT", () => {});
    db.run("ALTER TABLE sales ADD COLUMN customer_id INTEGER", () => {});
    db.run("ALTER TABLE sales ADD COLUMN credit_amount REAL DEFAULT 0", () => {});
    db.run("ALTER TABLE sales ADD COLUMN created_by TEXT", () => {});

    // Seed Khata Customers if empty
    db.get('SELECT COUNT(*) as count FROM customers', (err, row) => {
      if (err) return;
      if (row.count === 0) {
        console.log('Seeding initial Khata credit customers...');
        const stmt = db.prepare(`
          INSERT INTO customers (name, name_te, phone, address, total_credit_due, credit_limit)
          VALUES (?, ?, ?, ?, ?, ?)
        `);

        const seedCustomers = [
          ['K. Srinivasa Rao', 'కె. శ్రీనివాస రావు', '9848012345', 'Main Bazaar, Shop #4', 450, 5000],
          ['M. Venkat Reddy', 'ఎం. వెంకట్ రెడ్డి', '9988776655', 'Bazaar Street, Near Temple', 1200, 10000],
          ['Sri Balaji Tiffin Center', 'శ్రీ బాలాజీ టిఫిన్ సెంటర్', '9440112233', 'Station Road', 2800, 15000],
          ['G. Lakshmi Narayana', 'జి. లక్ష్మీ నారాయణ', '9123456789', 'Gandhi Nagar', 0, 3000]
        ];

        seedCustomers.forEach(c => stmt.run(c));
        stmt.finalize();

        // Seed initial opening transactions for the seed customers
        db.all('SELECT id, total_credit_due FROM customers WHERE total_credit_due > 0', (err, custs) => {
          if (!err && custs) {
            custs.forEach(c => {
              db.run(`
                INSERT INTO customer_khata_transactions (customer_id, type, amount, balance_after, notes)
                VALUES (?, 'CREDIT_PURCHASE', ?, ?, 'Opening credit balance (పాత బాకీ)')
              `, [c.id, c.total_credit_due, c.total_credit_due]);
            });
          }
        });
      }
    });

    // Seed Initial Data if empty
    db.get('SELECT COUNT(*) as count FROM items', (err, row) => {
      if (err) return;
      if (row.count === 0) {
        console.log('Seeding initial shop items...');
        const stmt = db.prepare(`
          INSERT INTO items (name, name_te, category, unit, selling_price, cost_price, stock_qty, low_stock_threshold)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `);

        const seedItems = [
          ['Groundnut Oil 1L', 'పల్లీ నూనె 1 లీటర్', 'OIL', 'bottle', 180, 140, 50, 10],
          ['Groundnut Oil 500ml', 'పల్లీ నూనె 500 ml', 'OIL', 'bottle', 95, 72, 35, 10],
          ['Groundnut Oil 5L', 'పల్లీ నూనె 5 లీటర్ల క్యాన్', 'OIL', 'can', 880, 690, 12, 5],
          ['Sesame (Til) Oil 1L', 'నువ్వుల నూనె 1 లీటర్', 'OIL', 'bottle', 320, 250, 20, 5],
          ['Sesame (Til) Oil 500ml', 'నువ్వుల నూనె 500 ml', 'OIL', 'bottle', 165, 128, 25, 5],
          ['Pooja / Deepam Oil 1L', 'దీపం నూనె 1 లీటర్', 'OIL', 'bottle', 130, 95, 40, 10],
          ['Groundnut Oil Cake 1Kg', 'పల్లీ చెక్క / పిండి (కేజీ)', 'CAKE', 'kg', 35, 22, 120, 25],
          ['Repacked Groundnuts 1Kg', 'పల్లీలు 1 కేజీ ప్యాకెట్', 'REPACK', 'packet', 130, 108, 30, 8],
          ['Repacked Groundnuts 500g', 'పల్లీలు 500 గ్రాములు', 'REPACK', 'packet', 68, 55, 40, 10],
          ['Repacked Toor Dal 1Kg', 'కందిపప్పు 1 కేజీ ప్యాకెట్', 'REPACK', 'packet', 165, 142, 25, 6],
          ['Special Mixture 500g', 'హాట్ మిక్చర్ 500 గ్రాములు', 'SNACK', 'packet', 110, 70, 20, 5],
          ['Murukku / Chekkalu 500g', 'మురుకులు / చెక్కలు 500 గ్రాములు', 'SNACK', 'packet', 100, 65, 18, 5]
        ];

        seedItems.forEach(item => stmt.run(item));
        stmt.finalize();
      }
    });

    db.get('SELECT COUNT(*) as count FROM milling_services', (err, row) => {
      if (err) return;
      if (row.count === 0) {
        console.log('Seeding milling services rates...');
        const stmt = db.prepare(`
          INSERT INTO milling_services (name, name_te, type, rate_per_kg, unit)
          VALUES (?, ?, ?, ?, ?)
        `);

        const seedMilling = [
          ['Wheat / Rice Flour', 'గోధుమ / బియ్యం పిండి', 'FLOUR', 8, 'kg'],
          ['Ragi / Jowar Millets', 'రాగులు / జొన్నల పిండి', 'FLOUR', 10, 'kg'],
          ['Mirchi / Chilli Grinding', 'కారం కొట్టడం', 'SPICE', 25, 'kg'],
          ['Turmeric / Masala', 'పసుపు / మసాలా పిండి', 'SPICE', 30, 'kg'],
          ['Groundnut Oil Expelling', 'పల్లీ గానుగ ఆడించడం', 'OIL_CRUSH', 15, 'kg'],
          ['Sesame Oil Expelling', 'నువ్వుల గానుగ ఆడించడం', 'OIL_CRUSH', 20, 'kg']
        ];

        seedMilling.forEach(s => stmt.run(s));
        stmt.finalize();
      }
    });

    db.get('SELECT COUNT(*) as count FROM raw_materials', (err, row) => {
      if (err) return;
      if (row.count === 0) {
        console.log('Seeding raw materials...');
        const stmt = db.prepare(`
          INSERT INTO raw_materials (name, name_te, type, unit, stock_qty, avg_cost_per_unit)
          VALUES (?, ?, ?, ?, ?, ?)
        `);

        const seedRaw = [
          ['Raw Groundnut Seeds', 'పల్లీ గింజలు', 'SEEDS', 'kg', 500, 85],
          ['Raw Sesame Seeds', 'నువ్వులు', 'SEEDS', 'kg', 150, 150],
          ['Empty 1L Bottles + Caps', 'ఖాళీ 1L బాటిల్స్ & మూతలు', 'PACKAGING', 'piece', 200, 9],
          ['Empty 500ml Bottles + Caps', 'ఖాళీ 500ml బాటిల్స్ & మూతలు', 'PACKAGING', 'piece', 250, 7],
          ['Empty 5L Cans', 'ఖాళీ 5L క్యాన్లు', 'PACKAGING', 'piece', 50, 35],
          ['Pouch Covers 1Kg / 500g', 'ప్యాకింగ్ కవర్లు', 'PACKAGING', 'piece', 500, 1.5]
        ];

        seedRaw.forEach(r => stmt.run(r));
        stmt.finalize();
      }
    });

    // 12. Users (Admin, Staff authentication)
    db.run(`
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        name TEXT NOT NULL,
        name_te TEXT,
        role TEXT NOT NULL, -- 'ADMIN', 'STAFF'
        phone TEXT,
        is_active INTEGER DEFAULT 1,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);

    db.get('SELECT COUNT(*) as count FROM users', (err, row) => {
      if (err) return;
      if (row.count === 0) {
        console.log('Seeding initial system users (Admin & Staff)...');
        const stmt = db.prepare(`
          INSERT INTO users (username, password, name, name_te, role, phone)
          VALUES (?, ?, ?, ?, ?, ?)
        `);

        stmt.run(['admin', 'admin123', 'Shop Owner / Admin', 'షాప్ యజమాని (ఓనర్)', 'ADMIN', '9848012345']);
        stmt.run(['staff', 'staff123', 'Counter Staff / Cashier', 'బిల్లింగ్ స్టాఫ్', 'STAFF', '9988776655']);
        stmt.finalize();
      }
    });

    // 13. Online Orders (Customer Mobile/Web E-Commerce Orders)
    db.run(`
      CREATE TABLE IF NOT EXISTS online_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_number TEXT UNIQUE NOT NULL,
        customer_name TEXT NOT NULL,
        customer_phone TEXT NOT NULL,
        delivery_type TEXT NOT NULL DEFAULT 'DELIVERY',
        delivery_address TEXT,
        total_amount REAL NOT NULL,
        payment_mode TEXT NOT NULL DEFAULT 'COD',
        payment_status TEXT NOT NULL DEFAULT 'PENDING',
        order_status TEXT NOT NULL DEFAULT 'NEW',
        notes TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);

    db.run(`
      CREATE TABLE IF NOT EXISTS online_order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        item_id INTEGER,
        name TEXT NOT NULL,
        name_te TEXT,
        variant TEXT,
        unit_price REAL NOT NULL,
        quantity REAL NOT NULL,
        total_price REAL NOT NULL,
        image_url TEXT,
        FOREIGN KEY (order_id) REFERENCES online_orders(id) ON DELETE CASCADE
      )
    `);
  });
}

initDatabase();

module.exports = db;
