import { Ionicons } from "@expo/vector-icons";
import {
  Image,
  ImageSourcePropType,
  Pressable,
  StyleSheet,
  Text,
  View
} from "react-native";

import { categories, memoColors } from "@/data/mockMemos";
import { theme } from "@/constants/theme";
import { Memo, MemoCategoryId } from "@/types/memo";

const sharedLifeDiaryStickerSources = [
  require("../../assets/memo-icons/flower-basket.png"),
  require("../../assets/memo-icons/camera-photo.png")
] as const;

const fixedStickerSources: Record<Exclude<MemoCategoryId, "life" | "diary">, ImageSourcePropType> = {
  todo: require("../../assets/memo-icons/checklist.png"),
  study: require("../../assets/memo-icons/reading.png"),
  idea: require("../../assets/memo-icons/idea.png")
};

const categoryIconSources: Partial<Record<MemoCategoryId, ImageSourcePropType>> = {
  life: require("../../assets/category-icons/life.png"),
  todo: require("../../assets/category-icons/todo.png"),
  study: require("../../assets/category-icons/study.png"),
  idea: require("../../assets/category-icons/idea.png")
};

function getStableStickerIndex(seed: string) {
  return Array.from(seed).reduce((total, char) => total + char.charCodeAt(0), 0) % sharedLifeDiaryStickerSources.length;
}

function getStickerSource(memo: Memo) {
  if (memo.categoryId === "life" || memo.categoryId === "diary") {
    return sharedLifeDiaryStickerSources[getStableStickerIndex(memo.id)];
  }

  return fixedStickerSources[memo.categoryId];
}

type MemoCardProps = {
  memo: Memo;
  onPress?: () => void;
};

export function MemoCard({ memo, onPress }: MemoCardProps) {
  const category = categories.find((item) => item.id === memo.categoryId);
  const color = memoColors.find((item) => item.id === memo.colorId)?.value ?? theme.colors.cream;
  const stickerSource = getStickerSource(memo);
  const categoryIconSource = categoryIconSources[memo.categoryId];

  return (
    <Pressable onPress={onPress} style={({ pressed }) => [styles.card, { backgroundColor: color }, pressed && styles.pressed]}>
      <View style={styles.header}>
        <View style={styles.categoryBadge}>
          {categoryIconSource ? (
            <Image resizeMode="contain" source={categoryIconSource} style={styles.categoryIconImage} />
          ) : (
            <Ionicons color={theme.colors.text} name={(category?.icon ?? "bookmark") as keyof typeof Ionicons.glyphMap} size={15} />
          )}
          <Text style={styles.categoryText}>{category?.name}</Text>
        </View>
        <Pressable accessibilityLabel="更多功能" style={styles.moreButton}>
          <Ionicons color={theme.colors.muted} name="ellipsis-horizontal" size={18} />
        </Pressable>
      </View>

      <Text numberOfLines={1} style={styles.title}>
        {memo.title}
      </Text>
      <Text numberOfLines={3} style={styles.content}>
        {memo.content}
      </Text>
      <Image
        resizeMode="contain"
        source={stickerSource}
        style={styles.sticker}
      />

      <View style={styles.footer}>
        <Text style={styles.updatedAt}>{memo.updatedAt}</Text>
        <Ionicons color={theme.colors.muted} name="chevron-forward" size={17} />
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: {
    minHeight: 164,
    borderRadius: theme.radius.xl,
    padding: 18,
    marginBottom: 14,
    shadowColor: theme.colors.shadow,
    shadowOpacity: 0.18,
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 8 },
    elevation: 4,
    borderWidth: 2,
    borderColor: "rgba(255,255,255,0.74)"
  },
  header: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    marginBottom: 14
  },
  categoryBadge: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    paddingHorizontal: 10,
    paddingVertical: 7,
    borderRadius: 999,
    backgroundColor: "rgba(255,255,255,0.56)"
  },
  categoryText: {
    color: theme.colors.text,
    fontSize: 12,
    fontWeight: "800"
  },
  categoryIconImage: {
    width: 20,
    height: 20
  },
  moreButton: {
    width: 30,
    height: 30,
    alignItems: "center",
    justifyContent: "center"
  },
  title: {
    color: theme.colors.text,
    fontSize: 20,
    fontWeight: "900",
    paddingRight: 82,
    marginBottom: 8
  },
  content: {
    color: "#6D594C",
    fontSize: 15,
    lineHeight: 22,
    fontWeight: "600",
    paddingRight: 86
  },
  sticker: {
    position: "absolute",
    right: 18,
    top: 52,
    width: 72,
    height: 72
  },
  footer: {
    marginTop: "auto",
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between"
  },
  updatedAt: {
    color: theme.colors.muted,
    fontSize: 12,
    fontWeight: "700"
  },
  pressed: {
    transform: [{ scale: 0.985 }]
  }
});
