import { ActionBar } from "../../pattern/ActionBar";
import { useDomainMutation } from "../../pattern/useDomainMutation";
import { ResourceForm } from "./forms";
import { DomainSection } from "../../pattern/DomainSection";

/** UC05: resources, the roles that grant them and the objects they protect. */
export function Resources() {
  const { run, error } = useDomainMutation();
  return (
    <DomainSection
      domain="permissions"
      entityType="resource"
      label="Resources"
      createOperationId="PUT /v2/security/resource"
      meta={(item) => String(item.object.ResourceType ?? "")}
      renderForm={(form, done) =>
        form.mode === "create" ? (
          <ResourceForm mode="create" original={{ PublicPermission: "" }} onDone={done} />
        ) : (
          <ResourceForm mode="edit" keys={form.detail.keys} original={form.detail.object} onDone={done} />
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
              { operationId: "PUT /v2/security/resource", label: "Edit", mutating: true, onActivate: () => openForm({ mode: "edit", detail }) },
              {
                operationId: "DELETE /v2/security/resource",
                label: "Delete",
                mutating: true,
                // The platform itself refuses to delete some resources, and says so in the list.
                refusedByObject: detail.object.AllowDelete === false ? "The platform does not allow deleting this resource." : null,
                onActivate: async () => {
                  await run({ operationId: "DELETE /v2/security/resource", keys: detail.keys, noun: "resource" });
                },
              },
            ]}
          />
        </>
      )}
      empty={{ title: "No resource matches", cause: "The filters exclude every resource this instance has.", nextAction: "Clear the filters or the search text." }}
    />
  );
}
