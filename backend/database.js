const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
require('dotenv').config({ path: path.resolve(__dirname, '.env') });
const { types, Pool } = require('pg');
const sqlite3 = require('sqlite3').verbose();

// Determine database type: defaults to postgres in Docker/production, but allows explicit DB_TYPE=sqlite
const isPostgres = process.env.DB_TYPE !== 'sqlite' && (
  process.env.DB_TYPE === 'postgres' || Boolean(process.env.DATABASE_URL || process.env.DB_HOST)
);

let pool = null;
let sqliteDb = null;

// Configure node-pg parsers for PostgreSQL so data types seamlessly match SQLite formats
if (isPostgres) {
  // Parse NUMERIC / DECIMAL (type 1700) and BIGINT (type 20) as JS Numbers
  types.setTypeParser(1700, (val) => (val === null ? null : parseFloat(val)));
  types.setTypeParser(20, (val) => (val === null ? null : parseInt(val, 10)));
  // Keep DATE (OID 1082) as 'YYYY-MM-DD' string to match SQLite format expected by frontend
  types.setTypeParser(1082, (val) => val);

  const poolConfig = process.env.DATABASE_URL
    ? {
        connectionString: process.env.DATABASE_URL,
        ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false
      }
    : {
        host: process.env.DB_HOST || 'localhost',
        port: parseInt(process.env.DB_PORT || '5432', 10),
        user: process.env.DB_USER || 'postgres',
        password: process.env.DB_PASSWORD || 'postgres',
        database: process.env.DB_NAME || 'shop_db',
        ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false
      };

  pool = new Pool(poolConfig);
  pool.on('error', (err) => {
    console.error('Unexpected error on idle PostgreSQL client:', err);
  });
  console.log(`Configured PostgreSQL connection to: ${process.env.DB_HOST || 'DATABASE_URL'}/${process.env.DB_NAME || ''}`);
} else {
  const dbPath = process.env.SQLITE_DB_PATH || path.resolve(__dirname, 'shop.db');
  sqliteDb = new sqlite3.Database(dbPath, (err) => {
    if (err) {
      console.error('Error connecting to SQLite database:', err.message);
    } else {
      console.log('Connected to local SQLite database at:', dbPath);
    }
  });
}

// Convert SQLite parameter placeholders (?) and functions to PostgreSQL syntax ($1, $2, ...)
function adaptQueryForPostgres(sql) {
  let paramIdx = 1;
  let inString = false;
  let converted = '';

  for (let i = 0; i < sql.length; i++) {
    const ch = sql[i];
    if (ch === "'") {
      if (inString && sql[i + 1] === "'") {
        converted += "''";
        i++;
        continue;
      }
      inString = !inString;
      converted += ch;
    } else if (ch === '?' && !inString) {
      converted += `$${paramIdx++}`;
    } else {
      converted += ch;
    }
  }

  // Convert SQLite date functions to standard PostgreSQL functions
  converted = converted
    .replace(/DATE\(\s*([a-zA-Z0-9_\.]+)\s*,\s*'localtime'\s*\)/gi, 'DATE($1)')
    .replace(/DATE\(\s*'now'\s*,\s*'localtime'\s*,\s*'-(\d+)\s+days'\s*\)/gi, "(CURRENT_DATE - INTERVAL '$1 days')")
    .replace(/DATE\(\s*'now'\s*,\s*'localtime'\s*\)/gi, 'CURRENT_DATE')
    .replace(/DATE\(\s*'now'\s*\)/gi, 'CURRENT_DATE')
    .replace(/CAST\s*\(\s*ROUND\s*\(\s*JULIANDAY\('now'\)\s*-\s*JULIANDAY\(([^)]+)\)\s*\)\s*AS\s*INTEGER\s*\)/gi, "(CURRENT_DATE - CAST($1 AS DATE))")
    .replace(/\|\s*id\b/gi, '|| CAST(id AS TEXT)');

  return converted;
}

// Promise wrapper: dbAll (returns array of rows)
function dbAll(query, params = []) {
  if (isPostgres) {
    const pgSql = adaptQueryForPostgres(query);
    return pool.query(pgSql, params).then((res) => res.rows);
  }
  return new Promise((resolve, reject) => {
    sqliteDb.all(query, params, (err, rows) => {
      if (err) reject(err);
      else resolve(rows || []);
    });
  });
}

// Promise wrapper: dbGet (returns single row or undefined)
function dbGet(query, params = []) {
  if (isPostgres) {
    const pgSql = adaptQueryForPostgres(query);
    return pool.query(pgSql, params).then((res) => res.rows[0]);
  }
  return new Promise((resolve, reject) => {
    sqliteDb.get(query, params, (err, row) => {
      if (err) reject(err);
      else resolve(row);
    });
  });
}

