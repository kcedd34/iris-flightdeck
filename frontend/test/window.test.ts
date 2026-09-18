import { describe, expect, it } from "vitest";
import { createWindow } from "../src/pattern/instruments/window";

describe("the instrument sliding window", () => {
  it("keeps the last N readings and drops the oldest first", () => {
    const window = createWindow(3);
    for (const value of [1, 2, 3, 4, 5]) window.push("cpu", value);
    expect(window.series("cpu")).toEqual([3, 4, 5]);
  });

  it("ignores a reading the instance did not report, rather than charting a zero", () => {
    const window = createWindow(5);
    window.push("cpu", 10);
    window.push("cpu", null);
    window.push("cpu", Number.NaN);
    window.push("cpu", 20);
    expect(window.series("cpu")).toEqual([10, 20]);
  });

  it("stays bounded over ten minutes at one reading a second (spec FR-018, SC-003)", () => {
    const window = createWindow(60);
    for (let i = 0; i < 600; i++) window.push("cpu", i);
    expect(window.series("cpu")).toHaveLength(60);
    expect(window.series("cpu")[0]).toBe(540);
  });

  it("keeps each instrument's series apart", () => {
    const window = createWindow(2);
    window.push("cpu", 1);
    window.push("memory", 9);
    expect(window.series("cpu")).toEqual([1]);
    expect(window.series("memory")).toEqual([9]);
    expect(window.series("disk")).toEqual([]);
  });
});
