import { useTheme } from "../theme/ThemeProvider";

const SUN_RAYS = '<circle cx="8" cy="8" r="3.2"/><path d="M8 1v1.6M8 13.4V15M15 8h-1.6M2.6 8H1M12.9 3.1l-1.1 1.1M4.2 11.8l-1.1 1.1M12.9 12.9l-1.1-1.1M4.2 4.2L3.1 3.1"/>';
const MOON = '<path d="M13.2 9.8A5.8 5.8 0 0 1 6.2 2.8a5.8 5.8 0 1 0 7 7z"/>';

export function ThemeToggle() {
  const { theme, toggle } = useTheme();
  const next = theme === "light" ? "dark" : "light";
  return (
    <button className="mode" type="button" onClick={toggle} aria-label={`Switch to ${next} theme`}>
      <svg
        width="13"
        height="13"
        viewBox="0 0 16 16"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.3"
        aria-hidden="true"
        dangerouslySetInnerHTML={{ __html: theme === "light" ? MOON : SUN_RAYS }}
      />
      <span className="mode-theme-label">{next === "light" ? "Light" : "Dark"}</span>
    </button>
  );
}
