import { useSession } from "../session/SessionProvider";
import { SafeModeIndicator } from "./SafeModeIndicator";
import { ThemeToggle } from "./ThemeToggle";
import { Vitals } from "./Vitals";

function productLabel(product: string): string {
  if (product === "irisforhealth") return "IRIS for Health";
  if (product === "iris") return "IRIS";
  return product;
}

/** 44px glareshield: identity, vitals, theme, safe mode, user (design §4, FR-029). */
export function Glareshield() {
  const { session, signOut } = useSession();
  if (!session) return null;
  const { instance } = session;
  return (
    <header className="glare" data-testid="glareshield">
      <span className="glare-brand">FlightDeck</span>
      <span className="glare-inst mono" data-testid="instance-identity">
        {productLabel(instance.product)} {instance.version}
        {instance.edition === "Community" ? " CE" : ""} · {instance.namespace}
      </span>
      <Vitals />
      <ThemeToggle />
      <SafeModeIndicator />
      <span className="glare-user mono">{session.username}</span>
      <button className="btn" type="button" onClick={() => void signOut()}>
        Sign out
      </button>
    </header>
  );
}
