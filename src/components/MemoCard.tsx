import { Ionicons } from "@expo/vector-icons";
import { useRef } from "react";
import {
  GestureResponderEvent,
  Image,
  ImageSourcePropType,
  Pressable,
  StyleSheet,
  Text,
  View
} from "react-native";

import { categories } from "@/data/mockMemos";
import { theme } from "@/constants/theme";
import { Memo, MemoCategoryId } from "@/types/memo";

const sharedLifeDiaryStickerSources = [
  require("../../assets/memo-icons/flower-basket.png"),
  require("../../assets/memo-icons/camera-photo.png")
] as const;

const pinnedCategoryIconSource = require("../../assets/category-icons/pinned.png");

const defaultMemoCardColor = "#FFFDF5";
const gridCellWidth = 34;
const gridCellHeight = 26;
const gridVerticalLines = Array.from({ length: 14 }, (_, index) => index);
const gridHorizontalLines = Array.from({ length: 9 }, (_, index) => index);

const fixedStickerSources: Record<Exclude<MemoCategoryId, "life" | "diary">, ImageSourcePropType> = {
  todo: require("../../assets/memo-icons/checklist.png"),
  study: require("../../assets/memo-icons/reading.png"),
  idea: require("../../assets/memo-icons/idea.png")
};

const categoryIconSources: Partial<Record<MemoCategoryId, ImageSourcePropType>> = {
  life: require("../../assets/category-icons/life.png"),
  todo: require("../../assets/category-icons/todo.png"),
  study: require("../../assets/category-icons/study.png"),
  idea: require("../../assets/category-icons/idea.png"),
  diary: require("../../assets/category-icons/diary.png")
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
  onLongPress?: (memo: Memo, anchor: { x: number; y: number; source: "longPress"; cardTop: number; cardBottom: number }) => void;
  onMorePress?: (memo: Memo, anchor: { x: number; y: number; source: "more" }) => void;
};

