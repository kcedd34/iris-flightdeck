import { ActionBar } from "../../pattern/ActionBar";
import { SingletonSection } from "../../pattern/SingletonSection";

/**
 * UC06 encryption: readable here, changed in the platform's own management portal.
 * <p>FlightDeck declines the eight write operations of this family (spec FR-020). Each one is shown
 * as a control, disabled, with the reason and the native path beside it, because a control that is
 * absent reads as a missing feature, while a control that states why it is refused is a decision the
 * evaluator can judge. The decision is recorded in the capability map, in the coverage document and
 * in the project's gap list; nothing about it is inferred in this screen.
 */
export function Encryption() {
  return (
    <SingletonSection
      entity={{ domain: "security", entityType: "encryption-settings", keys: {} }}
      label="Encryption"
      actions={(detail) => (
        <>
          <section className="sect" aria-label="Why these operations are not offered">
            <div className="sect-h">FlightDeck reads encryption; it does not change it</div>
            <p className="lgroup-reason" data-testid="encryption-policy-note">
              Creating an encryption key file, administering one, activating or deactivating a key, and changing these settings can make an
              instance's data permanently unreadable, with no recovery through this portal. FlightDeck declines those operations on every
              version and names where to perform them instead. The settings above are what the official API reports today.
            </p>
          </section>
          <ActionBar
            capabilities={detail.availableMutations}
            actions={[
              { operationId: "PUT /v2/security/encryption/settings", label: "Edit settings", mutating: true, onActivate: () => undefined },
              { operationId: "POST /v2/security/encryption/file", label: "Create key file", mutating: true, onActivate: () => undefined },
              { operationId: "POST /v2/security/encryption/file/activate", label: "Activate key", mutating: true, onActivate: () => undefined },
              { operationId: "POST /v2/security/encryption/key/deactivate", label: "Deactivate key", mutating: true, onActivate: () => undefined },
            ]}
          />
        </>
      )}
    />
  );
}
