import { Link } from "react-router-dom";
import { ActionBar } from "../../pattern/ActionBar";
import { DomainSection } from "../../pattern/DomainSection";
import { useDomainMutation } from "../../pattern/useDomainMutation";

/**
 * UC09: what the instance records.
 *
 * These definitions live here, and the audit state and records live in the security domain. The
 * split is by the nature of the object, not by the verb: state and records are data, and the
 * definitions of what is captured are configuration of an investigation, which belongs where the
 * investigating happens (feature 005 spec FR-031a). Both sections say so and link to each other.
 */
export function AuditEvents() {
  const { run, error } = useDomainMutation();
  return (
    <DomainSection
      domain="logs"
      entityType="audit-event"
      label="Audit events"
      createOperationId="PUT /v2/security/audit/event"
      meta={(item) => `${String(item.object.Source ?? "")}/${String(item.object.Type ?? "")}`}
      actions={(detail) => (
        <>
          {error && (
            <div className="dlist-error" role="alert" data-testid="action-error">
              {error}
            </div>
          )}
          <p className="logs-note" data-testid="audit-split-note">
            These are the definitions of what this instance records. Whether auditing is running at
            all, and the records themselves, are in{" "}
            <Link to="/security/auditing">Security and secrets, Auditing</Link>.
          </p>
          <ActionBar
            capabilities={detail.availableMutations}
            actions={[
              {
                operationId: "DELETE /v2/security/audit/event",
                label: "Delete",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "DELETE /v2/security/audit/event", keys: detail.keys, noun: "audit event" });
                },
              },
            ]}
          />
        </>
      )}
      empty={{ title: "No audit event matches", cause: "The filters exclude every audit event this instance defines.", nextAction: "Clear the filters or the search text." }}
    />
  );
}
