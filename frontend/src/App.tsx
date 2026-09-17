import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter } from "react-router-dom";
import { MutationProvider } from "./mutation/useMutation";
import { CommandPalette } from "./palette/CommandPalette";
import { AppRoutes } from "./routes";
import { ReauthOverlay } from "./session/ReauthOverlay";
import { SessionProvider, useSession } from "./session/SessionProvider";
import { SignIn } from "./session/SignIn";
import { Glareshield } from "./shell/Glareshield";
import { Rail } from "./shell/Rail";
import { ThemeProvider } from "./theme/ThemeProvider";
import "./shell/shell.css";

const queryClient = new QueryClient({
  defaultOptions: {
    queries: { retry: false, refetchOnWindowFocus: false, staleTime: 5_000 },
  },
});

function Shell() {
  const { state, session } = useSession();
  if (state === "loading") return null;
  if (state === "signed_out" || !session) return <SignIn />;
  return (
    <MutationProvider>
      <div className="app">
        <Glareshield />
        <div className="shell">
          <Rail />
          <main className="work">
            <AppRoutes />
          </main>
        </div>
        <CommandPalette />
        <ReauthOverlay />
      </div>
    </MutationProvider>
  );
}

function Themed() {
  const { session } = useSession();
  return (
    <ThemeProvider username={session?.username ?? null}>
      <Shell />
    </ThemeProvider>
  );
}

export function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter basename="/flightdeck" future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
        <SessionProvider>
          <Themed />
        </SessionProvider>
      </BrowserRouter>
    </QueryClientProvider>
  );
}
