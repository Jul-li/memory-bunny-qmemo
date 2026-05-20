import { Memo, MemoCardColor, MemoCategory } from "@/types/memo";

export const categories: MemoCategory[] = [
  { id: "life", name: "生活", icon: "cafe" },
  { id: "todo", name: "待办", icon: "checkbox" },
  { id: "study", name: "学习", icon: "school" },
  { id: "idea", name: "灵感", icon: "bulb" },
  { id: "diary", name: "心情", icon: "heart" }
];

export const memoColors: MemoCardColor[] = [
  { id: "cream", name: "奶油黄", value: "#FFF0B8" },
  { id: "pink", name: "浅粉", value: "#FFD7E5" },
  { id: "mint", name: "薄荷绿", value: "#CFF5DD" },
  { id: "sky", name: "天空蓝", value: "#CFEAFF" },
  { id: "lavender", name: "棉花紫", value: "#E5D8FF" },
  { id: "coral", name: "蜜桃橘", value: "#FFC7B8" }
];

export const mockMemos: Memo[] = [
  {
    id: "1",
    title: "周末手账素材",
    content: "买粉色胶带、云朵贴纸和一支顺滑的奶油笔。",
    categoryId: "life",
    colorId: "pink",
    isPinned: true,
    updatedAt: "今天 09:30"
  },
  {
    id: "2",
    title: "英语听力计划",
    content: "每天 20 分钟精听，记录 5 个新表达，睡前复盘。",
    categoryId: "study",
    colorId: "sky",
    isPinned: false,
    updatedAt: "昨天 21:12"
  },
  {
    id: "3",
    title: "便利店新品灵感",
    content: "草莓牛乳包装可以做成小贴纸，配一个圆脸小杯子。",
    categoryId: "idea",
    colorId: "mint",
    isPinned: true,
    updatedAt: "周一 16:45"
  },
  {
    id: "4",
    title: "今天的小任务",
    content: "整理书桌、浇花、把课程截图归档到相册。",
    categoryId: "todo",
    colorId: "cream",
    isPinned: false,
    updatedAt: "5月18日"
  }
];
