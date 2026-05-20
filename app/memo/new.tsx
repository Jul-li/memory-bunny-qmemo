import { Stack, useLocalSearchParams, useRouter } from "expo-router";

import { MemoForm } from "@/components/MemoForm";
import { MemoEditorShell } from "@/components/MemoEditorShell";
import { MemoDraft, useMemos } from "@/context/MemoContext";
import { categories } from "@/data/mockMemos";
import { MemoCategoryId } from "@/types/memo";

export default function NewMemoScreen() {
  const router = useRouter();
  const { categoryId } = useLocalSearchParams<{ categoryId?: string }>();
  const { saveMemo } = useMemos();
  const initialCategoryId = categories.some((category) => category.id === categoryId)
    ? categoryId as MemoCategoryId
    : undefined;

  const handleSubmit = async (draft: MemoDraft) => {
    await saveMemo(draft);
    router.replace("/");
  };

  return (
    <MemoEditorShell title="新建备忘录" subtitle="把刚冒出来的小想法贴在这里">
      <Stack.Screen options={{ headerShown: false }} />
      <MemoForm
        initialCategoryId={initialCategoryId}
        submitLabel="保存便签"
        onSubmit={handleSubmit}
      />
    </MemoEditorShell>
  );
}
