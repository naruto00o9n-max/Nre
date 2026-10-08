import React, { useMemo, useState } from "react";
import {
  Alert,
  ActivityIndicator,
  Platform,
  Pressable,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";
import { StatusBar } from "expo-status-bar";
import * as DocumentPicker from "expo-document-picker";
import { Directory, File, Paths } from "expo-file-system";
import * as Sharing from "expo-sharing";
import type { Layer } from "./modules/long-image";
import { validateProject } from "./src/project";
const native =
  Platform.OS === "android" || Platform.OS === "ios"
    ? require("./modules/long-image")
    : null;
const colors = [
  "#ffffff",
  "#111111",
  "#ef4444",
  "#f59e0b",
  "#22c55e",
  "#3b82f6",
];
const fonts = [
  ["sans-serif", "بلا زوائد"],
  ["serif", "بزوائد"],
  ["monospace", "ثابت العرض"],
];
export default function App() {
  const [source, setSource] = useState("");
  const [dimensions, setDimensions] = useState({ width: 0, height: 0 });
  const [layers, setLayers] = useState<Layer[]>([]);
  const [past, setPast] = useState<Layer[][]>([]);
  const [future, setFuture] = useState<Layer[][]>([]);
  const [selected, setSelected] = useState("");
  const [tool, setTool] = useState("pan");
  const [color, setColor] = useState("#ffffff");
  const [size, setSize] = useState("48");
  const [customFonts, setCustomFonts] = useState<string[]>([]);
  const [text, setText] = useState("النص العربي هنا");
  const [font, setFont] = useState("sans-serif");
  const [busy, setBusy] = useState("");
  const [panel, setPanel] = useState(true);
  const layerJson = useMemo(() => JSON.stringify(layers), [layers]);
  const chosen = layers.find((l) => l.id === selected);
  const commit = (next: Layer[]) => {
    setPast((p) => [...p.slice(-49), layers]);
    setLayers(next);
    setFuture([]);
  };
  const update = (changes: Partial<Layer>) =>
    commit(layers.map((l) => (l.id === selected ? { ...l, ...changes } : l)));
  const guarded = async (label: string, fn: () => Promise<void>) => {
    setBusy(label);
    try {
      await fn();
    } catch (e) {
      Alert.alert("تعذر إتمام العملية", String(e));
    } finally {
      setBusy("");
    }
  };
  const open = () =>
    guarded("فتح الصورة", async () => {
      const result = await DocumentPicker.getDocumentAsync({
        type: ["image/png", "image/jpeg", "image/webp"],
        copyToCacheDirectory: true,
      });
      if (result.canceled) return;
      const dir = new Directory(Paths.document, "originals");
      dir.create({ idempotent: true, intermediates: true });
      const original = new File(
        dir,
        `${Date.now()}-${result.assets[0].name.replace(/[^\w.-]/g, "_")}`,
      );
      new File(result.assets[0].uri).copy(original);
      try {
        const info = await native.LongImage.inspect(original.uri);
        setSource(original.uri);
        setDimensions(info);
        setLayers([]);
        setPast([]);
        setFuture([]);
        setSelected("");
      } catch (e) {
        original.delete();
        throw e;
      }
    });
  const importFont = () =>
    guarded("استيراد الخط", async () => {
      const result = await DocumentPicker.getDocumentAsync({
        type: "*/*",
        copyToCacheDirectory: true,
      });
      if (result.canceled) return;
      if (!/\.(ttf|otf)$/i.test(result.assets[0].name))
        throw Error("اختر ملف TTF أو OTF");
      const dir = new Directory(Paths.document, "fonts");
      dir.create({ idempotent: true, intermediates: true });
      const file = new File(
        dir,
        `${Date.now()}.${result.assets[0].name.split(".").pop()}`,
      );
      new File(result.assets[0].uri).copy(file);
      try {
        await native.LongImage.inspectFont(file.uri);
      } catch (e) {
        file.delete();
        throw e;
      }
      setCustomFonts((v) => [...v, file.uri]);
      setFont(file.uri);
    });
  const save = () =>
    guarded("حفظ المشروع", async () => {
      const dir = new Directory(Paths.document, "projects");
      dir.create({ idempotent: true, intermediates: true });
      const file = new File(dir, `project-${Date.now()}.json`);
      file.write(JSON.stringify({ version: 1, source, dimensions, layers }));
      Alert.alert(
        "حُفظ المشروع",
        "الصورة الأصلية والطبقات محفوظة داخل التطبيق. يمكنك فتحه من قائمة المشاريع.",
      );
    });
  const reopen = () =>
    guarded("فتح المشروع", async () => {
      const dir = new Directory(Paths.document, "projects");
      if (!dir.exists) {
        Alert.alert("المشاريع", "لا توجد مشاريع محفوظة");
        return;
      }
      const files = dir
        .list()
        .filter((f): f is File => f instanceof File && f.name.endsWith(".json"))
        .sort((a, b) => b.name.localeCompare(a.name));
      if (!files.length) {
        Alert.alert("المشاريع", "لا توجد مشاريع محفوظة");
        return;
      }
      Alert.alert("المشاريع المحفوظة", "اختر مشروعًا (آخر 8 مشاريع)", [
        ...files.slice(0, 8).map((file) => ({
          text: file.name.replace("project-", "").replace(".json", ""),
          onPress: () =>
            guarded("استعادة المشروع", async () => {
              const p = validateProject(JSON.parse(await file.text()));
              const info = await native.LongImage.inspect(p.source);
              if (
                info.width !== p.dimensions.width ||
                info.height !== p.dimensions.height
              )
                throw Error("أبعاد المصدر لا تطابق المشروع");
              setSource(p.source);
              setDimensions(info);
              setLayers(p.layers);
              setPast([]);
              setFuture([]);
              setSelected("");
            }),
        })),
        { text: "إلغاء", style: "cancel" },
      ]);
    });
  const exportImage = () =>
    guarded("تصدير PNG بالدقة الأصلية…", async () => {
      const uri = await native.LongImage.exportPng(
        source,
        JSON.stringify(layers),
      );
      const dir = new Directory(Paths.document, "exports");
      dir.create({ idempotent: true, intermediates: true });
      const output = new File(dir, `manhwa-${Date.now()}.png`);
      new File(uri).move(output);
      if (await Sharing.isAvailableAsync())
        await Sharing.shareAsync(output.uri, {
          mimeType: "image/png",
          dialogTitle: "حفظ الصورة الأصلية الدقة",
        });
      else Alert.alert("اكتمل التصدير", output.uri);
    });
  const button = (
    label: string,
    action: () => void,
    active = false,
    disabled = false,
  ) => (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      disabled={disabled || !!busy}
      onPress={action}
      style={[
        s.button,
        active && s.active,
        (disabled || !!busy) && { opacity: 0.35 },
      ]}
    >
      <Text style={s.buttonText}>{label}</Text>
    </Pressable>
  );
  if (!native)
    return (
      <SafeAreaView style={s.root}>
        <Text style={s.title}>مرسم المانهوا</Text>
        <Text style={s.hint}>
          هذه النسخة تستخدم محركًا أصليًا. شغّل بناء التطوير على Android أو iOS؛
          معاينة الويب وExpo Go لا تشغّلان المحرك.
        </Text>
      </SafeAreaView>
    );
  return (
    <SafeAreaView style={s.root}>
      <StatusBar style="light" />
      <View style={s.header}>
        <View>
          <Text style={s.title}>مرسم المانهوا</Text>
          <Text style={s.subtitle}>
            {source
              ? `${dimensions.width} × ${dimensions.height} بكسل · الأصل محفوظ`
              : "مساحتك لتحرير الصفحات الطويلة"}
          </Text>
        </View>
        {button("المشاريع", reopen)}
      </View>
      <View style={s.row}>
        {button("استيراد", open)}
        {button("حفظ المشروع", save, false, !source)}
        {button("تصدير PNG", exportImage, true, !source)}
      </View>
      <View style={s.canvas}>
        {source ? (
          <native.LongImageCanvas
            style={{ flex: 1 }}
            pointerEvents={busy ? "none" : "auto"}
            source={source}
            layers={layerJson}
            tool={tool}
            brushColor={color}
            brushSize={Number(size) || 48}
            onFailure={(e: { nativeEvent: { message: string } }) =>
              Alert.alert("خطأ في الصورة", e.nativeEvent.message)
            }
            onStroke={(e: {
              nativeEvent: { points: string; type: string };
            }) => {
              const points = JSON.parse(e.nativeEvent.points);
              if (e.nativeEvent.type === "move") {
                if (chosen?.type === "text")
                  update({ x: points[0][0], y: points[0][1] });
                return;
              }
              const id =
                Date.now().toString() + Math.random().toString(16).slice(2);
              const layer: Layer =
                e.nativeEvent.type === "text"
                  ? {
                      id,
                      type: "text",
                      name: text.slice(0, 20),
                      text,
                      x: points[0][0],
                      y: points[0][1],
                      font,
                      color,
                      size: Number(size) || 48,
                      visible: true,
                      opacity: 1,
                    }
                  : {
                      id,
                      type: "stroke",
                      name: "رسم",
                      points,
                      color,
                      size: Number(size) || 48,
                      visible: true,
                      opacity: 1,
                    };
              commit([...layers, layer]);
              setSelected(id);
            }}
          />
        ) : (
          <View style={s.empty}>
            <Text style={s.emptyIcon}>▧</Text>
            <Text style={s.title}>صفحة طويلة، تفاصيل كاملة</Text>
            <Text style={s.hint}>
              استورد صورة لتبدأ. استخدم إصبعين للتكبير، وأداة التنقل لتحريك
              الصفحة.
            </Text>
            {button("اختيار صورة", open, true)}
          </View>
        )}
        {!!busy && (
          <View style={s.loading}>
            <ActivityIndicator color="#60e0c2" />
            <Text style={s.hint}>{busy}</Text>
          </View>
        )}
      </View>
      <ScrollView
        style={{ maxHeight: 300, flexGrow: 0 }}
        keyboardShouldPersistTaps="handled"
      >
        <View style={s.row}>
          {button("تنقل", () => setTool("pan"), tool === "pan")}
          {button("فرشاة", () => setTool("brush"), tool === "brush")}
          {button(
            "نص",
            () => {
              setTool("text");
              setColor("#111111");
            },
            tool === "text",
          )}
          {button("طبقات", () => setPanel(!panel), panel)}
        </View>
        <View style={s.row}>
          {button(
            "تراجع",
            () => {
              setFuture((f) => [layers, ...f]);
              setLayers(past[past.length - 1]);
              setPast((p) => p.slice(0, -1));
            },
            false,
            !past.length,
          )}
          {button(
            "إعادة",
            () => {
              setPast((p) => [...p, layers]);
              setLayers(future[0]);
              setFuture((f) => f.slice(1));
            },
            false,
            !future.length,
          )}
          <Text style={s.label}>الحجم</Text>
          <TextInput
            accessibilityLabel="حجم الأداة بالبكسل الأصلي"
            style={s.smallInput}
            value={size}
            keyboardType="numeric"
            onChangeText={(v) => setSize(v.replace(/[^0-9]/g, "").slice(0, 4))}
          />
        </View>
        {tool !== "pan" && (
          <View style={s.row}>
            {colors.map((c) => (
              <Pressable
                key={c}
                accessibilityRole="button"
                accessibilityLabel={`اللون ${c}`}
                onPress={() => setColor(c)}
                style={[
                  s.swatch,
                  {
                    backgroundColor: c,
                    borderColor: color === c ? "#60e0c2" : "#434958",
                    borderWidth: color === c ? 3 : 1,
                  },
                ]}
              />
            ))}
          </View>
        )}
        {tool === "text" && (
          <View style={s.textPanel}>
            <TextInput
              accessibilityLabel="نص الطبقة"
              multiline
              style={s.input}
              value={text}
              onChangeText={setText}
            />
            <View style={s.row}>
              {fonts.map(([value, label]) =>
                button(label, () => setFont(value), font === value),
              )}
              {customFonts.map((value, i) =>
                button("خط " + (i + 1), () => setFont(value), font === value),
              )}
              {button("استيراد خط", importFont)}
              {button(
                "تطبيق",
                () =>
                  update({
                    text,
                    name: text.slice(0, 20),
                    font,
                    color,
                    size: Number(size) || 48,
                  }),
                false,
                chosen?.type !== "text",
              )}
            </View>
            <Text style={s.subtitle}>
              اضغط على الصورة لوضع النص عند يمين موضع اللمس.
            </Text>
          </View>
        )}
        {panel && (
          <View style={s.layers}>
            <Text style={s.label}>
              الطبقات · {layers.length} · الأعلى يظهر فوق غيره
            </Text>
            <ScrollView nestedScrollEnabled style={{ maxHeight: 120 }}>
              {[...layers].reverse().map((l) => (
                <View
                  key={l.id}
                  style={[s.layer, l.id === selected && s.selected]}
                >
                  <Pressable
                    accessibilityRole="button"
                    accessibilityLabel={`تحديد ${l.name}`}
                    style={{ flex: 1 }}
                    pointerEvents={busy ? "none" : "auto"}
                    onPress={() => {
                      setSelected(l.id);
                      setText(l.text || text);
                      setFont(l.font || font);
                      setSize(String(l.size));
                      setColor(l.color);
                    }}
                  >
                    <Text style={s.buttonText}>
                      {l.type === "text" ? "T" : "✎"} {l.name}
                    </Text>
                  </Pressable>
                  {button(l.visible ? "ظاهر" : "مخفي", () =>
                    commit(
                      layers.map((v) =>
                        v.id === l.id ? { ...v, visible: !v.visible } : v,
                      ),
                    ),
                  )}
                </View>
              ))}
              <Text style={s.subtitle}>الصورة الأصلية · مقفلة</Text>
            </ScrollView>
            {chosen && (
              <View style={s.row}>
                {button(
                  "تحريك النص",
                  () => setTool("move"),
                  tool === "move",
                  chosen.type !== "text",
                )}
                {button("رفع", () => {
                  const i = layers.findIndex((l) => l.id === selected);
                  if (i < layers.length - 1) {
                    const n = [...layers];
                    [n[i], n[i + 1]] = [n[i + 1], n[i]];
                    commit(n);
                  }
                })}
                {button("خفض", () => {
                  const i = layers.findIndex((l) => l.id === selected);
                  if (i > 0) {
                    const n = [...layers];
                    [n[i], n[i - 1]] = [n[i - 1], n[i]];
                    commit(n);
                  }
                })}
                {button(
                  "شفافية " + Math.round(chosen.opacity * 100) + "٪",
                  () =>
                    update({
                      opacity:
                        chosen.opacity <= 0.25 ? 1 : chosen.opacity - 0.25,
                    }),
                )}
                {button("حذف", () => {
                  commit(layers.filter((l) => l.id !== selected));
                  setSelected("");
                })}
              </View>
            )}
          </View>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}
const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: "#10141d", paddingTop: 30 },
  header: {
    padding: 16,
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
  },
  title: {
    fontSize: 22,
    fontWeight: "700",
    color: "#eef3ff",
    textAlign: "right",
  },
  subtitle: {
    fontSize: 11,
    color: "#96a2b6",
    textAlign: "right",
    paddingVertical: 4,
  },
  row: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    paddingHorizontal: 10,
    paddingVertical: 5,
    flexWrap: "wrap",
  },
  button: {
    backgroundColor: "#242c3b",
    paddingHorizontal: 10,
    paddingVertical: 9,
    borderRadius: 9,
  },
  active: {
    backgroundColor: "#236151",
    borderColor: "#60e0c2",
    borderWidth: 1,
  },
  buttonText: { color: "#eef3ff", fontSize: 12 },
  canvas: {
    flex: 1,
    minHeight: 150,
    margin: 10,
    borderRadius: 14,
    overflow: "hidden",
    borderWidth: 1,
    borderColor: "#30394b",
  },
  empty: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    padding: 25,
    gap: 12,
  },
  emptyIcon: { fontSize: 54, color: "#60e0c2" },
  hint: { color: "#b3bfd2", textAlign: "center", lineHeight: 24, padding: 12 },
  label: { color: "#aab7ce", fontSize: 12, textAlign: "right" },
  smallInput: {
    backgroundColor: "#242c3b",
    color: "#fff",
    borderRadius: 6,
    padding: 6,
    width: 60,
  },
  swatch: { height: 30, width: 30, borderRadius: 15 },
  textPanel: { paddingHorizontal: 10 },
  input: {
    backgroundColor: "#202838",
    color: "#fff",
    padding: 10,
    borderRadius: 8,
    textAlign: "right",
    maxHeight: 80,
  },
  layers: { padding: 10, backgroundColor: "#171d29" },
  layer: {
    flexDirection: "row",
    alignItems: "center",
    padding: 5,
    borderRadius: 7,
    marginVertical: 2,
  },
  selected: { backgroundColor: "#283b47" },
  loading: {
    position: "absolute",
    top: 0,
    right: 0,
    bottom: 0,
    left: 0,
    backgroundColor: "#10141ddd",
    alignItems: "center",
    justifyContent: "center",
  },
});
