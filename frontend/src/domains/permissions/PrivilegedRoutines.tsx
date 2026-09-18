import { ActionBar } from "../../pattern/ActionBar";
import { useDomainMutation } from "../../pattern/useDomainMutation";
import { PrivilegedRoutineForm } from "./forms";
import { DomainSection } from "../../pattern/DomainSection";

/** UC05: routine applications that run with a role, part of the same chain. */
export function PrivilegedRoutines() {
  const { run, error } = useDomainMutation();
  return (
    <DomainSection
      domain="permissions"
      entityType="privileged-routine"
      label="Privileged routines"
      createOperationId="PUT /v2/security/privileged-routine"
      meta={(item) => String(item.object.Namespace ?? "")}
      renderForm={(form, done) =>
        form.mode === "create" ? (
          <PrivilegedRoutineForm mode="create" original={{ Enabled: true, Routines: [] }} onDone={done} />
        ) : (
          <PrivilegedRoutineForm mode="edit" keys={form.detail.keys} original={form.detail.object} onDone={done} />
        )
      }
      actions={(detail, openForm) => (
        <>
          {error && (
            <div className="dlist-error" role="alert" data-testid="action-error">
              {error}
            </div>
          )}
          <ActionBar
            capabilities={detail.availableMutations}
            actions={[
              { operationId: "PUT /v2/security/privileged-routine", label: "Edit", mutating: true, onActivate: () => openForm({ mode: "edit", detail }) },
              {
                operationId: "DELETE /v2/security/privileged-routine",
                label: "Delete",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "DELETE /v2/security/privileged-routine", keys: detail.keys, noun: "privileged routine application" });
                },
              },
            ]}
          />
        </>
      )}
      empty={{ title: "No privileged routine application matches", cause: "The filters exclude every application this instance has.", nextAction: "Clear the filters or the search text." }}
    />
  );
}
