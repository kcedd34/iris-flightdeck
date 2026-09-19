import { useState, type FormEvent } from "react";
import { ApiError, MESSAGES } from "../api/client";
import { readDemoNotice } from "./demoNotice";
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
      <DemoCredentials />
    </form>
  );
}

/**
 * The published credentials of the online demo, and what is true about that instance.
 *
 * Renders only where the server injected the notice, which is the demo deployment and nothing else.
 * On any normal install this is absent and nothing is shown — nobody who installs FlightDeck at home
 * finds a password printed under the sign-in form.
 */
function DemoCredentials() {
  const notice = readDemoNotice();
  if (!notice) return null;
  return (
    <div className="credentials-demo" data-testid="demo-credentials">
      <div className="credentials-demo-h">This is the public demo.</div>
      {/* Said plainly, because it cannot be told apart from the outside: the portal is driving a real
          instance, and every operation is performed against it. That is also the reason the instance
          is thrown away on a timer. */}
      <p className="credentials-demo-real" data-testid="demo-real-instance">
        {`It is talking to a real InterSystems IRIS Community instance, not a simulator: every
        operation you run is executed against the platform, which is why the instance is rebuilt
        ${notice.reset}.`}
      </p>
      <div className="credentials-demo-account">
        <dl className="credentials-demo-pair">
          <dt>User</dt>
          <dd className="mono">{notice.username}</dd>
          <dt>Password</dt>
          <dd className="mono">{notice.password}</dd>
        </dl>
        <p className="credentials-demo-shows">Full administrator: every domain and every operation this IRIS offers.</p>
      </div>
      {notice.reduced && (
        <div className="credentials-demo-account" data-testid="demo-credentials-reduced">
          <dl className="credentials-demo-pair">
            <dt>User</dt>
            <dd className="mono">{notice.reduced.username}</dd>
            <dt>Password</dt>
            <dd className="mono">{notice.reduced.password}</dd>
          </dl>
          <p className="credentials-demo-shows">
            Reduced privileges: the same portal with most controls disabled, each naming the privilege it needs, and
            whole sections it cannot open.
          </p>
        </div>
      )}
      <p className="credentials-demo-note">
        {`Everything you change here is discarded: the instance is rebuilt ${notice.reset}, and it is
        shared with whoever else is looking. The connection is plain HTTP, so treat anything you type
        as public — these credentials are published, and no other account of yours belongs here.`}
      </p>
    </div>
  );
}
