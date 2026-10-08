import { test } from "node:test";
import assert from "node:assert/strict";
import { validateProject } from "../src/project.ts";
const project = () => ({
  version: 1,
  source: "file:///original.png",
  dimensions: { width: 2000, height: 50000 },
  layers: [
    {
      id: "1",
      type: "text",
      name: "ترجمة",
      visible: true,
      opacity: 1,
      color: "#111111",
      size: 48,
      text: "مرحبا",
      x: 300,
      y: 49000,
      font: "sans-serif",
    },
  ],
});
test("preserves long image coordinates and Arabic text on project reload", () => {
  const p = project();
  assert.deepEqual(validateProject(JSON.parse(JSON.stringify(p))), p);
});
test("rejects invalid source, dimensions, color, opacity and coordinates", () => {
  for (const mutate of [
    (p) => (p.source = "https://invalid"),
    (p) => (p.dimensions.width = 0),
    (p) => (p.layers[0].opacity = 2),
    (p) => (p.layers[0].color = "invalid"),
    (p) => (p.layers[0].x = Infinity),
    (p) => (p.layers[0].font = "unknown"),
  ]) {
    const p = project();
    mutate(p);
    assert.throws(() => validateProject(p));
  }
});
test("rejects duplicate layers and malformed stroke coordinates", () => {
  const p = project();
  p.layers.push({ ...p.layers[0] });
  assert.throws(() => validateProject(p));
  p.layers = [{ ...p.layers[0], type: "stroke", points: [[0, NaN]] }];
  assert.throws(() => validateProject(p));
});