// Promise wrapper: dbRun (returns { lastID, changes })
function dbRun(query, params = []) {
  if (isPostgres) {
    let pgSql = adaptQueryForPostgres(query);
    const isInsert = /^\s*INSERT\s+INTO\s+/i.test(pgSql);
    const hasReturning = /\bRETURNING\b/i.test(pgSql);

    if (isInsert && !hasReturning) {
      pgSql += ' RETURNING id';
    }

    return pool.query(pgSql, params).then((res) => ({
      lastID: res.rows && res.rows[0] && res.rows[0].id ? res.rows[0].id : null,
      changes: res.rowCount || 0
    }));
  }

  return new Promise((resolve, reject) => {
    sqliteDb.run(query, params, function (err) {
      if (err) reject(err);
      else resolve({ lastID: this.lastID, changes: this.changes });
    });
  });
}

// ==================== SCHEMA INITIALIZATION ====================
let isInitializing = false;
let isInitialized = false;

async function initDatabase(retries = 5, delayMs = 2000) {
  if (isInitialized) return true;
  if (isInitializing) {
    while (isInitializing) {
      await new Promise((r) => setTimeout(r, 200));
    }
    return isInitialized;
  }

  isInitializing = true;
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      if (isPostgres) {
        await initPostgresDatabase();
      } else {
        initSqliteDatabase();
      }
      isInitialized = true;
      isInitializing = false;
      console.log('Database schema successfully initialized and verified.');
      return true;
    } catch (err) {
      console.error(`Database initialization attempt ${attempt}/${retries} failed:`, err.message);
      if (attempt < retries) {
        await new Promise((r) => setTimeout(r, delayMs));
      } else {
        isInitializing = false;
        throw err;
      }
    }
  }
}

