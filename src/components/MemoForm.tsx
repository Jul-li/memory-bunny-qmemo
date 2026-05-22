import { Ionicons } from "@expo/vector-icons";
import { useState } from "react";
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View
} from "react-native";

import { IOS26Switch } from "@/components/IOS26Switch";
import { theme } from "@/constants/theme";
import { memoColors } from "@/data/mockMemos";
import { MemoDraft } from "@/context/MemoContext";
import { Memo, MemoCategoryId, MemoColorId } from "@/types/memo";

type MemoFormProps = {
  initialCategoryId?: MemoCategoryId;
  memo?: Memo;
  submitLabel: string;
  onSubmit: (draft: MemoDraft) => Promise<void>;
  onDelete?: () => Promise<void>;
};

export function MemoForm({ initialCategoryId, memo, submitLabel, onSubmit, onDelete }: MemoFormProps) {
  const [title, setTitle] = useState(memo?.title ?? "");
  const [content, setContent] = useState(memo?.content ?? "");
  const categoryId = memo?.categoryId ?? initialCategoryId ?? "life";
  const [colorId, setColorId] = useState<MemoColorId>(memo?.colorId ?? "cream");
  const [isPinned, setIsPinned] = useState(memo?.isPinned ?? false);
  const [isSaving, setIsSaving] = useState(false);

  const handleSubmit = async () => {
    if (isSaving) {
      return;
    }

    setIsSaving(true);
    try {
      await onSubmit({
        id: memo?.id,
        title,
        content,
        categoryId,
        colorId,
        isPinned
      });
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={styles.content}>
      <View style={styles.editorInput}>
        <TextInput
          value={title}
          onChangeText={setTitle}
          placeholder="给这张便签起个名字"
          placeholderTextColor={theme.colors.muted}
          style={styles.titleInput}
        />
        <View style={styles.editorDivider} />
        <TextInput
          multiline
          textAlignVertical="top"
          value={content}
          onChangeText={setContent}
          placeholder="写下灵感、待办、学习笔记或今天的小心情"
          placeholderTextColor={theme.colors.muted}
          style={styles.contentInput}
        />
      </View>

      <Text style={styles.label}>卡片颜色</Text>
      <View style={styles.colorRow}>
        {memoColors.map((color) => {
          const isActive = color.id === colorId;

          return (
            <Pressable
              accessibilityLabel={color.name}
              key={color.id}
              onPress={() => setColorId(color.id)}
              style={({ pressed }) => [
                styles.colorSwatch,
                { backgroundColor: color.value },
                isActive && styles.activeColorSwatch,
                pressed && styles.pressed
              ]}
            >
              {isActive ? <Ionicons color={theme.colors.accentStrong} name="checkmark" size={20} /> : null}
            </Pressable>
          );
        })}
      </View>

      <View style={styles.pinRow}>
        <View style={styles.pinTextWrap}>
          <Text style={styles.pinTitle}>置顶这张便签</Text>
          <Text style={styles.pinDescription}>重要的小纸条会排在最前面</Text>
        </View>
        <IOS26Switch
          accessibilityLabel="置顶这张便签"
          value={isPinned}
          onValueChange={setIsPinned}
        />
      </View>

      <Pressable
        onPress={handleSubmit}
        style={({ pressed }) => [styles.saveButton, pressed && styles.pressed]}
      >
        <Ionicons color="#FFFFFF" name="checkmark-circle" size={21} />
        <Text style={styles.saveText}>{isSaving ? "保存中..." : submitLabel}</Text>
      </Pressable>

      {onDelete ? (
        <Pressable
          onPress={onDelete}
          style={({ pressed }) => [styles.deleteButton, pressed && styles.pressed]}
        >
          <Ionicons color={theme.colors.accentStrong} name="trash" size={20} />
          <Text style={styles.deleteText}>删除这张便签</Text>
        </Pressable>
      ) : null}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  content: {
    paddingBottom: 36
  },
  label: {
    color: theme.colors.text,
    fontSize: 15,
    fontWeight: "900",
    marginBottom: 9
  },
  editorInput: {
    minHeight: 224,
    borderRadius: theme.radius.lg,
    backgroundColor: theme.colors.surfaceStrong,
    borderWidth: 1,
    borderColor: theme.colors.line,
    marginBottom: 18,
    overflow: "hidden"
  },
  titleInput: {
    minHeight: 54,
    paddingHorizontal: 16,
    borderWidth: 0,
    color: theme.colors.text,
    fontSize: 16,
    fontWeight: "800",
    outlineColor: "transparent",
    outlineWidth: 0
  },
  editorDivider: {
    height: 1,
    marginHorizontal: 16,
    backgroundColor: theme.colors.line
  },
  contentInput: {
    minHeight: 154,
    paddingHorizontal: 16,
    paddingTop: 15,
    borderWidth: 0,
    color: theme.colors.text,
    fontSize: 15,
    fontWeight: "700",
    lineHeight: 22,
    outlineColor: "transparent",
    outlineWidth: 0
  },
  colorRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 10,
    marginBottom: 18
  },
  colorSwatch: {
    width: 42,
    height: 42,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 21,
    borderWidth: 3,
    borderColor: "#FFFFFF"
  },
  activeColorSwatch: {
    borderColor: theme.colors.accent
  },
  pinRow: {
    minHeight: 66,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: 16,
    borderRadius: theme.radius.lg,
    backgroundColor: "#FFF9E8",
    borderWidth: 1,
    borderColor: theme.colors.line,
    marginBottom: 18
  },
  pinTextWrap: {
    flex: 1,
    paddingRight: 12
  },
  pinTitle: {
    color: theme.colors.text,
    fontSize: 15,
    fontWeight: "900",
    marginBottom: 4
  },
  pinDescription: {
    color: theme.colors.muted,
    fontSize: 12,
    fontWeight: "700"
  },
  saveButton: {
    minHeight: 54,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    borderRadius: 999,
    backgroundColor: theme.colors.accent,
    shadowColor: theme.colors.accentStrong,
    shadowOpacity: 0.22,
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 7 },
    elevation: 4
  },
  saveText: {
    color: "#FFFFFF",
    fontSize: 16,
    fontWeight: "900"
  },
  deleteButton: {
    minHeight: 50,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    borderRadius: 999,
    backgroundColor: "#FFF2F5",
    borderWidth: 1,
    borderColor: "#F5B8C6",
    marginTop: 12
  },
  deleteText: {
    color: theme.colors.accentStrong,
    fontSize: 15,
    fontWeight: "900"
  },
  pressed: {
    transform: [{ scale: 0.98 }]
  }
});
