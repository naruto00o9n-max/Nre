import { requireNativeModule, requireNativeView } from "expo";
import { ViewProps } from "react-native";
export const LongImage = requireNativeModule("LongImage") as {
  inspectFont(uri: string): Promise<boolean>;
  inspect(uri: string): Promise<{ width: number; height: number }>;
  exportPng(uri: string, layers: string): Promise<string>;
};
export type Layer = {
  id: string;
  type: "text" | "stroke";
  name: string;
  visible: boolean;
  opacity: number;
  color: string;
  size: number;
  points?: number[][];
  text?: string;
  x?: number;
  y?: number;
  font?: string;
};
export const LongImageCanvas = requireNativeView<
  ViewProps & {
    source: string;
    layers: string;
    tool: string;
    brushColor: string;
    brushSize: number;
    onStroke: (event: {
      nativeEvent: { points: string; type: string };
    }) => void;
    onFailure: (event: { nativeEvent: { message: string } }) => void;
  }
>("LongImage");
