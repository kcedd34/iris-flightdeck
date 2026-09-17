import * as Tooltip from "@radix-ui/react-tooltip";
import { Link, useLocation } from "react-router-dom";
import { DOMAINS } from "./domains";
import { Icon } from "./Icon";

/** 56px icon-only rail with exactly six destinations (design §4, FR-032). */
export function Rail() {
  const { pathname } = useLocation();
  const active = pathname.split("/")[1];
  return (
    <Tooltip.Provider delayDuration={150}>
      <nav className="rail" aria-label="Domains" data-testid="rail">
        {DOMAINS.map((d) => (
          <Tooltip.Root key={d.id}>
            <Tooltip.Trigger asChild>
              <Link
                className="rail-item"
                to={`/${d.id}`}
                aria-label={d.label}
                aria-current={active === d.id ? "page" : undefined}
              >
                <Icon paths={d.icon} />
              </Link>
            </Tooltip.Trigger>
            <Tooltip.Portal>
              <Tooltip.Content className="tip" side="right" sideOffset={8}>
                {d.label}
              </Tooltip.Content>
            </Tooltip.Portal>
          </Tooltip.Root>
        ))}
      </nav>
    </Tooltip.Provider>
  );
}
