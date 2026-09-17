import { CredentialsForm } from "./CredentialsForm";
import { useSession } from "./SessionProvider";
import "./session.css";

export function SignIn() {
  const { signIn } = useSession();
  return (
    <main className="signin">
      <div className="signin-panel">
        <h1 className="signin-brand">FlightDeck</h1>
        <p className="signin-sub">Sign in with your InterSystems IRIS account. FlightDeck stores no credentials.</p>
        <CredentialsForm submitLabel="Sign in" onSubmit={signIn} />
      </div>
    </main>
  );
}
