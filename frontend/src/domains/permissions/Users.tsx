import type { EntityListItem } from "../../api/types";
import { ActionBar } from "../../pattern/ActionBar";
import { useDomainMutation } from "../../pattern/useDomainMutation";
import { PasswordForm, UserForm } from "./forms";
import { DomainSection } from "../../pattern/DomainSection";

/** UC05: the accounts of the instance, with the chain of roles each one holds. */
export function Users() {
  const { run, error } = useDomainMutation();
  return (
    <DomainSection
      domain="permissions"
      entityType="user"
      label="Users"
      createOperationId="POST /v2/security/user"
      stateFilter={{
        label: "State",
        options: [
          { value: "", label: "Enabled and disabled" },
          { value: "enabled", label: "Enabled" },
          { value: "disabled", label: "Disabled" },
        ],
        matches: (item: EntityListItem, value: string) => (value === "enabled" ? Boolean(item.object.Enabled) : !item.object.Enabled),
      }}
      meta={(item) => String(item.object.FullName ?? "")}
      renderForm={(form, done) =>
        form.mode === "create" ? (
          <UserForm mode="create" original={{ Enabled: true, ChangePassword: false }} onDone={done} />
        ) : form.mode === "password" ? (
          <PasswordForm mode="edit" keys={form.detail.keys} original={{}} onDone={done} />
        ) : (
          <UserForm mode="edit" keys={form.detail.keys} original={form.detail.object} onDone={done} />
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
              { operationId: "PUT /v2/security/user", label: "Edit", mutating: true, onActivate: () => openForm({ mode: "edit", detail }) },
              { operationId: "POST /v2/security/user/password", label: "Set password", mutating: true, onActivate: () => openForm({ mode: "password", detail }) },
              {
                operationId: "DELETE /v2/security/user",
                label: "Delete",
                mutating: true,
                onActivate: async () => {
                  await run({ operationId: "DELETE /v2/security/user", keys: detail.keys, noun: "user" });
                },
              },
            ]}
          />
        </>
      )}
      empty={{ title: "No user matches", cause: "The filters exclude every account this instance has.", nextAction: "Clear the filters or the search text." }}
    />
  );
}
