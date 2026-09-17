import { lazy, Suspense } from "react";
import { Navigate, Route, Routes, useParams } from "react-router-dom";
import { SECTIONS } from "./domains/registry";
import { Home } from "./home/Home";
import { findDomain, findSection } from "./shell/domains";
import { EmptyState } from "./shell/EmptyState";
import { PlaceholderSection } from "./shell/PlaceholderSection";
import { WorkHeader } from "./shell/WorkHeader";

// Compiled only in fixtures mode; the production bundle does not contain it (FR-017a).
const ReauthFixture = import.meta.env.MODE === "fixtures" ? lazy(() => import("./fixtures/ReauthFixture")) : null;
const PatternCatalog = import.meta.env.MODE === "fixtures" ? lazy(() => import("./fixtures/PatternCatalog")) : null;

function DomainRedirect() {
  const { domain } = useParams();
  const d = findDomain(domain);
  if (!d) return <NotFound />;
  return <Navigate to={`/${d.id}/${d.sections[0]!.id}`} replace />;
}

function SectionRoute() {
  const params = useParams();
  const domain = findDomain(params.domain);
  const section = domain && findSection(domain, params.section);
  if (!domain || !section) return <NotFound />;
  const title = domain.sections.length > 1 ? domain.label : section.label;
  return (
    <>
      <WorkHeader title={title} domain={domain} activeSection={section.id} />
      {(() => {
        const Built = SECTIONS[`${domain.id}/${section.id}`];
        return Built ? <Built key={`${domain.id}/${section.id}`} /> : <PlaceholderSection key={`${domain.id}/${section.id}`} domain={domain} section={section} />;
      })()}
    </>
  );
}

function NotFound() {
  return (
    <>
      <WorkHeader title="Not found" />
      <div className="view">
        <EmptyState title="This page does not exist." cause="The address does not match any FlightDeck screen." nextAction="Use the rail or press Ctrl+K." />
      </div>
    </>
  );
}

export function AppRoutes() {
  return (
    <Routes>
      <Route
        path="/"
        element={
          <>
            <WorkHeader title="Home" />
            <Home />
          </>
        }
      />
      {ReauthFixture && (
        <Route
          path="/__fixtures__/reauth"
          element={
            <Suspense fallback={null}>
              <ReauthFixture />
            </Suspense>
          }
        />
      )}
      {PatternCatalog && (
        <Route
          path="/__fixtures__/pattern"
          element={
            <Suspense fallback={null}>
              <PatternCatalog />
            </Suspense>
          }
        />
      )}
      <Route path="/:domain" element={<DomainRedirect />} />
      <Route path="/:domain/:section" element={<SectionRoute />} />
      <Route path="*" element={<NotFound />} />
    </Routes>
  );
}
