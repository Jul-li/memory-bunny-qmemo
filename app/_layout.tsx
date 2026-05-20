import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";

import { WebInputFocusReset } from "@/components/WebInputFocusReset";
import { MemoProvider } from "@/context/MemoContext";
import { theme } from "@/constants/theme";

export default function RootLayout() {
  return (
    <MemoProvider>
      <WebInputFocusReset />
      <StatusBar style="dark" backgroundColor={theme.colors.background} />
      <Stack
        screenOptions={{
          headerShown: false,
          contentStyle: {
            backgroundColor: theme.colors.background
          }
        }}
      />
    </MemoProvider>
  );
}
