import { Ionicons } from "@expo/vector-icons";
import { Pressable, StyleSheet, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

import { theme } from "@/constants/theme";
import { useMemos } from "@/context/MemoContext";

export default function SettingsScreen() {
  const { clearMemos } = useMemos();

  return (
    <SafeAreaView style={styles.safeArea}>
      <Text style={styles.title}>设置</Text>
      <View style={styles.appCard}>
        <View style={styles.logo}>
          <Ionicons color={theme.colors.accentStrong} name="book" size={34} />
        </View>
        <Text style={styles.appName}>QMemo Cute</Text>
        <Text style={styles.appIntro}>一本装在手机里的 Q 版手账备忘录。</Text>
      </View>

      <View style={styles.group}>
        <View style={styles.row}>
          <Ionicons color={theme.colors.text} name="color-palette" size={22} />
          <Text style={styles.rowText}>主题设置</Text>
          <Text style={styles.comingSoon}>奶油日光</Text>
        </View>
        <View style={styles.row}>
          <Ionicons color={theme.colors.text} name="information-circle" size={22} />
          <Text style={styles.rowText}>关于 App</Text>
          <Text style={styles.comingSoon}>v1.0.0</Text>
        </View>
      </View>

      <Pressable
        onPress={clearMemos}
        style={({ pressed }) => [styles.clearButton, pressed && styles.pressed]}
      >
        <Ionicons color={theme.colors.accentStrong} name="trash" size={21} />
        <Text style={styles.clearText}>清空本地数据</Text>
      </Pressable>
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
  appCard: {
    alignItems: "center",
    padding: 24,
    borderRadius: theme.radius.xl,
    backgroundColor: theme.colors.surfaceStrong,
    borderWidth: 1,
    borderColor: theme.colors.line,
    marginBottom: 16
  },
  logo: {
    width: 70,
    height: 70,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 28,
    backgroundColor: theme.colors.pink,
    marginBottom: 14
  },
  appName: {
    color: theme.colors.text,
    fontSize: 22,
    fontWeight: "900",
    marginBottom: 6
  },
  appIntro: {
    color: theme.colors.muted,
    fontSize: 14,
    fontWeight: "600",
    textAlign: "center"
  },
  group: {
    overflow: "hidden",
    borderRadius: theme.radius.lg,
    backgroundColor: theme.colors.surfaceStrong,
    borderWidth: 1,
    borderColor: theme.colors.line,
    marginBottom: 16
  },
  row: {
    minHeight: 58,
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    paddingHorizontal: 16,
    borderBottomWidth: 1,
    borderBottomColor: theme.colors.line
  },
  rowText: {
    flex: 1,
    color: theme.colors.text,
    fontSize: 16,
    fontWeight: "800"
  },
  comingSoon: {
    color: theme.colors.muted,
    fontSize: 13,
    fontWeight: "700"
  },
  clearButton: {
    minHeight: 56,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    borderRadius: theme.radius.lg,
    backgroundColor: theme.colors.surfaceStrong,
    borderWidth: 1,
    borderColor: "#F5B8C6"
  },
  clearText: {
    color: theme.colors.accentStrong,
    fontSize: 16,
    fontWeight: "900"
  },
  pressed: {
    transform: [{ scale: 0.98 }]
  }
});
