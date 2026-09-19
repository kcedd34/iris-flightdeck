/**
 * The public-demo notice, read from the meta tag the server injects (feature 007).
 *
 * It exists for one deployment: the published online demo, whose instance is thrown away and rebuilt
 * every hour and whose credentials are meant to be read by anyone who opens it. A normal install has
 * no such tag, so this answers null and nothing renders — which is the property that matters, and the
 * one the tests check on both sides.
 *
 * The values are supplied by the operator through the environment, never read from the instance's
 * security tables, so nothing here reaches the wallet, the mutation layer or the session trail.
 */
export interface DemoAccount {
  username: string;
  password: string;
}

export interface DemoNotice extends DemoAccount {
  /** How often the instance is rebuilt, in the operator's own words. */
  reset: string;
  /**
   * The reduced account, when the deployment declares one. It exists so that the capability map is
   * visible: an administrator with every privilege sees nothing disabled, which is the one state in
   * which the feature cannot be seen at all.
   */
  reduced: DemoAccount | null;
}

export function readDemoNotice(): DemoNotice | null {
  if (typeof document === "undefined") return null;
  const meta = document.querySelector('meta[name="fd-demo-notice"]');
  const content = meta?.getAttribute("content");
  if (!content) return null;
  const [username, password, reset, reducedUser, reducedPassword] = content.split("\t");
  if (!username || !password) return null;
  return {
    username,
    password,
    reset: reset || "regularly",
    reduced: reducedUser && reducedPassword ? { username: reducedUser, password: reducedPassword } : null,
  };
}
