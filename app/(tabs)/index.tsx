import { Ionicons } from "@expo/vector-icons";
import { usePathname, useRouter } from "expo-router";
import { useEffect, useMemo, useRef, useState } from "react";
import {
  Animated,
  Easing,
  FlatList,
  Image,
  ImageSourcePropType,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  useWindowDimensions,
  View,
  ViewStyle
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

import { CategoryPill } from "@/components/CategoryPill";
import { MemoCard } from "@/components/MemoCard";
import { StickerEmptyState } from "@/components/StickerEmptyState";
import { theme } from "@/constants/theme";
import { useMemos } from "@/context/MemoContext";
import { categories } from "@/data/mockMemos";
import { Memo, MemoCategoryId } from "@/types/memo";

type ActiveCategory = "all" | MemoCategoryId;
type MemoActionAnchor = {
  x: number;
  y: number;
  source: "longPress" | "more";
  cardTop?: number;
  cardBottom?: number;
};
type SearchEntryIconMode = "search" | "close";

const actionMenuWidth = 184;
const actionMenuEstimatedHeight = 166;
const actionMenuBottomReservedHeight = 128;
const actionMenuGap = 8;
const searchBackdropBlurStyle = Platform.select({
  web: {
    backdropFilter: "blur(10px)",
    WebkitBackdropFilter: "blur(10px)"
  } as unknown as ViewStyle,
  default: {}
});

const avatarSource = require("../../assets/profile-icons/avatar.png");
const appLogoSource = require("../../assets/brand/app_logo.svg");
const searchIconSource = require("../../assets/action-icons/search.png");
const closeIconSource = require("../../assets/action-icons/close.png");

const categoryIconSources: Partial<Record<MemoCategoryId, ImageSourcePropType>> = {
  life: require("../../assets/category-icons/life.png"),
  todo: require("../../assets/category-icons/todo.png"),
  study: require("../../assets/category-icons/study.png"),
  idea: require("../../assets/category-icons/idea.png"),
  diary: require("../../assets/category-icons/diary.png")
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

const categoryScrollerOverflow = {
  overflowY: "visible"
} as const;

export default function HomeScreen() {
  const pathname = usePathname();
  const router = useRouter();
  const { deleteMemo, memos, isReady, saveMemo } = useMemos();
  const { height: viewportHeight, width: viewportWidth } = useWindowDimensions();
  const [searchText, setSearchText] = useState("");
  const [isSearchOpen, setIsSearchOpen] = useState(false);
  const [shouldRenderSearch, setShouldRenderSearch] = useState(false);
  const [searchEntryIconMode, setSearchEntryIconMode] = useState<SearchEntryIconMode>("search");
  const [activeCategory, setActiveCategory] = useState<ActiveCategory>("all");
  const [isCreateMenuOpen, setIsCreateMenuOpen] = useState(false);
  const [shouldRenderCreateMenu, setShouldRenderCreateMenu] = useState(false);
  const [actionMenuMemo, setActionMenuMemo] = useState<Memo | null>(null);
  const [actionMenuAnchor, setActionMenuAnchor] = useState<MemoActionAnchor | null>(null);
  const [isActionMenuOpen, setIsActionMenuOpen] = useState(false);
  const [shouldRenderActionMenu, setShouldRenderActionMenu] = useState(false);
  const createMenuProgress = useRef(new Animated.Value(0)).current;
  const actionMenuProgress = useRef(new Animated.Value(0)).current;
  const searchProgress = useRef(new Animated.Value(0)).current;
  const searchEntryIconProgress = useRef(new Animated.Value(1)).current;
  const searchInputRef = useRef<TextInput>(null);
  const searchIconSwapTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    return () => {
      if (searchIconSwapTimerRef.current) {
        clearTimeout(searchIconSwapTimerRef.current);
      }
    };
  }, []);

  useEffect(() => {
    if (pathname !== "/") {
      setIsCreateMenuOpen(false);
      setIsActionMenuOpen(false);
      setIsSearchOpen(false);
      setSearchEntryIconMode("search");
      searchEntryIconProgress.setValue(1);
    }
  }, [pathname, searchEntryIconProgress]);

  useEffect(() => {
    if (isSearchOpen) {
      setShouldRenderSearch(true);

      Animated.timing(searchProgress, {
        toValue: 1,
        duration: 460,
        easing: Easing.bezier(0.22, 1, 0.36, 1),
        useNativeDriver: false
      }).start(({ finished }) => {
        if (finished) {
          searchInputRef.current?.focus();
        }
      });
      return;
    }

    Animated.timing(searchProgress, {
      toValue: 0,
      duration: 360,
      easing: Easing.bezier(0.64, 0, 0.78, 0),
      useNativeDriver: false
    }).start(({ finished }) => {
      if (finished && !isSearchOpen) {
        setShouldRenderSearch(false);
        setSearchText("");
      }
    });
  }, [isSearchOpen, searchProgress]);

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

  useEffect(() => {
    if (isActionMenuOpen) {
      setShouldRenderActionMenu(true);

      Animated.spring(actionMenuProgress, {
        toValue: 1,
        friction: 7,
        tension: 120,
        useNativeDriver: true
      }).start();
      return;
    }

    Animated.timing(actionMenuProgress, {
      toValue: 0,
      duration: 180,
      easing: Easing.out(Easing.quad),
      useNativeDriver: true
    }).start(({ finished }) => {
      if (finished && !isActionMenuOpen) {
        setShouldRenderActionMenu(false);
        setActionMenuMemo(null);
        setActionMenuAnchor(null);
      }
    });
  }, [actionMenuProgress, isActionMenuOpen]);

  const openMemoActionMenu = (memo: Memo, anchor: MemoActionAnchor) => {
    setIsCreateMenuOpen(false);
    actionMenuProgress.setValue(0);
    setActionMenuMemo(memo);
    setActionMenuAnchor(anchor);
    setShouldRenderActionMenu(true);
    setIsActionMenuOpen(true);
  };

  const closeMemoActionMenu = () => {
    setIsActionMenuOpen(false);
  };

  const openSearch = () => {
    if (searchIconSwapTimerRef.current) {
      clearTimeout(searchIconSwapTimerRef.current);
    }

    setIsCreateMenuOpen(false);
    setIsActionMenuOpen(false);
    searchProgress.setValue(0);
    setShouldRenderSearch(true);
    setSearchEntryIconMode("search");
    searchEntryIconProgress.setValue(1);
    setIsSearchOpen(true);

    Animated.timing(searchEntryIconProgress, {
      toValue: 0,
      duration: 150,
      easing: Easing.out(Easing.quad),
      useNativeDriver: true
    }).start();

    searchIconSwapTimerRef.current = setTimeout(() => {
      setSearchEntryIconMode("close");
      searchEntryIconProgress.setValue(0);
      Animated.spring(searchEntryIconProgress, {
        toValue: 1,
        friction: 5,
        tension: 170,
        useNativeDriver: true
      }).start();
    }, 150);
  };

  const closeSearch = () => {
    if (searchIconSwapTimerRef.current) {
      clearTimeout(searchIconSwapTimerRef.current);
    }

    Animated.timing(searchEntryIconProgress, {
      toValue: 0,
      duration: 150,
      easing: Easing.out(Easing.quad),
      useNativeDriver: true
    }).start();

    searchIconSwapTimerRef.current = setTimeout(() => {
      setSearchEntryIconMode("search");
      searchEntryIconProgress.setValue(0);
      Animated.spring(searchEntryIconProgress, {
        toValue: 1,
        friction: 5,
        tension: 170,
        useNativeDriver: true
      }).start();
    }, 150);

    setIsSearchOpen(false);
  };

  const toggleSearch = () => {
    if (isSearchOpen) {
      closeSearch();
      return;
    }

    openSearch();
  };

  const handleTogglePin = async () => {
    if (!actionMenuMemo) {
      return;
    }

    const memo = actionMenuMemo;
    closeMemoActionMenu();
    await saveMemo({
      id: memo.id,
      title: memo.title,
      content: memo.content,
      categoryId: memo.categoryId,
      colorId: memo.colorId,
      isPinned: !memo.isPinned
    });
  };

  const handleDeleteMemo = async () => {
    if (!actionMenuMemo) {
      return;
    }

    const id = actionMenuMemo.id;
    closeMemoActionMenu();
    await deleteMemo(id);
  };

  const handleEditMemo = () => {
    if (!actionMenuMemo) {
      return;
    }

    const id = actionMenuMemo.id;
    closeMemoActionMenu();
    router.push(`/memo/${id}`);
  };

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

  const actionMenuPosition = useMemo(() => {
    const fallbackX = viewportWidth - theme.spacing.page - actionMenuWidth;
    const fallbackY = viewportHeight / 2;
    const anchorX = actionMenuAnchor?.x ?? fallbackX;
    const anchorY = actionMenuAnchor?.y ?? fallbackY;
    const cardTop = actionMenuAnchor?.cardTop;
    const bottomLimit = viewportHeight - actionMenuBottomReservedHeight - actionMenuEstimatedHeight;
    const shouldOpenAbove =
      actionMenuAnchor?.source === "longPress" &&
      cardTop !== undefined &&
      anchorY > bottomLimit;
    const top = shouldOpenAbove
      ? Math.max(theme.spacing.page, cardTop - actionMenuEstimatedHeight - actionMenuGap)
      : Math.min(
          Math.max(anchorY, theme.spacing.page),
          Math.max(theme.spacing.page, bottomLimit)
        );

    return {
      placement: shouldOpenAbove ? "above" : "below",
      style: {
        left: Math.min(
          Math.max(anchorX - actionMenuWidth / 2, theme.spacing.page),
          viewportWidth - actionMenuWidth - theme.spacing.page
        ),
        top
      }
    };
  }, [actionMenuAnchor, viewportHeight, viewportWidth]);

  const searchSlotStyle = {
    height: searchProgress.interpolate({
      inputRange: [0, 0.24, 1],
      outputRange: [0, 20, 70]
    }),
    opacity: searchProgress.interpolate({
      inputRange: [0, 0.08, 1],
      outputRange: [0, 1, 1]
    })
  };

  const searchBoxStyle = {
    width: searchProgress.interpolate({
      inputRange: [0, 0.24, 1],
      outputRange: [44, 44, viewportWidth - theme.spacing.page * 2]
    }),
    height: searchProgress.interpolate({
      inputRange: [0, 0.24, 1],
      outputRange: [44, 44, 52]
    }),
    borderRadius: searchProgress.interpolate({
      inputRange: [0, 0.24, 1],
      outputRange: [22, 22, theme.radius.lg]
    }),
    opacity: searchProgress.interpolate({
      inputRange: [0, 0.06, 1],
      outputRange: [0, 1, 1]
    }),
    transform: [
      {
        translateY: searchProgress.interpolate({
          inputRange: [0, 0.24, 1],
          outputRange: [-58, -46, 0]
        })
      },
      {
        scale: searchProgress.interpolate({
          inputRange: [0, 0.2, 1],
          outputRange: [0.86, 0.94, 1]
        })
      }
    ]
  };

  const searchEntryIconStyle = {
    transform: [
      {
        scale: searchEntryIconProgress
      }
    ]
  };

  const searchBoxContentStyle = {
    opacity: searchProgress.interpolate({
      inputRange: [0, 0.48, 1],
      outputRange: [0, 0, 1]
    })
  };

  return (
    <SafeAreaView style={styles.safeArea}>
      <View style={styles.header}>
        <View style={styles.headerBrand}>
          <View style={styles.avatar}>
            <Image resizeMode="contain" source={avatarSource} style={styles.avatarImage} />
          </View>
          <View style={styles.headerText}>
            <Image resizeMode="contain" source={appLogoSource} style={styles.logoImage} />
            <Text style={styles.title}>今天想记点什么？</Text>
          </View>
        </View>
        <Pressable
          accessibilityLabel={isSearchOpen ? "关闭搜索" : "打开搜索"}
          onPress={toggleSearch}
          style={({ pressed }) => [styles.searchEntry, pressed && styles.searchEntryPressed]}
        >
          <Animated.Image
            resizeMode="contain"
            source={searchEntryIconMode === "close" ? closeIconSource : searchIconSource}
            style={[styles.searchEntryIcon, searchEntryIconStyle]}
          />
        </Pressable>
      </View>

      {shouldRenderSearch ? (
        <Animated.View style={[styles.searchSlot, searchSlotStyle]}>
          <Animated.View style={[styles.searchBox, searchBoxStyle]}>
            <Animated.View style={[styles.searchBoxContent, searchBoxContentStyle]}>
              <Ionicons color={theme.colors.muted} name="search" size={20} />
              <TextInput
                ref={searchInputRef}
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
            </Animated.View>
          </Animated.View>
        </Animated.View>
      ) : null}

      <View style={styles.categorySection}>
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          style={[styles.categoryScroller, categoryScrollerOverflow]}
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

      <View style={styles.listHeader}>
        <Text style={styles.sectionTitle}>我的便签</Text>
        <Text style={styles.count}>{isReady ? `${filteredMemos.length} 条` : "加载中"}</Text>
      </View>

      <FlatList
        data={filteredMemos}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => (
          <MemoCard
            memo={item}
            onLongPress={openMemoActionMenu}
            onMorePress={openMemoActionMenu}
            onPress={() => router.push(`/memo/${item.id}`)}
          />
        )}
        showsVerticalScrollIndicator={false}
        style={styles.memoScroller}
        contentContainerStyle={styles.memoList}
        ListEmptyComponent={
          <StickerEmptyState
            title="这里还空空软软的"
            description={isReady ? "换个关键词试试，或者点下方按钮写下第一张可爱便签。" : "正在翻开你的小本本..."}
          />
        }
      />

      {shouldRenderSearch ? (
        <Animated.View
          pointerEvents={isSearchOpen ? "auto" : "none"}
          style={[
            styles.searchDismissLayer,
            {
              opacity: searchProgress.interpolate({
                inputRange: [0, 0.46, 1],
                outputRange: [0, 0, 1]
              })
            }
          ]}
        >
          <Pressable
            accessibilityLabel="关闭搜索"
            onPress={closeSearch}
            style={styles.searchDismissTapTarget}
          >
            <View pointerEvents="none" style={[styles.searchBlurBackdrop, searchBackdropBlurStyle]} />
          </Pressable>
        </Animated.View>
      ) : null}

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

      {shouldRenderActionMenu ? (
        <Animated.View
          pointerEvents={isActionMenuOpen ? "auto" : "none"}
          style={[
            styles.actionBackdropWrap,
            {
              opacity: actionMenuProgress
            }
          ]}
        >
          <Pressable
            accessibilityLabel="关闭便签操作菜单"
            onPress={closeMemoActionMenu}
            style={styles.actionBackdropTapTarget}
          >
            <View pointerEvents="none" style={[styles.actionBackdrop, searchBackdropBlurStyle]} />
          </Pressable>
        </Animated.View>
      ) : null}

      {shouldRenderActionMenu && actionMenuMemo ? (
        <Animated.View
          pointerEvents={isActionMenuOpen ? "auto" : "none"}
          style={[
            styles.actionMenu,
            actionMenuPosition.style,
            {
              opacity: actionMenuProgress,
              transform: [
                {
                  translateY: actionMenuProgress.interpolate({
                    inputRange: [0, 1],
                    outputRange: [actionMenuPosition.placement === "above" ? 10 : -10, 0]
                  })
                },
                {
                  scale: actionMenuProgress.interpolate({
                    inputRange: [0, 1],
                    outputRange: [0.86, 1]
                  })
                }
              ]
            }
          ]}
        >
          <Pressable
            onPress={handleTogglePin}
            style={({ pressed }) => [styles.actionMenuItem, pressed && styles.actionMenuItemPressed]}
          >
            <Ionicons color={theme.colors.text} name={actionMenuMemo.isPinned ? "remove-circle" : "push"} size={20} />
            <Text style={styles.actionMenuText}>{actionMenuMemo.isPinned ? "取消置顶" : "置顶"}</Text>
          </Pressable>
          <Pressable
            onPress={handleDeleteMemo}
            style={({ pressed }) => [styles.actionMenuItem, pressed && styles.actionMenuItemPressed]}
          >
            <Ionicons color={theme.colors.accentStrong} name="trash" size={20} />
            <Text style={[styles.actionMenuText, styles.actionMenuDangerText]}>删除</Text>
          </Pressable>
          <Pressable
            onPress={handleEditMemo}
            style={({ pressed }) => [styles.actionMenuItem, pressed && styles.actionMenuItemPressed]}
          >
            <Ionicons color={theme.colors.text} name="create" size={20} />
            <Text style={styles.actionMenuText}>编辑</Text>
          </Pressable>
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
    position: "relative",
    zIndex: 8,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: theme.spacing.page,
    paddingTop: 10,
    paddingBottom: 16
  },
  headerBrand: {
    flexDirection: "row",
    alignItems: "center"
  },
  headerText: {
    marginLeft: 12
  },
  logoImage: {
    width: 104,
    height: 40,
    marginBottom: 4
  },
  title: {
    color: theme.colors.text,
    fontSize: 16,
    lineHeight: 22,
    fontWeight: "400"
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
  searchEntry: {
    width: 52,
    height: 52,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 26
  },
  searchEntryPressed: {
    transform: [{ scale: 0.94 }]
  },
  searchEntryIcon: {
    width: 42,
    height: 42
  },
  searchSlot: {
    position: "relative",
    zIndex: 8,
    overflow: "visible"
  },
  searchBox: {
    position: "absolute",
    right: theme.spacing.page,
    top: 0,
    zIndex: 8,
    overflow: "hidden",
    backgroundColor: theme.colors.surfaceStrong,
    borderWidth: 1,
    borderColor: theme.colors.line,
    shadowColor: theme.colors.shadow,
    shadowOpacity: 0.1,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 6 },
    elevation: 2
  },
  searchBoxContent: {
    flex: 1,
    width: "100%",
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 16
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
  searchDismissLayer: {
    ...StyleSheet.absoluteFillObject,
    zIndex: 7
  },
  searchDismissTapTarget: {
    ...StyleSheet.absoluteFillObject
  },
  searchBlurBackdrop: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: "rgba(255,248,229,0.68)"
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
    paddingTop: 12,
    paddingBottom: 112
  },
  memoScroller: {
    flex: 1
  },
  listHeader: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    marginTop: 18,
    paddingHorizontal: theme.spacing.page
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
  },
  actionBackdropWrap: {
    ...StyleSheet.absoluteFillObject,
    zIndex: 9
  },
  actionBackdropTapTarget: {
    ...StyleSheet.absoluteFillObject
  },
  actionBackdrop: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: "rgba(255,248,229,0.68)"
  },
  actionMenu: {
    position: "absolute",
    zIndex: 10,
    width: actionMenuWidth,
    padding: 8,
    borderRadius: theme.radius.md,
    backgroundColor: theme.colors.surfaceStrong,
    borderWidth: 1,
    borderColor: "rgba(255,255,255,0.82)",
    shadowColor: "#000000",
    shadowOpacity: 0.14,
    shadowRadius: 18,
    shadowOffset: { width: 0, height: 10 },
    elevation: 12
  },
  actionMenuItem: {
    minHeight: 46,
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
    paddingHorizontal: 12,
    borderRadius: theme.radius.sm
  },
  actionMenuItemPressed: {
    backgroundColor: "#F3F0EA",
    transform: [{ scale: 0.98 }]
  },
  actionMenuText: {
    color: theme.colors.text,
    fontSize: 15,
    fontWeight: "800"
  },
  actionMenuDangerText: {
    color: theme.colors.accentStrong
  }
});
