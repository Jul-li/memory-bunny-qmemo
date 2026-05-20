import * as SQLite from "expo-sqlite";

const databaseName = "qmemo-cute.db";

export async function openMemoDatabase() {
  const db = await SQLite.openDatabaseAsync(databaseName);

  await db.execAsync(`
    CREATE TABLE IF NOT EXISTS memos (
      id TEXT PRIMARY KEY NOT NULL,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      category_id TEXT NOT NULL,
      color_id TEXT NOT NULL,
      is_pinned INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  `);

  return db;
}
