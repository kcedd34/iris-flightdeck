import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from "react";
import { getTheme, setTheme as persistTheme, type Theme } from "../prefs/storage";

interface ThemeContextValue {
  theme: Theme;
  toggle: () => void;
}

const ThemeContext = createContext<ThemeContextValue | null>(null);

function osTheme(): Theme {
  return window.matchMedia?.("(prefers-color-scheme: light)").matches ? "light" : "dark";
}

/**
 * Initial theme follows the OS; an explicit choice is remembered per IRIS user (FR-037).
 * Switching swaps the variable set on the root element, nothing else.
 */
export function ThemeProvider({ username, children }: { username: string | null; children: ReactNode }) {
  const [explicit, setExplicit] = useState<Theme | null>(null);
  const [system, setSystem] = useState<Theme>(osTheme);

  useEffect(() => {
    setExplicit(username ? getTheme(username) : null);
  }, [username]);

  useEffect(() => {
    const media = window.matchMedia?.("(prefers-color-scheme: light)");
    if (!media) return;
    const onChange = () => setSystem(osTheme());
    media.addEventListener("change", onChange);
    return () => media.removeEventListener("change", onChange);
  }, []);

  const theme = explicit ?? system;

  useEffect(() => {
    document.documentElement.setAttribute("data-theme", theme);
  }, [theme]);

  const toggle = useCallback(() => {
    const next: Theme = theme === "light" ? "dark" : "light";
    setExplicit(next);
    if (username) persistTheme(username, next);
  }, [theme, username]);

  return <ThemeContext.Provider value={{ theme, toggle }}>{children}</ThemeContext.Provider>;
}

export function useTheme(): ThemeContextValue {
  const value = useContext(ThemeContext);
  if (!value) throw new Error("useTheme must be used inside ThemeProvider");
  return value;
}