export function MemoCard({ memo, onLongPress, onMorePress, onPress }: MemoCardProps) {
  const cardRef = useRef<View>(null);
  const moreButtonRef = useRef<View>(null);
  const category = categories.find((item) => item.id === memo.categoryId);
  const stickerSource = getStickerSource(memo);
  const categoryIconSource = categoryIconSources[memo.categoryId];
  const hasSubtitle = memo.content.trim().length > 0;

  const handleLongPress = () => {
    cardRef.current?.measureInWindow((x, y, width, height) => {
      onLongPress?.(memo, {
        x: x + width / 2,
        y: y + height + 8,
        source: "longPress",
        cardTop: y,
        cardBottom: y + height
      });
    });
  };

  const handleMorePress = (event: GestureResponderEvent) => {
    event.stopPropagation();

    moreButtonRef.current?.measureInWindow((x, y, width, height) => {
      onMorePress?.(memo, { x: x + width / 2, y: y + height + 8, source: "more" });
    });
  };

  return (
    <Pressable
      ref={cardRef}
      onLongPress={handleLongPress}
      onPress={onPress}
      style={({ pressed }) => [styles.card, { backgroundColor: defaultMemoCardColor }, pressed && styles.pressed]}
    >
      <View pointerEvents="none" style={styles.gridTexture}>
        {gridVerticalLines.map((item) => (
          <View key={`vertical-${item}`} style={[styles.gridVerticalLine, { left: item * gridCellWidth }]} />
        ))}
        {gridHorizontalLines.map((item) => (
          <View key={`horizontal-${item}`} style={[styles.gridHorizontalLine, { top: item * gridCellHeight }]} />
        ))}
      </View>

      <View style={styles.header}>
        <View style={[styles.categoryBadge, memo.isPinned && styles.pinnedCategoryBadge]}>
          {memo.isPinned ? (
            <Image resizeMode="contain" source={pinnedCategoryIconSource} style={styles.pinnedCategoryIcon} />
          ) : categoryIconSource ? (
            <Image resizeMode="contain" source={categoryIconSource} style={styles.categoryIconImage} />
          ) : (
            <Ionicons color={theme.colors.text} name={(category?.icon ?? "bookmark") as keyof typeof Ionicons.glyphMap} size={15} />
          )}
          <Text style={styles.categoryText}>{category?.name}</Text>
        </View>
        <Pressable
          ref={moreButtonRef}
          accessibilityLabel="更多功能"
          onPress={handleMorePress}
          style={styles.moreButton}
        >
          <Ionicons color={theme.colors.muted} name="ellipsis-horizontal" size={18} />
        </Pressable>
      </View>

      <View style={styles.body}>
        <View style={styles.titleRow}>
          {memo.isPinned ? (
            categoryIconSource ? (
              <Image resizeMode="contain" source={categoryIconSource} style={styles.titleCategoryIcon} />
            ) : (
              <Ionicons color={theme.colors.text} name={(category?.icon ?? "bookmark") as keyof typeof Ionicons.glyphMap} size={32} />
            )
          ) : null}
          <Text numberOfLines={1} style={styles.title}>
            {memo.title}
          </Text>
        </View>
        <Text numberOfLines={2} style={styles.content}>
          {memo.content}
        </Text>
        <Image
          resizeMode="contain"
          source={stickerSource}
          style={[styles.sticker, !hasSubtitle && styles.stickerTitleOnly]}
        />
      </View>

      <View style={styles.footer}>
        <Text style={styles.updatedAt}>{memo.updatedAt}</Text>
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
    position: "relative",
    zIndex: 1,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    marginBottom: 14
  },
  gridTexture: {
    position: "absolute",
    left: 0,
    right: 0,
    top: 0,
    bottom: 0,
    zIndex: 0,
    opacity: 0.02,
    borderRadius: theme.radius.xl,
    overflow: "hidden"
  },
  gridVerticalLine: {
    position: "absolute",
    top: 0,
    bottom: 0,
    width: StyleSheet.hairlineWidth,
    backgroundColor: "#000000"
  },
  gridHorizontalLine: {
    position: "absolute",
    left: 0,
    right: 0,
    height: StyleSheet.hairlineWidth,
    backgroundColor: "#000000"
  },
  categoryBadge: {
    position: "relative",
    height: 36,
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    paddingHorizontal: 10,
    borderRadius: 999,
    backgroundColor: "rgba(255,255,255,0.56)",
    borderWidth: 1,
    borderColor: "#FFFFFF",
    overflow: "visible"
  },
  pinnedCategoryBadge: {
    paddingLeft: 36
  },
  categoryText: {
    color: theme.colors.text,
    fontSize: 12,
    fontWeight: "800"
  },
  categoryIconImage: {
    width: 24,
    height: 24
  },
  pinnedCategoryIcon: {
    position: "absolute",
    left: 2,
    bottom: 7,
    width: 32,
    height: 32
  },
  moreButton: {
    width: 30,
    height: 30,
    alignItems: "center",
    justifyContent: "center"
  },
  body: {
    position: "relative",
    zIndex: 1
  },
  titleRow: {
    position: "relative",
    zIndex: 1,
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    paddingRight: 82,
    marginBottom: 4
  },
  titleCategoryIcon: {
    width: 32,
    height: 32
  },
  title: {
    flex: 1,
    color: theme.colors.text,
    fontSize: 20,
    fontWeight: "900"
  },
  content: {
    position: "relative",
    zIndex: 1,
    color: "#6D594C",
    fontSize: 15,
    lineHeight: 22,
    fontWeight: "400",
    paddingRight: 86
  },
  sticker: {
    position: "absolute",
    zIndex: 2,
    left: 255,
    top: -14,
    width: 86,
    height: 86
  },
  stickerTitleOnly: {
    top: -27
  },
  footer: {
    position: "relative",
    zIndex: 1,
    marginTop: 6,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "flex-start"
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
