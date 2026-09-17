import * as Dialog from "@radix-ui/react-dialog";
import { CredentialsForm } from "./CredentialsForm";
import { useSession } from "./SessionProvider";
import "./session.css";

/**
 * Shown above the current screen when IRIS reports the session expired (FR-016, FR-017).
 * The route, selection and typed input stay mounted underneath; nothing navigates.
 */
export function ReauthOverlay() {
  const { state, session, reauthenticate, signOut } = useSession();
  return (
    <Dialog.Root open={state === "expired"}>
      <Dialog.Portal>
        <Dialog.Overlay className="scrim" />
        <Dialog.Content
          className="float reauth"
          onEscapeKeyDown={(e) => e.preventDefault()}
          onPointerDownOutside={(e) => e.preventDefault()}
          aria-describedby="reauth-desc"
        >
          <Dialog.Title className="reauth-title">Your session expired</Dialog.Title>
          <p id="reauth-desc" className="reauth-desc">
            Sign in again to continue where you were. Your screen and typed input are kept.
          </p>
          <CredentialsForm
            initialUsername={session?.username ?? ""}
            submitLabel="Continue"
            autoFocusPassword={Boolean(session?.username)}
            onSubmit={reauthenticate}
          />
          <button className="btn reauth-signout" type="button" onClick={() => void signOut()}>
            Sign out instead
          </button>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}
