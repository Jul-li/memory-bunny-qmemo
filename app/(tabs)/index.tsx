import { Ionicons } from "@expo/vector-icons";
import { useRouter } from "expo-router";
import { useEffect, useMemo, useRef, useState } from "react";
import {
  Animated,
  Easing,
  FlatList,
  Image,
  ImageSourcePropType,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

import { CategoryPill } from "@/components/CategoryPill";
import { MemoCard } from "@/components/MemoCard";
import { StickerEmptyState } from "@/components/StickerEmptyState";
import { theme } from "@/constants/theme";
import { useMemos } from "@/context/MemoContext";
import { categories } from "@/data/mockMemos";
import { MemoCategoryId } from "@/types/memo";

type ActiveCategory = "all" | MemoCategoryId;

const avatarSource = require("../../assets/profile-icons/avatar.png");

const categoryIconSources: Partial<Record<MemoCategoryId, ImageSourcePropType>> = {
  life: require("../../assets/category-icons/life.png"),
  todo: require("../../assets/category-icons/todo.png"),
  study: require("../../assets/category-icons/study.png"),
  idea: require("../../assets/category-icons/idea.png")
};

const createMenuDescriptions: Record<MemoCategoryId, string> = {
  life: "记录日常碎片和小灵感",
  todo: "安排任务清单不遗漏",
  study: "整理笔记和复习重点",
  idea: "收集突然冒出的点子",
  diary: "写下今天的小情绪"
};

const allCategory = {
  id: "all" as const,
  name: "全部",
  icon: "albums" as keyof typeof Ionicons.glyphMap
};

export default function HomeScreen() {
  const router = useRouter();
  const { memos, isReady } = useMemos();
  const [searchText, setSearchText] = useState("");
  const [activeCategory, setActiveCategory] = useState<ActiveCategory>("all");
  const [isCreateMenuOpen, setIsCreateMenuOpen] = useState(false);
  const [shouldRenderCreateMenu, setShouldRenderCreateMenu] = useState(false);
  const createMenuProgress = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    if (isCreateMenuOpen) {
      setShouldRenderCreateMenu(true);
    }

    Animated.timing(createMenuProgress, {
      toValue: isCreateMenuOpen ? 1 : 0,
      duration: 420,
      easing: Easing.bezier(0.22, 1, 0.36, 1),
      useNativeDriver: false
    }).start(({ finished }) => {
      if (finished && !isCreateMenuOpen) {
        setShouldRenderCreateMenu(false);
      }
    });
  }, [createMenuProgress, isCreateMenuOpen]);

  const filteredMemos = useMemo(() => {
    const keyword = searchText.trim().toLowerCase();

    return memos
      .filter((memo) => activeCategory === "all" || memo.categoryId === activeCategory)
      .filter((memo) => {
        if (!keyword) {
          return true;
        }

        return `${memo.title} ${memo.content}`.toLowerCase().includes(keyword);
      })
      .sort((a, b) => Number(b.isPinned) - Number(a.isPinned));
  }, [activeCategory, memos, searchText]);

  return (
    <SafeAreaView style={styles.safeArea}>
      <View style={styles.header}>
        <View style={styles.avatar}>
          <Image resizeMode="contain" source={avatarSource} style={styles.avatarImage} />
        </View>
        <View style={styles.headerText}>
          <Text style={styles.eyebrow}>记忆兔</Text>
          <Text style={styles.title}>今天想记点什么？</Text>
        </View>
      </View>

      <View style={styles.searchBox}>
        <Ionicons color={theme.colors.muted} name="search" size={20} />
        <TextInput
          placeholder="搜索灵感、待办或小心情"
          placeholderTextColor={theme.colors.muted}
          value={searchText}
          onChangeText={setSearchText}
          style={styles.searchInput}
        />
        {searchText ? (
          <Pressable onPress={() => setSearchText("")} style={styles.clearButton}>
            <Ionicons color={theme.colors.muted} name="close" size={16} />
          </Pressable>
        ) : null}
      </View>

      <View style={styles.categorySection}>
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          style={styles.categoryScroller}
          contentContainerStyle={styles.categoryList}
        >
          <CategoryPill
            category={allCategory}
            isActive={activeCategory === "all"}
            onPress={() => setActiveCategory("all")}
          />
          {categories.map((category) => (
            <CategoryPill
              key={category.id}
              category={category}
              isActive={activeCategory === category.id}
              onPress={() => setActiveCategory(category.id)}
            />
          ))}
        </ScrollView>
      </View>

      <FlatList
        data={filteredMemos}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => (
          <MemoCard memo={item} onPress={() => router.push(`/memo/${item.id}`)} />
        )}
        showsVerticalScrollIndicator={false}
        contentContainerStyle={styles.memoList}
        ListHeaderComponent={
          <View style={styles.listHeader}>
            <Text style={styles.sectionTitle}>我的便签</Text>
            <Text style={styles.count}>{isReady ? `${filteredMemos.length} 条` : "加载中"}</Text>
          </View>
        }
        ListEmptyComponent={
          <StickerEmptyState
            title="这里还空空软软的"
            description={isReady ? "换个关键词试试，或者点下方按钮写下第一张可爱便签。" : "正在翻开你的小本本..."}
          />
        }
      />

      {!shouldRenderCreateMenu ? (
        <Pressable
          accessibilityLabel="展开新建菜单"
          onPress={() => setIsCreateMenuOpen(true)}
          style={({ pressed }) => [styles.addButton, pressed && styles.addButtonPressed]}
        >
          <Ionicons color="#FFFFFF" name="add" size={30} />
        </Pressable>
      ) : null}

      {shouldRenderCreateMenu ? (
        <Pressable
          accessibilityLabel="关闭新建菜单"
          onPress={() => setIsCreateMenuOpen(false)}
          style={styles.createMenuBackdrop}
        />
      ) : null}

      {shouldRenderCreateMenu ? (
        <Animated.View
          pointerEvents={isCreateMenuOpen ? "auto" : "none"}
          style={[
            styles.createMenu,
            {
              width: createMenuProgress.interpolate({
                inputRange: [0, 0.2, 1],
                outputRange: [62, 62, 302]
              }),
              height: createMenuProgress.interpolate({
                inputRange: [0, 0.2, 1],
                outputRange: [62, 62, 360]
              }),
              borderRadius: createMenuProgress.interpolate({
                inputRange: [0, 0.2, 1],
                outputRange: [31, 31, theme.radius.xl]
              }),
              borderWidth: createMenuProgress.interpolate({
                inputRange: [0, 0.2, 1],
                outputRange: [4, 4, 1]
              }),
              backgroundColor: createMenuProgress.interpolate({
                inputRange: [0, 0.2, 1],
                outputRange: [theme.colors.accent, theme.colors.accent, theme.colors.surfaceStrong]
              }),
              borderColor: createMenuProgress.interpolate({
                inputRange: [0, 0.2, 1],
                outputRange: ["#FFFFFF", "#FFFFFF", theme.colors.line]
              }),
              transform: [
                {
                  translateY: createMenuProgress.interpolate({
                    inputRange: [0, 0.2, 1],
                    outputRange: [0, -16, 0]
                  })
                },
                {
                  scale: createMenuProgress.interpolate({
                    inputRange: [0, 0.2, 1],
                    outputRange: [1, 0.94, 1]
                  })
                }
              ]
            }
          ]}
        >
          <Animated.View
            style={[
              styles.createMenuPlus,
              {
                opacity: createMenuProgress.interpolate({
                  inputRange: [0, 0.2, 0.34],
                  outputRange: [1, 1, 0]
                })
              }
            ]}
          >
            <Ionicons color="#FFFFFF" name="add" size={30} />
          </Animated.View>

          <Animated.View
            style={[
              styles.createMenuContent,
              {
                opacity: createMenuProgress.interpolate({
                  inputRange: [0, 0.52, 1],
                  outputRange: [0, 0, 1]
                }),
                transform: [
                  {
                    translateY: createMenuProgress.interpolate({
                      inputRange: [0, 0.52, 1],
                      outputRange: [12, 12, 0]
                    })
                  }
                ]
              }
            ]}
          >
            <ScrollView
              showsVerticalScrollIndicator={false}
              contentContainerStyle={styles.createMenuScrollContent}
            >
              <Text style={styles.createMenuTitle}>新建便签</Text>
              <View style={styles.createMenuGrid}>
                {categories.map((category) => {
                  const iconSource = categoryIconSources[category.id];

                  return (
                    <Pressable
                      accessibilityLabel={`新建${category.name}便签`}
                      key={category.id}
                      onPress={() => {
                        setIsCreateMenuOpen(false);
                        router.push(`/memo/new?categoryId=${category.id}`);
                      }}
                      style={({ pressed }) => [
                        styles.createMenuOption,
                        pressed && styles.createMenuOptionPressed
                      ]}
                    >
                      {iconSource ? (
                        <Image resizeMode="contain" source={iconSource} style={styles.createMenuIcon} />
                      ) : (
                        <Ionicons color={theme.colors.muted} name={category.icon as keyof typeof Ionicons.glyphMap} size={38} />
                      )}
                      <View style={styles.createMenuOptionCopy}>
                        <Text style={styles.createMenuOptionText}>{category.name}</Text>
                        <Text numberOfLines={1} style={styles.createMenuOptionDescription}>
                          {createMenuDescriptions[category.id]}
                        </Text>
                      </View>
                    </Pressable>
                  );
                })}
              </View>
            </ScrollView>
          </Animated.View>
        </Animated.View>
      ) : null}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: theme.colors.background
  },
  header: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: theme.spacing.page,
    paddingTop: 10,
    paddingBottom: 16
  },
  headerText: {
    marginLeft: 12
  },
  eyebrow: {
    color: "#411F0B",
    fontSize: 32,
    lineHeight: 38,
    fontWeight: "900",
    marginBottom: 4
  },
  title: {
    color: theme.colors.text,
    fontSize: 18,
    lineHeight: 22,
    fontWeight: "900"
  },
  avatar: {
    width: 64,
    height: 64,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 32,
    backgroundColor: theme.colors.pink,
    borderWidth: 3,
    borderColor: theme.colors.surfaceStrong
  },
  avatarImage: {
    width: 64,
    height: 64
  },
  searchBox: {
    minHeight: 52,
    flexDirection: "row",
    alignItems: "center",
    marginHorizontal: theme.spacing.page,
    paddingHorizontal: 16,
    borderRadius: theme.radius.lg,
    backgroundColor: theme.colors.surfaceStrong,
    borderWidth: 1,
    borderColor: theme.colors.line,
    shadowColor: theme.colors.shadow,
    shadowOpacity: 0.1,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 6 },
    elevation: 2
  },
  searchInput: {
    flex: 1,
    height: 52,
    marginLeft: 9,
    color: theme.colors.text,
    fontSize: 15,
    fontWeight: "700"
  },
  clearButton: {
    width: 28,
    height: 28,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 14,
    backgroundColor: "#F8ECD8"
  },
  categorySection: {
    marginTop: 16,
    overflow: "visible"
  },
  categoryScroller: {
    height: 74,
    marginTop: -10,
    marginBottom: -24,
    overflow: "visible"
  },
  categoryList: {
    gap: 10,
    paddingHorizontal: theme.spacing.page,
    paddingTop: 10,
    paddingBottom: 24
  },
  memoList: {
    paddingHorizontal: theme.spacing.page,
    paddingTop: 18,
    paddingBottom: 112
  },
  listHeader: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    marginBottom: 12
  },
  sectionTitle: {
    color: theme.colors.text,
    fontSize: 18,
    fontWeight: "900"
  },
  count: {
    color: theme.colors.muted,
    fontSize: 13,
    fontWeight: "800"
  },
  addButton: {
    position: "absolute",
    right: 22,
    bottom: 120,
    zIndex: 6,
    width: 62,
    height: 62,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 31,
    backgroundColor: theme.colors.accent,
    borderWidth: 4,
    borderColor: "#FFFFFF",
    shadowColor: theme.colors.accentStrong,
    shadowOpacity: 0.28,
    shadowRadius: 18,
    shadowOffset: { width: 0, height: 8 },
    elevation: 6
  },
  addButtonPressed: {
    transform: [{ scale: 0.94 }]
  },
  createMenuBackdrop: {
    ...StyleSheet.absoluteFillObject,
    zIndex: 7
  },
  createMenu: {
    position: "absolute",
    right: 22,
    bottom: 120,
    zIndex: 8,
    overflow: "hidden",
    shadowColor: theme.colors.shadow,
    shadowOpacity: 0.18,
    shadowRadius: 22,
    shadowOffset: { width: 0, height: 12 },
    elevation: 10
  },
  createMenuPlus: {
    ...StyleSheet.absoluteFillObject,
    alignItems: "center",
    justifyContent: "center"
  },
  createMenuContent: {
    flex: 1
  },
  createMenuScrollContent: {
    padding: 16
  },
  createMenuTitle: {
    color: theme.colors.text,
    fontSize: 17,
    fontWeight: "900",
    marginBottom: 12
  },
  createMenuGrid: {
    gap: 6
  },
  createMenuOption: {
    minHeight: 54,
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 10,
    paddingVertical: 7,
    borderRadius: theme.radius.sm
  },
  createMenuOptionPressed: {
    backgroundColor: "#F3F0EA",
    transform: [{ scale: 0.96 }]
  },
  createMenuIcon: {
    width: 38,
    height: 38,
    marginRight: 12
  },
  createMenuOptionCopy: {
    flex: 1
  },
  createMenuOptionText: {
    color: theme.colors.text,
    fontSize: 15,
    fontWeight: "800",
    lineHeight: 20
  },
  createMenuOptionDescription: {
    color: theme.colors.muted,
    fontSize: 12,
    fontWeight: "700",
    lineHeight: 18
  }
});
