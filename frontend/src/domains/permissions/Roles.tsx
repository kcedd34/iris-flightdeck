import { ActionBar } from "../../pattern/ActionBar";
import { useDomainMutation } from "../../pattern/useDomainMutation";
import { RoleForm } from "./forms";
import { DomainSection } from "../../pattern/DomainSection";

/** UC05: roles, what they grant, who holds them. */
export function Roles() {
  const { run, error } = useDomainMutation();
  return (
    <DomainSection
      domain="permissions"
      entityType="role"
      label="Roles"
      createOperationId="PUT /v2/security/role"
      meta={(item) => String(item.object.Description ?? "")}
      renderForm={(form, done) =>
        form.mode === "create" ? (
          <RoleForm mode="create" original={{ Resources: [], GrantedRoles: [] }} onDone={done} />
        ) : (
          <RoleForm mode="edit" keys={form.detail.keys} original={form.detail.object} onDone={done} />
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
              { operationId: "PUT /v2/security/role", label: "Edit", mutating: true, onActivate: () => openForm({ mode: "edit", detail }) },
              {
                operationId: "DELETE /v2/security/role",
                label: "Delete",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "DELETE /v2/security/role", keys: detail.keys, noun: "role" });
                },
              },
            ]}
          />
        </>
      )}
      empty={{ title: "No role matches", cause: "The filters exclude every role this instance has.", nextAction: "Clear the filters or the search text." }}
      emptyUnfiltered={{ title: "No role", cause: "This instance defines no role.", nextAction: "Create one with New." }}
    />
  );
}
