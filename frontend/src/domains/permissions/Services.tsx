import type { EntityListItem } from "../../api/types";
import { ActionBar } from "../../pattern/ActionBar";
import { ServiceForm } from "./forms";
import { DomainSection } from "../../pattern/DomainSection";

/** UC05: the platform's access services. They are edited, never created. */
export function Services() {
  return (
    <DomainSection
      domain="permissions"
      entityType="service"
      label="Services"
      stateFilter={{
        label: "State",
        options: [
          { value: "", label: "Enabled and disabled" },
          { value: "enabled", label: "Enabled" },
          { value: "disabled", label: "Disabled" },
        ],
        matches: (item: EntityListItem, value: string) => (value === "enabled" ? Boolean(item.object.Enabled) : !item.object.Enabled),
      }}
      meta={(item) => String(item.object.Description ?? "")}
      renderForm={(form, done) => (form.mode === "create" ? null : <ServiceForm mode="edit" keys={form.detail.keys} original={form.detail.object} onDone={done} />)}
      actions={(detail, openForm) => (
        <ActionBar
          capabilities={detail.availableMutations}
          actions={[{ operationId: "PUT /v2/security/service", label: "Edit", mutating: true, onActivate: () => openForm({ mode: "edit", detail }) }]}
        />
      )}
      empty={{ title: "No service matches", cause: "The filters exclude every service this instance has.", nextAction: "Clear the filters or the search text." }}
    />
  );
}
