import { Ionicons } from "@expo/vector-icons";
import {
  Image,
  ImageSourcePropType,
  Pressable,
  StyleSheet,
  Text
} from "react-native";

import { theme } from "@/constants/theme";
import { MemoCategory, MemoCategoryId } from "@/types/memo";

type CategoryPillId = MemoCategoryId | "all";

const categoryIconSources: Partial<Record<CategoryPillId, ImageSourcePropType>> = {
  all: require("../../assets/category-icons/all.png"),
  life: require("../../assets/category-icons/life.png"),
  todo: require("../../assets/category-icons/todo.png"),
  study: require("../../assets/category-icons/study.png"),
  idea: require("../../assets/category-icons/idea.png"),
  diary: require("../../assets/category-icons/diary.png")
};

type CategoryPillProps = {
  category: MemoCategory | { id: "all"; name: string; icon: keyof typeof Ionicons.glyphMap };
  isActive: boolean;
  onPress: () => void;
};

export function CategoryPill({ category, isActive, onPress }: CategoryPillProps) {
  const iconSource = categoryIconSources[category.id as CategoryPillId];

  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [
        styles.pill,
        isActive && styles.activePill,
        pressed && styles.pressed
      ]}
    >
      {iconSource ? (
        <Image resizeMode="contain" source={iconSource} style={styles.iconImage} />
      ) : (
        <Ionicons
          color={isActive ? theme.colors.text : theme.colors.muted}
          name={category.icon as keyof typeof Ionicons.glyphMap}
          size={24}
        />
      )}
      <Text style={[styles.label, isActive && styles.activeLabel]}>{category.name}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  pill: {
    height: 40,
    flexDirection: "row",
    alignItems: "center",
    gap: 7,
    paddingHorizontal: 15,
    borderRadius: 999,
    borderWidth: 2,
    borderColor: "transparent",
    backgroundColor: theme.colors.surfaceStrong,
    shadowColor: theme.colors.shadow,
    shadowOpacity: 0.13,
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 7 },
    elevation: 3
  },
  activePill: {
    backgroundColor: theme.colors.cream,
    borderColor: theme.colors.surfaceStrong
  },
  iconImage: {
    width: 24,
    height: 24
  },
  label: {
    color: theme.colors.muted,
    fontSize: 14,
    fontWeight: "700"
  },
  activeLabel: {
    color: theme.colors.text
  },
  pressed: {
    transform: [{ scale: 0.97 }]
  }
});
