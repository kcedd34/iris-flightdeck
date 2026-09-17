import type { ComponentType } from "react";
import { Services as RestServices } from "./rest-apis/Services";
import { PercentClassAccess } from "./web-apps/PercentClassAccess";
import { WebApplications } from "./web-apps/WebApplications";

/** Sections built on the domain pattern. Sections not listed keep the feature 001 empty state. */
export const SECTIONS: Record<string, ComponentType> = {
  "web-apps/web-applications": WebApplications,
  "web-apps/percent-class-access": PercentClassAccess,
  "web-apps/rest-apis": RestServices,
};
