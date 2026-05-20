import { Stack, useLocalSearchParams } from "expo-router";
import { useRouter } from "expo-router";
import { Text } from "react-native";

import { MemoForm } from "@/components/MemoForm";
import { MemoEditorShell } from "@/components/MemoEditorShell";
import { MemoDraft, useMemos } from "@/context/MemoContext";

export default function EditMemoScreen() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { deleteMemo, getMemoById, saveMemo } = useMemos();
  const memo = getMemoById(id);

  const handleSubmit = async (draft: MemoDraft) => {
    await saveMemo(draft);
    router.replace("/");
  };

  const handleDelete = async () => {
    if (!id) {
      return;
    }

    await deleteMemo(id);
    router.replace("/");
  };

  return (
    <MemoEditorShell title="编辑备忘录" subtitle="修改后记得保存到小本本">
      <Stack.Screen options={{ headerShown: false }} />
      {memo ? (
        <MemoForm
          memo={memo}
          submitLabel="保存修改"
          onSubmit={handleSubmit}
          onDelete={handleDelete}
        />
      ) : (
        <Text>没有找到这张便签，可能已经被删除了。</Text>
      )}
    </MemoEditorShell>
  );
}
