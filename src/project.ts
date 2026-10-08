import type { Layer } from "../modules/long-image";
export type Project = {
  version: 1;
  source: string;
  dimensions: { width: number; height: number };
  layers: Layer[];
};
export function validateProject(value: unknown): Project {
  const p = value as Project;
  if (
    !p ||
    p.version !== 1 ||
    typeof p.source !== "string" ||
    !p.source.startsWith("file:") ||
    !Number.isInteger(p.dimensions?.width) ||
    !Number.isInteger(p.dimensions?.height) ||
    p.dimensions.width < 1 ||
    p.dimensions.height < 1 ||
    !Array.isArray(p.layers)
  )
    throw Error("ملف مشروع غير صالح");
  const ids = new Set<string>();
  for (const l of p.layers) {
    if (
      !l ||
      typeof l.id !== "string" ||
      ids.has(l.id) ||
      typeof l.name !== "string" ||
      typeof l.visible !== "boolean" ||
      !Number.isFinite(l.opacity) ||
      l.opacity < 0 ||
      l.opacity > 1 ||
      !/^#[0-9a-f]{6}$/i.test(l.color) ||
      !Number.isFinite(l.size) ||
      l.size <= 0 ||
      l.size > 9999
    )
      throw Error("طبقة غير صالحة");
    ids.add(l.id);
    if (l.type === "text") {
      if (
        typeof l.text !== "string" ||
        !Number.isFinite(l.x) ||
        !Number.isFinite(l.y) ||
        (!["sans-serif", "serif", "monospace"].includes(l.font || "") &&
          !/^file:\/\/.+\.(ttf|otf)$/i.test(l.font || ""))
      )
        throw Error("نص غير صالح");
    } else if (l.type === "stroke") {
      if (
        !Array.isArray(l.points) ||
        !l.points.length ||
        l.points.some(
          (v) =>
            !Array.isArray(v) ||
            v.length !== 2 ||
            v.some((n) => !Number.isFinite(n)),
        )
      )
        throw Error("رسم غير صالح");
    } else throw Error("نوع طبقة غير مدعوم");
  }
  return p;
}
