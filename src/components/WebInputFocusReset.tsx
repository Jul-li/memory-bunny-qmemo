import { useEffect } from "react";
import { Platform } from "react-native";

export function WebInputFocusReset() {
  useEffect(() => {
    if (Platform.OS !== "web") {
      return;
    }

    const styleId = "qmemo-input-focus-reset";
    if (document.getElementById(styleId)) {
      return;
    }

    const style = document.createElement("style");
    style.id = styleId;
    style.textContent = `
      input:focus,
      textarea:focus {
        border-color: transparent !important;
        box-shadow: none !important;
        outline: none !important;
      }
    `;

    document.head.appendChild(style);
  }, []);

  return null;
}
