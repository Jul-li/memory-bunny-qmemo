import { useEffect, useRef } from "react";
import { Animated, Pressable, StyleSheet, View } from "react-native";

import { theme } from "@/constants/theme";

const trackWidth = 56;
const trackHeight = 34;
const trackPadding = 2;
const trackBorderWidth = 1;
const knobSize = 28;
const knobTravel = trackWidth - knobSize - (trackPadding + trackBorderWidth) * 2;

type IOS26SwitchProps = {
  value: boolean;
  onValueChange: (value: boolean) => void;
  accessibilityLabel?: string;
};

export function IOS26Switch({ value, onValueChange, accessibilityLabel }: IOS26SwitchProps) {
  const progress = useRef(new Animated.Value(value ? 1 : 0)).current;

  useEffect(() => {
    Animated.spring(progress, {
      toValue: value ? 1 : 0,
      damping: 18,
      stiffness: 190,
      mass: 0.75,
      useNativeDriver: false
    }).start();
  }, [progress, value]);

  const knobTranslate = progress.interpolate({
    inputRange: [0, 1],
    outputRange: [0, knobTravel]
  });

  const activeGlowOpacity = progress.interpolate({
    inputRange: [0, 1],
    outputRange: [0, 1]
  });

  const inactiveGlowOpacity = progress.interpolate({
    inputRange: [0, 1],
    outputRange: [1, 0]
  });

  return (
    <Pressable
      accessibilityLabel={accessibilityLabel}
      accessibilityRole="switch"
      accessibilityState={{ checked: value }}
      onPress={() => onValueChange(!value)}
      style={({ pressed }) => [styles.pressable, pressed && styles.pressed]}
    >
      <View style={styles.track}>
        <Animated.View style={[styles.inactiveFill, { opacity: inactiveGlowOpacity }]} />
        <Animated.View style={[styles.activeFill, { opacity: activeGlowOpacity }]} />
        <Animated.View style={[styles.knob, { transform: [{ translateX: knobTranslate }] }]}>
          <View style={styles.knobCore} />
        </Animated.View>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  pressable: {
    width: 62,
    height: 40,
    alignItems: "center",
    justifyContent: "center"
  },
  track: {
    width: trackWidth,
    height: trackHeight,
    overflow: "hidden",
    padding: trackPadding,
    borderRadius: trackHeight / 2,
    backgroundColor: "rgba(255,255,255,0.58)",
    borderWidth: trackBorderWidth,
    borderColor: "rgba(255,255,255,0.86)",
    shadowColor: "#B48A78",
    shadowOpacity: 0.18,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 5 },
    elevation: 3
  },
  inactiveFill: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: "rgba(226,211,198,0.68)"
  },
  activeFill: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: theme.colors.accent
  },
  knob: {
    width: knobSize,
    height: knobSize,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: knobSize / 2,
    backgroundColor: "#FFFFFF",
    borderWidth: 1,
    borderColor: "rgba(255,255,255,0.9)",
    shadowColor: "#765C52",
    shadowOpacity: 0.22,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 3 },
    elevation: 5
  },
  knobCore: {
    width: knobSize - 6,
    height: knobSize - 6,
    borderRadius: (knobSize - 6) / 2,
    backgroundColor: "rgba(255,255,255,0.72)"
  },
  pressed: {
    transform: [{ scale: 0.96 }]
  }
});
