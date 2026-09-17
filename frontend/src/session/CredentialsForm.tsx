import { useState, type FormEvent } from "react";
import { ApiError, MESSAGES } from "../api/client";
import "./session.css";

interface Props {
  initialUsername?: string;
  submitLabel: string;
  onSubmit: (username: string, password: string) => Promise<void>;
  autoFocusPassword?: boolean;
}

function describe(error: unknown): { message: string; detail: string | null } {
  if (error instanceof ApiError) {
    switch (error.code) {
      case "INVALID_CREDENTIALS":
        return { message: MESSAGES.invalidCredentials, detail: null };
      case "NO_ADMIN_PRIVILEGE":
        return { message: error.message, detail: null };
      case "UNSUPPORTED_VERSION":
        // The server names the minimum version (message 8); only an instance without any SysAdmin API is refused.
        return { message: error.message, detail: error.detectedVersion ? `Detected: ${error.detectedVersion}` : null };
      default:
        // IRIS text is shown verbatim, never replaced by generic portal text (design §7).
        return { message: error.message, detail: error.raw };
    }
  }
  return { message: "The server could not be reached.", detail: error instanceof Error ? error.message : null };
}

/** Username and password fields. The password lives in component state only until submit. */
export function CredentialsForm({ initialUsername = "", submitLabel, onSubmit, autoFocusPassword }: Props) {
  const [username, setUsername] = useState(initialUsername);
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<{ message: string; detail: string | null } | null>(null);

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!username || !password || busy) return;
    setBusy(true);
    setError(null);
    const typed = password;
    setPassword("");
    try {
      await onSubmit(username, typed);
    } catch (e) {
      setError(describe(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <form className="credentials" onSubmit={submit} noValidate>
      <label className="credentials-field">
        <span>Username</span>
        <input
          className="field-input mono"
          name="username"
          autoComplete="username"
          value={username}
          autoFocus={!autoFocusPassword}
          onChange={(e) => setUsername(e.target.value)}
        />
      </label>
      <label className="credentials-field">
        <span>Password</span>
        <input
          className="field-input"
          name="password"
          type="password"
          autoComplete="current-password"
          value={password}
          autoFocus={autoFocusPassword}
          onChange={(e) => setPassword(e.target.value)}
        />
      </label>
      {error && (
        <div className="credentials-error" role="alert">
          <svg className="glyph" viewBox="0 0 10 10" fill="currentColor" aria-hidden="true">
            <path d="M5 0l5 9H0z" />
          </svg>
          <div>
            <div>{error.message}</div>
            {error.detail && <div className="credentials-detail mono">{error.detail}</div>}
          </div>
        </div>
      )}
      <button className="btn btn-primary credentials-submit" type="submit" disabled={busy || !username || !password}>
        {busy ? "Signing in" : submitLabel}
      </button>
    </form>
  );
}
