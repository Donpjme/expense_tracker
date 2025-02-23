// filepath: /Users/mac/CodeAcademy/Expense Tracker/expense_tracker/web/sqflite_sw.js
self.importScripts('https://unpkg.com/sql.js@1.5.0/dist/sql-wasm.js');

let db;

self.onmessage = async function (e) {
  const { id, method, params } = e.data;

  try {
    if (method === 'open') {
      const SQL = await initSqlJs({ locateFile: file => `https://unpkg.com/sql.js@1.5.0/dist/${file}` });
      db = new SQL.Database();
      self.postMessage({ id, result: null });
    } else if (method === 'exec') {
      db.exec(params.sql);
      self.postMessage({ id, result: null });
    } else if (method === 'query') {
      const result = db.exec(params.sql);
      self.postMessage({ id, result });
    } else if (method === 'close') {
      db.close();
      self.postMessage({ id, result: null });
    } else {
      throw new Error(`Unknown method: ${method}`);
    }
  } catch (error) {
    self.postMessage({ id, error: error.message });
  }
};