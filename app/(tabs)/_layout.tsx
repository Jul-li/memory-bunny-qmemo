import { Tabs } from "expo-router";
import type { BottomTabBarProps } from "@react-navigation/bottom-tabs";
import { useEffect, useRef } from "react";
import { Animated, Easing, ImageSourcePropType, Pressable, StyleSheet, Text, View } from "react-native";

import { theme } from "@/constants/theme";

const tabIconSources = {
  index: require("../../assets/tab-icons/home.png"),
  categories: require("../../assets/tab-icons/categories.png"),
  settings: require("../../assets/tab-icons/settings.png")
} satisfies Record<string, ImageSourcePropType>;

type TabIconProps = {
  focused: boolean;
  label: string;
  source: ImageSourcePropType;
};

function TabItem({ focused, label, source }: TabIconProps) {
  const progress = useRef(new Animated.Value(focused ? 1 : 0)).current;

  useEffect(() => {
    Animated.timing(progress, {
      toValue: focused ? 1 : 0,
      duration: 360,
      easing: Easing.bezier(0.22, 1, 0.36, 1),
      useNativeDriver: false
    }).start();
  }, [focused, progress]);

  const itemStyle = {
    width: progress.interpolate({
      inputRange: [0, 1],
      outputRange: [64, 126]
    }),
    backgroundColor: progress.interpolate({
      inputRange: [0, 1],
      outputRange: ["rgba(255,229,234,0)", "#FFE5EA"]
    }),
    borderColor: progress.interpolate({
      inputRange: [0, 1],
      outputRange: ["rgba(247,198,205,0)", "#F7C6CD"]
    })
  };

  const iconStyle = {
    width: progress.interpolate({
      inputRange: [0, 1],
      outputRange: [34, 46]
    }),
    height: progress.interpolate({
      inputRange: [0, 1],
      outputRange: [34, 46]
    }),
    transform: [
      {
        translateX: progress.interpolate({
          inputRange: [0, 1],
          outputRange: [0, -4]
        })
      }
    ]
  };

  const labelWrapStyle = {
    width: progress.interpolate({
      inputRange: [0, 1],
      outputRange: [0, 40]
    }),
    marginLeft: progress.interpolate({
      inputRange: [0, 1],
      outputRange: [0, 4]
    }),
    opacity: progress,
    transform: [
      {
        translateX: progress.interpolate({
          inputRange: [0, 1],
          outputRange: [-8, 0]
        })
      }
    ]
  };

  return (
    <Animated.View style={[styles.tabItem, itemStyle]}>
      <Animated.View
        pointerEvents="none"
        style={[
          styles.tabItemInnerStroke,
          {
            opacity: progress
          }
        ]}
      />
      <Animated.Image
        resizeMode="contain"
        source={source}
        style={iconStyle}
      />
      <Animated.View style={[styles.tabLabelWrap, labelWrapStyle]}>
        <Text numberOfLines={1} style={styles.tabLabel}>
          {label}
        </Text>
      </Animated.View>
    </Animated.View>
  );
}

function CuteTabBar({ state, descriptors, navigation }: BottomTabBarProps) {
  return (
    <View style={styles.tabBar}>
      {state.routes.map((route, index) => {
        const focused = state.index === index;
        const options = descriptors[route.key].options;
        const label = options.title ?? route.name;
        const source = tabIconSources[route.name as keyof typeof tabIconSources];

        return (
          <Pressable
            key={route.key}
            accessibilityLabel={options.tabBarAccessibilityLabel}
            accessibilityRole="button"
            accessibilityState={focused ? { selected: true } : {}}
            onPress={() => {
              const event = navigation.emit({
                type: "tabPress",
                target: route.key,
                canPreventDefault: true
              });

              if (!focused && !event.defaultPrevented) {
                navigation.navigate(route.name, route.params);
              }
            }}
            style={styles.tabButton}
          >
            <TabItem focused={focused} label={label} source={source} />
          </Pressable>
        );
      })}
    </View>
  );
}

export default function TabsLayout() {
  return (
    <Tabs
      tabBar={(props) => <CuteTabBar {...props} />}
      screenOptions={{ headerShown: false }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: "备忘"
        }}
      />
      <Tabs.Screen
        name="categories"
        options={{
          title: "分类"
        }}
      />
      <Tabs.Screen
        name="settings"
        options={{
          title: "设置"
        }}
      />
    </Tabs>
  );
}

const styles = StyleSheet.create({
  tabBar: {
    position: "absolute",
    left: 12,
    right: 12,
    bottom: 18,
    height: 78,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: 16,
    paddingTop: 0,
    paddingBottom: 0,
    borderTopWidth: 0,
    borderRadius: 39,
    backgroundColor: theme.colors.surfaceStrong,
    shadowColor: theme.colors.shadow,
    shadowOpacity: 0.12,
    shadowRadius: 18,
    shadowOffset: { width: 0, height: 6 },
    elevation: 12
  },
  tabButton: {
    flex: 1,
    height: 78,
    alignItems: "center",
    justifyContent: "center"
  },
  tabItem: {
    height: 52,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 999,
    borderWidth: 1,
    overflow: "hidden",
    paddingHorizontal: 14
  },
  tabItemInnerStroke: {
    position: "absolute",
    left: 3,
    right: 3,
    top: 3,
    bottom: 3,
    borderRadius: 999,
    borderWidth: 1,
    borderStyle: "dashed",
    borderColor: "#FDFDFB"
  },
  tabLabel: {
    color: theme.colors.accentStrong,
    fontSize: 16,
    fontWeight: "700",
    lineHeight: 22
  },
  tabLabelWrap: {
    overflow: "hidden"
  }
});
