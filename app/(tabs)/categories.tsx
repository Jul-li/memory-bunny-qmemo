import { Ionicons } from "@expo/vector-icons";
import { FlatList, StyleSheet, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

import { theme } from "@/constants/theme";
import { categories } from "@/data/mockMemos";

export default function CategoriesScreen() {
  return (
    <SafeAreaView style={styles.safeArea}>
      <Text style={styles.title}>分类贴纸盒</Text>
      <FlatList
        data={categories}
        keyExtractor={(item) => item.id}
        contentContainerStyle={styles.list}
        renderItem={({ item }) => (
          <View style={styles.categoryCard}>
            <View style={styles.iconWrap}>
              <Ionicons color={theme.colors.text} name={item.icon as keyof typeof Ionicons.glyphMap} size={24} />
            </View>
            <View>
              <Text style={styles.name}>{item.name}</Text>
              <Text style={styles.description}>默认分类，后续可接入自定义管理。</Text>
            </View>
          </View>
        )}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: theme.colors.background,
    paddingHorizontal: theme.spacing.page
  },
  title: {
    color: theme.colors.text,
    fontSize: 28,
    fontWeight: "900",
    paddingTop: 10,
    paddingBottom: 18
  },
  list: {
    gap: 12,
    paddingBottom: 120
  },
  categoryCard: {
    flexDirection: "row",
    alignItems: "center",
    gap: 14,
    padding: 16,
    borderRadius: theme.radius.lg,
    backgroundColor: theme.colors.surfaceStrong,
    borderWidth: 1,
    borderColor: theme.colors.line
  },
  iconWrap: {
    width: 52,
    height: 52,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 20,
    backgroundColor: theme.colors.mint
  },
  name: {
    color: theme.colors.text,
    fontSize: 17,
    fontWeight: "900",
    marginBottom: 4
  },
  description: {
    color: theme.colors.muted,
    fontSize: 13,
    fontWeight: "600"
  }
});
