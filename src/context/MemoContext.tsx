import { Storage } from "expo-sqlite/kv-store";
import {
  createContext,
  PropsWithChildren,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState
} from "react";
import { Platform } from "react-native";

import { mockMemos } from "@/data/mockMemos";
import { Memo, MemoCategoryId, MemoColorId } from "@/types/memo";

const storageKey = "qmemo-cute:memos:v1";

export type MemoDraft = {
  id?: string;
  title: string;
  content: string;
  categoryId: MemoCategoryId;
  colorId: MemoColorId;
  isPinned: boolean;
};

type MemoContextValue = {
  memos: Memo[];
  isReady: boolean;
  getMemoById: (id: string) => Memo | undefined;
  saveMemo: (draft: MemoDraft) => Promise<string>;
  deleteMemo: (id: string) => Promise<void>;
  clearMemos: () => Promise<void>;
};

const MemoContext = createContext<MemoContextValue | null>(null);

function formatUpdatedAt(date: Date) {
  const hours = `${date.getHours()}`.padStart(2, "0");
  const minutes = `${date.getMinutes()}`.padStart(2, "0");
  return `今天 ${hours}:${minutes}`;
}

function createMemoId() {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

function getWebStorage() {
  if (Platform.OS !== "web") {
    return null;
  }

  const storage = globalThis.localStorage;
  return storage ?? null;
}

async function loadStoredMemos() {
  const webStorage = getWebStorage();

  if (webStorage) {
    return webStorage.getItem(storageKey);
  }

  return Storage.getItemAsync(storageKey);
}

async function persistMemos(nextMemos: Memo[]) {
  const value = JSON.stringify(nextMemos);
  const webStorage = getWebStorage();

  if (webStorage) {
    webStorage.setItem(storageKey, value);
    return;
  }

  await Storage.setItemAsync(storageKey, value);
}

export function MemoProvider({ children }: PropsWithChildren) {
  const [memos, setMemos] = useState<Memo[]>([]);
  const [isReady, setIsReady] = useState(false);

  useEffect(() => {
    let isMounted = true;

    async function loadMemos() {
      try {
        const stored = await loadStoredMemos();
        const nextMemos = stored ? (JSON.parse(stored) as Memo[]) : mockMemos;

        if (!stored) {
          await persistMemos(nextMemos);
        }

        if (isMounted) {
          setMemos(nextMemos);
        }
      } catch (error) {
        console.warn("Failed to load memos", error);
        if (isMounted) {
          setMemos(mockMemos);
        }
      } finally {
        if (isMounted) {
          setIsReady(true);
        }
      }
    }

    loadMemos();

    return () => {
      isMounted = false;
    };
  }, []);

  const getMemoById = useCallback(
    (id: string) => memos.find((memo) => memo.id === id),
    [memos]
  );

  const saveMemo = useCallback(
    async (draft: MemoDraft) => {
      const now = new Date();
      const id = draft.id ?? createMemoId();
      const cleanedTitle = draft.title.trim() || "未命名便签";
      const cleanedContent = draft.content.trim();
      const existingMemo = draft.id ? memos.find((memo) => memo.id === draft.id) : undefined;

      const nextMemo: Memo = {
        id,
        title: cleanedTitle,
        content: cleanedContent,
        categoryId: draft.categoryId,
        colorId: draft.colorId,
        isPinned: draft.isPinned,
        updatedAt: formatUpdatedAt(now)
      };

      const nextMemos = existingMemo
        ? memos.map((memo) => (memo.id === id ? nextMemo : memo))
        : [nextMemo, ...memos];

      setMemos(nextMemos);
      await persistMemos(nextMemos);
      return id;
    },
    [memos]
  );

  const deleteMemo = useCallback(
    async (id: string) => {
      const nextMemos = memos.filter((memo) => memo.id !== id);
      setMemos(nextMemos);
      await persistMemos(nextMemos);
    },
    [memos]
  );

  const clearMemos = useCallback(async () => {
    setMemos([]);
    await persistMemos([]);
  }, []);

  const value = useMemo<MemoContextValue>(
    () => ({
      memos,
      isReady,
      getMemoById,
      saveMemo,
      deleteMemo,
      clearMemos
    }),
    [clearMemos, deleteMemo, getMemoById, isReady, memos, saveMemo]
  );

  return <MemoContext.Provider value={value}>{children}</MemoContext.Provider>;
}

export function useMemos() {
  const context = useContext(MemoContext);

  if (!context) {
    throw new Error("useMemos must be used within MemoProvider");
  }

  return context;
}