async function initPostgresDatabase() {
  console.log('Initializing PostgreSQL database tables & schema...');

  // 1. Items
  await pool.query(`
    CREATE TABLE IF NOT EXISTS items (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      name_te TEXT,
      category TEXT NOT NULL,
      unit TEXT NOT NULL,
      selling_price DOUBLE PRECISION NOT NULL,
      cost_price DOUBLE PRECISION NOT NULL,
      stock_qty DOUBLE PRECISION DEFAULT 0,
      low_stock_threshold DOUBLE PRECISION DEFAULT 10,
      is_active INTEGER DEFAULT 1,
      image_url TEXT,
      group_name TEXT,
      group_name_te TEXT,
      variant_name TEXT,
      variant_name_te TEXT
    );
  `);

  // Ensure columns exist for items
  await pool.query('ALTER TABLE items ADD COLUMN IF NOT EXISTS image_url TEXT;');
  await pool.query('ALTER TABLE items ADD COLUMN IF NOT EXISTS group_name TEXT;');
  await pool.query('ALTER TABLE items ADD COLUMN IF NOT EXISTS group_name_te TEXT;');
  await pool.query('ALTER TABLE items ADD COLUMN IF NOT EXISTS variant_name TEXT;');
  await pool.query('ALTER TABLE items ADD COLUMN IF NOT EXISTS variant_name_te TEXT;');
  await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS address TEXT;');

  // 2. Milling Services
  await pool.query(`
    CREATE TABLE IF NOT EXISTS milling_services (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      name_te TEXT,
      type TEXT NOT NULL,
      rate_per_kg DOUBLE PRECISION NOT NULL,
      unit TEXT DEFAULT 'kg'
    );
  `);

  // 3. Raw Materials
  await pool.query(`
    CREATE TABLE IF NOT EXISTS raw_materials (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      name_te TEXT,
      type TEXT NOT NULL,
      unit TEXT NOT NULL,
      stock_qty DOUBLE PRECISION DEFAULT 0,
      avg_cost_per_unit DOUBLE PRECISION DEFAULT 0
    );
  `);

  // 4. Sales Orders
  await pool.query(`
    CREATE TABLE IF NOT EXISTS sales (
      id SERIAL PRIMARY KEY,
      bill_number TEXT UNIQUE NOT NULL,
      sale_time TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
      subtotal DOUBLE PRECISION NOT NULL,
      discount DOUBLE PRECISION DEFAULT 0,
      total_amount DOUBLE PRECISION NOT NULL,
      payment_mode TEXT NOT NULL,
      cash_paid DOUBLE PRECISION DEFAULT 0,
      upi_paid DOUBLE PRECISION DEFAULT 0,
      customer_phone TEXT,
      customer_name TEXT,
      customer_id INTEGER,
      credit_amount DOUBLE PRECISION DEFAULT 0,
      created_by TEXT
    );
  `);

  // 5. Sale Items
  await pool.query(`
    CREATE TABLE IF NOT EXISTS sale_items (
      id SERIAL PRIMARY KEY,
      sale_id INTEGER NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
      item_type TEXT NOT NULL,
      reference_id INTEGER,
      name TEXT NOT NULL,
      quantity DOUBLE PRECISION NOT NULL,
      rate DOUBLE PRECISION NOT NULL,
      total DOUBLE PRECISION NOT NULL
    );
  `);

  // 6. Oil Extraction Batches
  await pool.query(`
    CREATE TABLE IF NOT EXISTS oil_batches (
      id SERIAL PRIMARY KEY,
      batch_date DATE DEFAULT CURRENT_DATE,
      seed_name TEXT NOT NULL,
      seed_input_kg DOUBLE PRECISION NOT NULL,
      seed_cost_per_kg DOUBLE PRECISION NOT NULL,
      oil_output_litres DOUBLE PRECISION NOT NULL,
      oil_output_kg DOUBLE PRECISION,
      cake_output_kg DOUBLE PRECISION NOT NULL,
      wastage_kg DOUBLE PRECISION DEFAULT 0,
      extraction_percentage DOUBLE PRECISION,
      processing_cost DOUBLE PRECISION DEFAULT 0,
      notes TEXT,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
      status TEXT DEFAULT 'IN_TIN',
      tin_label TEXT,
      settled_oil_litres_remaining DOUBLE PRECISION,
      bottled_at TIMESTAMP WITH TIME ZONE,
      start_time TEXT,
      end_time TEXT,
      duration_minutes INTEGER,
      transport_cost DOUBLE PRECISION DEFAULT 0
    );
  `);

  // 7. Bottling Logs
  await pool.query(`
    CREATE TABLE IF NOT EXISTS bottling_logs (
      id SERIAL PRIMARY KEY,
      log_date DATE DEFAULT CURRENT_DATE,
      item_id INTEGER NOT NULL REFERENCES items(id),
      bottles_packed INTEGER NOT NULL,
      bulk_oil_litres_used DOUBLE PRECISION NOT NULL,
      bottle_cost_per_unit DOUBLE PRECISION DEFAULT 0,
      label_cost_per_unit DOUBLE PRECISION DEFAULT 0,
      batch_id INTEGER
    );
  `);

  // 8. Day-End Cash Tallies
  await pool.query(`
    CREATE TABLE IF NOT EXISTS day_end_tallies (
      id SERIAL PRIMARY KEY,
      tally_date DATE UNIQUE NOT NULL,
      system_cash_sales DOUBLE PRECISION NOT NULL,
      system_upi_sales DOUBLE PRECISION NOT NULL,
      system_total_sales DOUBLE PRECISION NOT NULL,
      actual_cash_counted DOUBLE PRECISION NOT NULL,
      cash_difference DOUBLE PRECISION NOT NULL,
      notes TEXT,
      verified_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );
  `);

  // 9. Expenses
  await pool.query(`
    CREATE TABLE IF NOT EXISTS expenses (
      id SERIAL PRIMARY KEY,
      expense_date DATE DEFAULT CURRENT_DATE,
      category TEXT NOT NULL,
      amount DOUBLE PRECISION NOT NULL,
      notes TEXT,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );
  `);

  // 10. Customers
  await pool.query(`
    CREATE TABLE IF NOT EXISTS customers (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      name_te TEXT,
      phone TEXT UNIQUE,
      address TEXT,
      total_credit_due DOUBLE PRECISION DEFAULT 0,
      credit_limit DOUBLE PRECISION DEFAULT 5000,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );
  `);

  // 11. Customer Khata Ledger Transactions
  await pool.query(`
    CREATE TABLE IF NOT EXISTS customer_khata_transactions (
      id SERIAL PRIMARY KEY,
      customer_id INTEGER NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
      sale_id INTEGER REFERENCES sales(id) ON DELETE SET NULL,
      type TEXT NOT NULL,
      amount DOUBLE PRECISION NOT NULL,
      payment_mode TEXT,
      balance_after DOUBLE PRECISION NOT NULL,
      notes TEXT,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );
  `);

  // 12. Users
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      username TEXT UNIQUE NOT NULL,
      password TEXT NOT NULL,
      name TEXT NOT NULL,
      name_te TEXT,
      role TEXT NOT NULL,
      phone TEXT,
      is_active INTEGER DEFAULT 1,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );
  `);

  // 13. Online Orders
  await pool.query(`
    CREATE TABLE IF NOT EXISTS online_orders (
      id SERIAL PRIMARY KEY,
      order_number TEXT UNIQUE NOT NULL,
      customer_name TEXT NOT NULL,
      customer_phone TEXT NOT NULL,
      delivery_type TEXT NOT NULL DEFAULT 'DELIVERY',
      delivery_address TEXT,
      total_amount DOUBLE PRECISION NOT NULL,
      payment_mode TEXT NOT NULL DEFAULT 'COD',
      payment_status TEXT NOT NULL DEFAULT 'PENDING',
      order_status TEXT NOT NULL DEFAULT 'NEW',
      notes TEXT,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );
  `);

  // 14. Online Order Items
  await pool.query(`
    CREATE TABLE IF NOT EXISTS online_order_items (
      id SERIAL PRIMARY KEY,
      order_id INTEGER NOT NULL REFERENCES online_orders(id) ON DELETE CASCADE,
      item_id INTEGER,
      name TEXT NOT NULL,
      name_te TEXT,
      variant TEXT,
      unit_price DOUBLE PRECISION NOT NULL,
      quantity DOUBLE PRECISION NOT NULL,
      total_price DOUBLE PRECISION NOT NULL,
      image_url TEXT
    );
  `);

  // Initial Seeds if tables are empty
  const userCheck = await pool.query('SELECT COUNT(*) as count FROM users');
  if (parseInt(userCheck.rows[0].count, 10) === 0) {
    console.log('Seeding initial system users into PostgreSQL...');
    await pool.query(`
      INSERT INTO users (username, password, name, name_te, role, phone)
      VALUES 
        ('admin', 'admin123', 'Shop Owner / Admin', 'షాప్ యజమాని (ఓనర్)', 'ADMIN', '9848012345'),
        ('staff', 'staff123', 'Counter Staff / Cashier', 'బిల్లింగ్ స్టాఫ్', 'STAFF', '9988776655')
      ON CONFLICT DO NOTHING;
    `);
  }

  const itemsCheck = await pool.query('SELECT COUNT(*) as count FROM items');
  if (parseInt(itemsCheck.rows[0].count, 10) === 0) {
    console.log('Seeding initial catalog items into PostgreSQL...');
    const seedItems = [
      ['Groundnut Oil 1L', 'పల్లీ నూనె 1 లీటర్', 'OIL', 'bottle', 180, 140, 50, 10, '/uploads/groundnut_oil.jpg'],
      ['Groundnut Oil 500ml', 'పల్లీ నూనె 500 ml', 'OIL', 'bottle', 95, 72, 35, 10, '/uploads/groundnut_oil.jpg'],
      ['Groundnut Oil 5L', 'పల్లీ నూనె 5 లీటర్ల క్యాన్', 'OIL', 'can', 880, 690, 12, 5, '/uploads/groundnut_oil.jpg'],
      ['Sesame (Til) Oil 1L', 'నువ్వుల నూనె 1 లీటర్', 'OIL', 'bottle', 320, 250, 20, 5, '/uploads/sesame_oil.jpg'],
      ['Sesame (Til) Oil 500ml', 'నువ్వుల నూనె 500 ml', 'OIL', 'bottle', 165, 128, 25, 5, '/uploads/sesame_oil.jpg'],
      ['Pooja / Deepam Oil 1L', 'దీపం నూనె 1 లీటర్', 'OIL', 'bottle', 130, 95, 40, 10, '/uploads/deepam_oil.jpg'],
      ['Groundnut Oil Cake 1Kg', 'పల్లీ చెక్క / పిండి (కేజీ)', 'CAKE', 'kg', 35, 22, 120, 25, '/uploads/oil_cake.jpg'],
      ['Repacked Groundnuts 1Kg', 'పల్లీలు 1 కేజీ ప్యాకెట్', 'REPACK', 'packet', 130, 108, 30, 8, '/uploads/repack_peanuts.jpg'],
      ['Repacked Groundnuts 500g', 'పల్లీలు 500 గ్రాములు', 'REPACK', 'packet', 68, 55, 40, 10, '/uploads/repack_peanuts.jpg'],
      ['Repacked Toor Dal 1Kg', 'కందిపప్పు 1 కేజీ ప్యాకెట్', 'REPACK', 'packet', 165, 142, 25, 6, '/uploads/repack_peanuts.jpg'],
      ['Special Mixture 500g', 'హాట్ మిక్చర్ 500 గ్రాములు', 'SNACK', 'packet', 110, 70, 20, 5, '/uploads/snack_mixture.jpg'],
      ['Murukku / Chekkalu 500g', 'మురుకులు / చెక్కలు 500 గ్రాములు', 'SNACK', 'packet', 100, 65, 18, 5, '/uploads/snack_mixture.jpg']
    ];
    for (const item of seedItems) {
      await pool.query(
        'INSERT INTO items (name, name_te, category, unit, selling_price, cost_price, stock_qty, low_stock_threshold, image_url) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)',
        item
      );
    }
  }

  const millingCheck = await pool.query('SELECT COUNT(*) as count FROM milling_services');
  if (parseInt(millingCheck.rows[0].count, 10) === 0) {
    console.log('Seeding milling services into PostgreSQL...');
    const seedMilling = [
      ['Wheat / Rice Flour', 'గోధుమ / బియ్యం పిండి', 'FLOUR', 8, 'kg'],
      ['Ragi / Jowar Millets', 'రాగులు / జొన్నల పిండి', 'FLOUR', 10, 'kg'],
      ['Mirchi / Chilli Grinding', 'కారం కొట్టడం', 'SPICE', 25, 'kg'],
      ['Turmeric / Masala', 'పసుపు / మసాలా పిండి', 'SPICE', 30, 'kg'],
      ['Groundnut Oil Expelling', 'పల్లీ గానుగ ఆడించడం', 'OIL_CRUSH', 15, 'kg'],
      ['Sesame Oil Expelling', 'నువ్వుల గానుగ ఆడించడం', 'OIL_CRUSH', 20, 'kg']
    ];
    for (const s of seedMilling) {
      await pool.query('INSERT INTO milling_services (name, name_te, type, rate_per_kg, unit) VALUES ($1, $2, $3, $4, $5)', s);
    }
  }

  const rawCheck = await pool.query('SELECT COUNT(*) as count FROM raw_materials');
  if (parseInt(rawCheck.rows[0].count, 10) === 0) {
    console.log('Seeding raw materials into PostgreSQL...');
    const seedRaw = [
      ['Raw Groundnut Seeds', 'పల్లీ గింజలు', 'SEEDS', 'kg', 500, 85],
      ['Raw Sesame Seeds', 'నువ్వులు', 'SEEDS', 'kg', 150, 150],
      ['Empty 1L Bottles + Caps', 'ఖాళీ 1L బాటిల్స్ & మూతలు', 'PACKAGING', 'piece', 200, 9],
      ['Empty 500ml Bottles + Caps', 'ఖాళీ 500ml బాటిల్స్ & మూతలు', 'PACKAGING', 'piece', 250, 7],
      ['Empty 5L Cans', 'ఖాళీ 5L క్యాన్లు', 'PACKAGING', 'piece', 50, 35],
      ['Pouch Covers 1Kg / 500g', 'ప్యాకింగ్ కవర్లు', 'PACKAGING', 'piece', 500, 1.5],
      ['Label Stickers (Front & Back)', 'బాటిల్ లేబుల్ స్టిక్కర్లు', 'PACKAGING', 'piece', 500, 1.5]
    ];
    for (const r of seedRaw) {
      await pool.query('INSERT INTO raw_materials (name, name_te, type, unit, stock_qty, avg_cost_per_unit) VALUES ($1, $2, $3, $4, $5, $6)', r);
    }
  }

  const custCheck = await pool.query('SELECT COUNT(*) as count FROM customers');
  if (parseInt(custCheck.rows[0].count, 10) === 0) {
    console.log('Seeding Khata customers into PostgreSQL...');
    const seedCustomers = [
      ['K. Srinivasa Rao', 'కె. శ్రీనివాస రావు', '9848012345', 'Main Bazaar, Shop #4', 450, 5000],
      ['M. Venkat Reddy', 'ఎం. వెంకట్ రెడ్డి', '9988776655', 'Bazaar Street, Near Temple', 1200, 10000],
      ['Sri Balaji Tiffin Center', 'శ్రీ బాలాజీ టిఫిన్ సెంటర్', '9440112233', 'Station Road', 2800, 15000],
      ['G. Lakshmi Narayana', 'జి. లక్ష్మీ నారాయణ', '9123456789', 'Gandhi Nagar', 0, 3000]
    ];
    for (const c of seedCustomers) {
      const res = await pool.query(
        'INSERT INTO customers (name, name_te, phone, address, total_credit_due, credit_limit) VALUES ($1, $2, $3, $4, $5, $6) RETURNING id',
        c
      );
      if (c[4] > 0) {
        await pool.query(
          "INSERT INTO customer_khata_transactions (customer_id, type, amount, balance_after, notes) VALUES ($1, 'CREDIT_PURCHASE', $2, $3, 'Opening credit balance (పాత బాకీ)')",
          [res.rows[0].id, c[4], c[4]]
        );
      }
    }
  }

  console.log('PostgreSQL schema initialization completed successfully.');
}

function initSqliteDatabase() {
  sqliteDb.serialize(() => {
    sqliteDb.run('PRAGMA journal_mode = WAL;');
    sqliteDb.run('PRAGMA busy_timeout = 5000;');
    sqliteDb.run('PRAGMA synchronous = NORMAL;');
    sqliteDb.run('PRAGMA cache_size = -64000;');
    sqliteDb.run('PRAGMA temp_store = MEMORY;');

    // 1. Items
    sqliteDb.run(`
      CREATE TABLE IF NOT EXISTS items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        name_te TEXT,
        category TEXT NOT NULL,
        unit TEXT NOT NULL,
        selling_price REAL NOT NULL,
        cost_price REAL NOT NULL,
        stock_qty REAL DEFAULT 0,
        low_stock_threshold REAL DEFAULT 10,
        is_active INTEGER DEFAULT 1,
        image_url TEXT
      )
    `);

    sqliteDb.run("ALTER TABLE items ADD COLUMN image_url TEXT", () => {});
    sqliteDb.run("ALTER TABLE items ADD COLUMN group_name TEXT", () => {});
    sqliteDb.run("ALTER TABLE items ADD COLUMN group_name_te TEXT", () => {});
    sqliteDb.run("ALTER TABLE items ADD COLUMN variant_name TEXT", () => {});
    sqliteDb.run("ALTER TABLE items ADD COLUMN variant_name_te TEXT", () => {});

    // 2. Milling Services
    sqliteDb.run(`
      CREATE TABLE IF NOT EXISTS milling_services (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        name_te TEXT,
        type TEXT NOT NULL,
        rate_per_kg REAL NOT NULL,
        unit TEXT DEFAULT 'kg'
      )
    `);

    // 3. Raw Materials
    sqliteDb.run(`
      CREATE TABLE IF NOT EXISTS raw_materials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        name_te TEXT,
        type TEXT NOT NULL,
        unit TEXT NOT NULL,
        stock_qty REAL DEFAULT 0,
        avg_cost_per_unit REAL DEFAULT 0
      )
    `);

    // 4. Sales Orders
    sqliteDb.run(`
      CREATE TABLE IF NOT EXISTS sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bill_number TEXT UNIQUE NOT NULL,
        sale_time DATETIME DEFAULT CURRENT_TIMESTAMP,
        subtotal REAL NOT NULL,
        discount REAL DEFAULT 0,
        total_amount REAL NOT NULL,
        payment_mode TEXT NOT NULL,
        cash_paid REAL DEFAULT 0,
        upi_paid REAL DEFAULT 0,
        customer_phone TEXT
      )
    `);

    sqliteDb.run("ALTER TABLE sales ADD COLUMN customer_name TEXT", () => {});
    sqliteDb.run("ALTER TABLE sales ADD COLUMN customer_id INTEGER", () => {});
    sqliteDb.run("ALTER TABLE sales ADD COLUMN credit_amount REAL DEFAULT 0", () => {});
    sqliteDb.run("ALTER TABLE sales ADD COLUMN created_by TEXT", () => {});

    // 5. Sale Items
    sqliteDb.run(`
      CREATE TABLE IF NOT EXISTS sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        item_type TEXT NOT NULL,
        reference_id INTEGER,
        name TEXT NOT NULL,
        quantity REAL NOT NULL,
        rate REAL NOT NULL,
        total REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
      )
    `);

    // 6. Oil Extraction Batches
    sqliteDb.run(`
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
        processing_cost REAL DEFAULT 0,
        notes TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);

    sqliteDb.run("ALTER TABLE oil_batches ADD COLUMN oil_output_kg REAL", () => {});
    sqliteDb.run("ALTER TABLE oil_batches ADD COLUMN status TEXT DEFAULT 'IN_TIN'", () => {});
    sqliteDb.run("ALTER TABLE oil_batches ADD COLUMN tin_label TEXT", () => {});
    sqliteDb.run("ALTER TABLE oil_batches ADD COLUMN settled_oil_litres_remaining REAL", () => {});
    sqliteDb.run("ALTER TABLE oil_batches ADD COLUMN bottled_at DATETIME", () => {});
    sqliteDb.run("ALTER TABLE oil_batches ADD COLUMN start_time TEXT", () => {});
    sqliteDb.run("ALTER TABLE oil_batches ADD COLUMN end_time TEXT", () => {});
    sqliteDb.run("ALTER TABLE oil_batches ADD COLUMN duration_minutes INTEGER", () => {});
    sqliteDb.run("ALTER TABLE oil_batches ADD COLUMN transport_cost REAL DEFAULT 0", () => {});
    sqliteDb.run("ALTER TABLE users ADD COLUMN address TEXT", () => {});

    // 7. Bottling Logs
    sqliteDb.run(`
      CREATE TABLE IF NOT EXISTS bottling_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        log_date DATE DEFAULT (DATE('now')),
        item_id INTEGER NOT NULL,
        bottles_packed INTEGER NOT NULL,
        bulk_oil_litres_used REAL NOT NULL,
        bottle_cost_per_unit REAL DEFAULT 0,
        label_cost_per_unit REAL DEFAULT 0,
        batch_id INTEGER,
        FOREIGN KEY (item_id) REFERENCES items (id)
      )
    `);
    sqliteDb.run("ALTER TABLE bottling_logs ADD COLUMN batch_id INTEGER", () => {});

    // 8. Day-End Cash Tallies
    sqliteDb.run(`
      CREATE TABLE IF NOT EXISTS day_end_tallies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tally_date DATE UNIQUE NOT NULL,
        system_cash_sales REAL NOT NULL,
        system_upi_sales REAL NOT NULL,
        system_total_sales REAL NOT NULL,
        actual_cash_counted REAL NOT NULL,
        cash_difference REAL NOT NULL,
        notes TEXT,
        verified_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // 9. Expenses
    sqliteDb.run(`
      CREATE TABLE IF NOT EXISTS expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        expense_date DATE DEFAULT (DATE('now')),
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        notes TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // 10. Customers
    sqliteDb.run(`
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
    sqliteDb.run(`
      CREATE TABLE IF NOT EXISTS customer_khata_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        sale_id INTEGER,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        payment_mode TEXT,
        balance_after REAL NOT NULL,
        notes TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE SET NULL
      )
    `);

    // 12. Users
    sqliteDb.run(`
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        name TEXT NOT NULL,
        name_te TEXT,
        role TEXT NOT NULL,
        phone TEXT,
        is_active INTEGER DEFAULT 1,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // 13. Online Orders
    sqliteDb.run(`
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

    // 14. Online Order Items
    sqliteDb.run(`
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

    // Seed Khata Customers if empty
    sqliteDb.get('SELECT COUNT(*) as count FROM customers', (err, row) => {
      if (err || !row) return;
      if (row.count === 0) {
        console.log('Seeding initial Khata credit customers...');
        const stmt = sqliteDb.prepare(`
          INSERT INTO customers (name, name_te, phone, address, total_credit_due, credit_limit)
          VALUES (?, ?, ?, ?, ?, ?)
        `);
        const seedCustomers = [
          ['K. Srinivasa Rao', 'కె. శ్రీనివాస రావు', '9848012345', 'Main Bazaar, Shop #4', 450, 5000],
          ['M. Venkat Reddy', 'ఎం. వెంకట్ రెడ్డి', '9988776655', 'Bazaar Street, Near Temple', 1200, 10000],
          ['Sri Balaji Tiffin Center', 'శ్రీ బాలాజీ టిఫిన్ సెంటర్', '9440112233', 'Station Road', 2800, 15000],
          ['G. Lakshmi Narayana', 'జి. లక్ష్మీ నారాయణ', '9123456789', 'Gandhi Nagar', 0, 3000]
        ];
        seedCustomers.forEach((c) => stmt.run(c));
        stmt.finalize();

        sqliteDb.all('SELECT id, total_credit_due FROM customers WHERE total_credit_due > 0', (err, custs) => {
          if (!err && custs) {
            custs.forEach((c) => {
              sqliteDb.run(
                `INSERT INTO customer_khata_transactions (customer_id, type, amount, balance_after, notes) VALUES (?, 'CREDIT_PURCHASE', ?, ?, 'Opening credit balance (పాత బాకీ)')`,
                [c.id, c.total_credit_due, c.total_credit_due]
              );
            });
          }
        });
      }
    });

    // Seed Items if empty
    sqliteDb.get('SELECT COUNT(*) as count FROM items', (err, row) => {
      if (err || !row) return;
      if (row.count === 0) {
        console.log('Seeding initial shop items...');
        const stmt = sqliteDb.prepare(`
          INSERT INTO items (name, name_te, category, unit, selling_price, cost_price, stock_qty, low_stock_threshold, image_url)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        `);
        const seedItems = [
          ['Groundnut Oil 1L', 'పల్లీ నూనె 1 లీటర్', 'OIL', 'bottle', 180, 140, 50, 10, '/uploads/groundnut_oil.jpg'],
          ['Groundnut Oil 500ml', 'పల్లీ నూనె 500 ml', 'OIL', 'bottle', 95, 72, 35, 10, '/uploads/groundnut_oil.jpg'],
          ['Groundnut Oil 5L', 'పల్లీ నూనె 5 లీటర్ల క్యాన్', 'OIL', 'can', 880, 690, 12, 5, '/uploads/groundnut_oil.jpg'],
          ['Sesame (Til) Oil 1L', 'నువ్వుల నూనె 1 లీటర్', 'OIL', 'bottle', 320, 250, 20, 5, '/uploads/sesame_oil.jpg'],
          ['Sesame (Til) Oil 500ml', 'నువ్వుల నూనె 500 ml', 'OIL', 'bottle', 165, 128, 25, 5, '/uploads/sesame_oil.jpg'],
          ['Pooja / Deepam Oil 1L', 'దీపం నూనె 1 లీటర్', 'OIL', 'bottle', 130, 95, 40, 10, '/uploads/deepam_oil.jpg'],
          ['Groundnut Oil Cake 1Kg', 'పల్లీ చెక్క / పిండి (కేజీ)', 'CAKE', 'kg', 35, 22, 120, 25, '/uploads/oil_cake.jpg'],
          ['Repacked Groundnuts 1Kg', 'పల్లీలు 1 కేజీ ప్యాకెట్', 'REPACK', 'packet', 130, 108, 30, 8, '/uploads/repack_peanuts.jpg'],
          ['Repacked Groundnuts 500g', 'పల్లీలు 500 గ్రాములు', 'REPACK', 'packet', 68, 55, 40, 10, '/uploads/repack_peanuts.jpg'],
          ['Repacked Toor Dal 1Kg', 'కందిపప్పు 1 కేజీ ప్యాకెట్', 'REPACK', 'packet', 165, 142, 25, 6, '/uploads/repack_peanuts.jpg'],
          ['Special Mixture 500g', 'హాట్ మిక్చర్ 500 గ్రాములు', 'SNACK', 'packet', 110, 70, 20, 5, '/uploads/snack_mixture.jpg'],
          ['Murukku / Chekkalu 500g', 'మురుకులు / చెక్కలు 500 గ్రాములు', 'SNACK', 'packet', 100, 65, 18, 5, '/uploads/snack_mixture.jpg']
        ];
        seedItems.forEach((item) => stmt.run(item));
        stmt.finalize();
      }
    });

    // Seed Milling Services if empty
    sqliteDb.get('SELECT COUNT(*) as count FROM milling_services', (err, row) => {
      if (err || !row) return;
      if (row.count === 0) {
        console.log('Seeding milling services rates...');
        const stmt = sqliteDb.prepare(`
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
        seedMilling.forEach((s) => stmt.run(s));
        stmt.finalize();
      }
    });

    // Seed Raw Materials if empty
    sqliteDb.get('SELECT COUNT(*) as count FROM raw_materials', (err, row) => {
      if (err || !row) return;
      if (row.count === 0) {
        console.log('Seeding raw materials...');
        const stmt = sqliteDb.prepare(`
          INSERT INTO raw_materials (name, name_te, type, unit, stock_qty, avg_cost_per_unit)
          VALUES (?, ?, ?, ?, ?, ?)
        `);
        const seedRaw = [
          ['Raw Groundnut Seeds', 'పల్లీ గింజలు', 'SEEDS', 'kg', 500, 85],
          ['Raw Sesame Seeds', 'నువ్వులు', 'SEEDS', 'kg', 150, 150],
          ['Empty 1L Bottles + Caps', 'ఖాళీ 1L బాటిల్స్ & మూతలు', 'PACKAGING', 'piece', 200, 9],
          ['Empty 500ml Bottles + Caps', 'ఖాళీ 500ml బాటిల్స్ & మూతలు', 'PACKAGING', 'piece', 250, 7],
          ['Empty 5L Cans', 'ఖాళీ 5L క్యాన్లు', 'PACKAGING', 'piece', 50, 35],
          ['Pouch Covers 1Kg / 500g', 'ప్యాకింగ్ కవర్లు', 'PACKAGING', 'piece', 500, 1.5],
          ['Label Stickers (Front & Back)', 'బాటిల్ లేబుల్ స్టిక్కర్లు', 'PACKAGING', 'piece', 500, 1.5]
        ];
        seedRaw.forEach((r) => stmt.run(r));
        stmt.finalize();
      }
    });

    // Seed Users if empty
    sqliteDb.get('SELECT COUNT(*) as count FROM users', (err, row) => {
      if (err || !row) return;
      if (row.count === 0) {
        console.log('Seeding initial system users (Admin & Staff)...');
        const stmt = sqliteDb.prepare(`
          INSERT INTO users (username, password, name, name_te, role, phone)
          VALUES (?, ?, ?, ?, ?, ?)
        `);
        stmt.run(['admin', 'admin123', 'Shop Owner / Admin', 'షాప్ యజమాని (ఓనర్)', 'ADMIN', '9848012345']);
        stmt.run(['staff', 'staff123', 'Counter Staff / Cashier', 'బిల్లింగ్ స్టాఫ్', 'STAFF', '9988776655']);
        stmt.finalize();
      }
    });
  });
}

// Automatically initialize schema when module is loaded
initDatabase().catch((err) => {
  console.error('Failed to initialize database schema:', err);
});

module.exports = {
  dbAll,
  dbGet,
  dbRun,
  initDatabase,
  isPostgres,
  pool,
  sqliteDb
};
