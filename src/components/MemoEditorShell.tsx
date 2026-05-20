import { Ionicons } from "@expo/vector-icons";
import { useRouter } from "expo-router";
import { PropsWithChildren } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

import { theme } from "@/constants/theme";

type MemoEditorShellProps = PropsWithChildren<{
  title: string;
  subtitle: string;
}>;

export function MemoEditorShell({ title, subtitle, children }: MemoEditorShellProps) {
  const router = useRouter();

  const handleBack = () => {
    if (router.canGoBack()) {
      router.back();
      return;
    }

    router.replace("/");
  };

  return (
    <SafeAreaView style={styles.safeArea}>
      <View style={styles.header}>
        <Pressable
          accessibilityLabel="返回"
          onPress={handleBack}
          style={({ pressed }) => [styles.backButton, pressed && styles.pressed]}
        >
          <Ionicons color={theme.colors.text} name="chevron-back" size={24} />
        </Pressable>
        <View style={styles.heading}>
          <Text style={styles.title}>{title}</Text>
          <Text style={styles.subtitle}>{subtitle}</Text>
        </View>
        <View style={styles.headerSpacer} />
      </View>

      <View style={styles.card}>{children}</View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    paddingHorizontal: theme.spacing.page,
    backgroundColor: theme.colors.background
  },
  header: {
    minHeight: 72,
    flexDirection: "row",
    alignItems: "center",
    paddingTop: 8,
    paddingBottom: 16
  },
  backButton: {
    width: 46,
    height: 46,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 23,
    backgroundColor: theme.colors.surfaceStrong,
    borderWidth: 1,
    borderColor: theme.colors.line
  },
  heading: {
    flex: 1,
    alignItems: "center",
    paddingHorizontal: 10
  },
  title: {
    color: theme.colors.text,
    fontSize: 22,
    fontWeight: "900",
    marginBottom: 4
  },
  subtitle: {
    color: theme.colors.muted,
    fontSize: 13,
    fontWeight: "700",
    textAlign: "center"
  },
  headerSpacer: {
    width: 46
  },
  card: {
    flex: 1,
    padding: 22,
    borderRadius: theme.radius.xl,
    backgroundColor: theme.colors.surfaceStrong,
    borderWidth: 1,
    borderColor: theme.colors.line,
    shadowColor: theme.colors.shadow,
    shadowOpacity: 0.12,
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 8 },
    elevation: 3
  },
  pressed: {
    transform: [{ scale: 0.96 }]
  }
});
