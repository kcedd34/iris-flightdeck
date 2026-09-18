import { useEffect, useRef } from "react";

/**
 * The trailing time series of an instrument, on canvas (docs/design.md §5, spec FR-015).
 *
 * Canvas, never a declarative SVG chart library: at a one-second refresh with several series, SVG
 * degrades visibly, and this is the one technical decision of that document which, ignored, breaks
 * the signature moment.
 *
 * The line is the whole information: a 1.5px stroke, no axis, no grid, no legend, no fill, no
 * gradient. It slides with time; points do not animate in.
 */
export function Series({ points, max = 100, label, reducedMotion }: { points: number[]; max?: number; label: string; reducedMotion: boolean }) {
  const canvas = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    const element = canvas.current;
    if (!element) return;
    const context = element.getContext("2d");
    if (!context) return;
    const ratio = window.devicePixelRatio || 1;
    const width = element.clientWidth;
    const height = element.clientHeight;
    if (element.width !== width * ratio || element.height !== height * ratio) {
      element.width = width * ratio;
      element.height = height * ratio;
    }
    context.setTransform(ratio, 0, 0, ratio, 0, 0);
    context.clearRect(0, 0, width, height);
    if (points.length < 2) return;
    // The stroke colour comes from the token, read off the element so a theme change repaints with
    // the theme rather than with a colour baked into the script.
    const stroke = getComputedStyle(element).getPropertyValue("color").trim() || "currentColor";
    const step = width / (points.length - 1);
    const scale = (value: number) => height - 1.5 - (Math.max(0, Math.min(value, max)) / max) * (height - 3);
    context.beginPath();
    context.lineWidth = 1.5;
    context.lineJoin = "round";
    context.lineCap = "round";
    context.strokeStyle = stroke;
    points.forEach((value, index) => {
      const x = index * step;
      const y = scale(value);
      if (index === 0) context.moveTo(x, y);
      else context.lineTo(x, y);
    });
    context.stroke();
  }, [points, max, reducedMotion]);

  return <canvas ref={canvas} className="ins-series" role="img" aria-label={label} data-testid="instrument-series" />;
}
