import { Ionicons } from "@expo/vector-icons";
import { StyleSheet, Text, View } from "react-native";

import { theme } from "@/constants/theme";

type StickerEmptyStateProps = {
  title: string;
  description: string;
};

export function StickerEmptyState({ title, description }: StickerEmptyStateProps) {
  return (
    <View style={styles.wrapper}>
      <View style={styles.illustration}>
        <View style={styles.note}>
          <Ionicons color={theme.colors.accentStrong} name="heart" size={24} />
          <View style={styles.lineLong} />
          <View style={styles.lineShort} />
        </View>
        <View style={styles.star}>
          <Ionicons color="#F4BA4D" name="star" size={22} />
        </View>
      </View>
      <Text style={styles.title}>{title}</Text>
      <Text style={styles.description}>{description}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  wrapper: {
    alignItems: "center",
    paddingHorizontal: 24,
    paddingVertical: 46,
    borderRadius: theme.radius.xl,
    backgroundColor: theme.colors.surface,
    borderWidth: 1,
    borderColor: theme.colors.line,
    marginTop: 12
  },
  illustration: {
    width: 116,
    height: 96,
    alignItems: "center",
    justifyContent: "center",
    marginBottom: 16
  },
  note: {
    width: 86,
    height: 78,
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    borderRadius: 24,
    backgroundColor: theme.colors.pink,
    borderWidth: 3,
    borderColor: "#FFFFFF",
    transform: [{ rotate: "-7deg" }]
  },
  star: {
    position: "absolute",
    right: 6,
    top: 2,
    width: 38,
    height: 38,
    borderRadius: 19,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: theme.colors.cream
  },
  lineLong: {
    width: 48,
    height: 7,
    borderRadius: 999,
    backgroundColor: "rgba(255,255,255,0.72)"
  },
  lineShort: {
    width: 34,
    height: 7,
    borderRadius: 999,
    backgroundColor: "rgba(255,255,255,0.72)"
  },
  title: {
    color: theme.colors.text,
    fontSize: 18,
    fontWeight: "900",
    marginBottom: 8,
    textAlign: "center"
  },
  description: {
    color: theme.colors.muted,
    fontSize: 14,
    lineHeight: 20,
    fontWeight: "600",
    textAlign: "center"
  }
});
