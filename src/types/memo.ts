export type MemoCategoryId = "life" | "todo" | "study" | "idea" | "diary";

export type MemoColorId = "cream" | "pink" | "mint" | "sky" | "lavender" | "coral";

export type Memo = {
  id: string;
  title: string;
  content: string;
  categoryId: MemoCategoryId;
  colorId: MemoColorId;
  isPinned: boolean;
  updatedAt: string;
};

export type MemoCategory = {
  id: MemoCategoryId;
  name: string;
  icon: string;
};

export type MemoCardColor = {
  id: MemoColorId;
  name: string;
  value: string;
};
