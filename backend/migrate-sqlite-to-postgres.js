const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
require('dotenv').config({ path: path.resolve(__dirname, '.env') });
const sqlite3 = require('sqlite3').verbose();
const { Pool, types } = require('pg');

// Parse numbers correctly
types.setTypeParser(1700, (val) => (val === null ? null : parseFloat(val)));
types.setTypeParser(20, (val) => (val === null ? null : parseInt(val, 10)));
types.setTypeParser(1082, (val) => val);

const sqlitePath = process.env.SQLITE_DB_PATH || path.resolve(__dirname, 'shop.db');

const pgConfig = process.env.DATABASE_URL
  ? { connectionString: process.env.DATABASE_URL }
  : {
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432', 10),
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD || 'postgres',
      database: process.env.DB_NAME || 'shop_db',
      ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false
    };

const sqliteDb = new sqlite3.Database(sqlitePath, sqlite3.OPEN_READONLY, (err) => {
  if (err) {
    console.error('❌ Could not open SQLite database at', sqlitePath, ':', err.message);
    process.exit(1);
  }
});

const pool = new Pool(pgConfig);

function sqliteQuery(sql, params = []) {
  return new Promise((resolve, reject) => {
    sqliteDb.all(sql, params, (err, rows) => {
      if (err) reject(err);
      else resolve(rows || []);
    });
  });
}

const TABLES = [
  'users',
  'items',
  'milling_services',
  'raw_materials',
  'customers',
  'customer_khata_transactions',
  'sales',
  'sale_items',
  'oil_batches',
  'bottling_logs',
  'day_end_tallies',
  'expenses',
  'online_orders',
  'online_order_items'
];

async function migrate() {
  console.log('====================================================');
  console.log('🔄 STARTING SQLITE TO POSTGRESQL DATA MIGRATION');
  console.log(`📂 Source SQLite DB: ${sqlitePath}`);
  console.log(`🐘 Target PostgreSQL DB: ${pgConfig.host || 'DATABASE_URL'}/${pgConfig.database || ''}`);
  console.log('====================================================\n');

  try {
    // Test PostgreSQL connection
    const client = await pool.connect();
    console.log('✅ Connected to PostgreSQL successfully.\n');
    client.release();

    // Ensure Postgres schema is initialized first
    const { initDatabase } = require('./database');
    await initDatabase();

    for (const table of TABLES) {
      process.stdout.write(`Migrating table '${table}'... `);
      let rows = [];
      try {
        rows = await sqliteQuery(`SELECT * FROM ${table} ORDER BY id ASC`);
      } catch (err) {
        console.log(`⚠️ Skipped (table does not exist in SQLite or error: ${err.message})`);
        continue;
      }

      if (rows.length === 0) {
        console.log('0 records found in SQLite.');
        continue;
      }

      const columns = Object.keys(rows[0]);
      const colList = columns.join(', ');
      const placeholders = columns.map((_, i) => `$${i + 1}`).join(', ');

      const insertSql = `
        INSERT INTO ${table} (${colList})
        VALUES (${placeholders})
        ON CONFLICT (id) DO UPDATE SET
          ${columns.filter(c => c !== 'id').map(c => `${c} = EXCLUDED.${c}`).join(', ')}
      `;

      let insertedCount = 0;
      for (const row of rows) {
        const values = columns.map(col => row[col]);
        await pool.query(insertSql, values);
        insertedCount++;
      }

      // Reset PostgreSQL SERIAL sequence to MAX(id)
      try {
        await pool.query(`
          SELECT setval(
            pg_get_serial_sequence('${table}', 'id'),
            COALESCE((SELECT MAX(id) FROM ${table}), 1),
            (SELECT MAX(id) FROM ${table}) IS NOT NULL
          );
        `);
      } catch (_) {
        // If table doesn't use a serial sequence, ignore
      }

      console.log(`✅ Migrated ${insertedCount} records.`);
    }

    console.log('\n====================================================');
    console.log('🎉 ALL DATA MIGRATED SUCCESSFULLY TO POSTGRESQL!');
    console.log('====================================================');
  } catch (err) {
    console.error('\n❌ Migration failed with error:', err);
    process.exit(1);
  } finally {
    sqliteDb.close();
    await pool.end();
  }
}

migrate();
