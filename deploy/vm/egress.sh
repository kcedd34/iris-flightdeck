#!/usr/bin/env bash
# Runtime egress restriction for the demo container (feature 007, items 17 to 19).
#
# Why the container and not the VM: the VM needs the internet — to pull the image, to update itself
# and to accept SSH. What must not happen is someone who gets administrative control of IRIS through
# the public portal using it to reach out and attack a third party. That is the one risk that travels
# beyond this disposable machine, and it arrives as an abuse notice.
#
# Why it cannot be permanent: the hourly rebuild pulls and installs. The rule is removed before the
# rebuild and applied again once the instance is answering, which is what `apply` and `clear` are for.
#
# Established connections are returned before the drop, so the proxy on the host keeps talking to the
# published port; only NEW outbound connections from the container are refused.
set -euo pipefail

CHAIN=DOCKER-USER
NETWORK="${FD_DEMO_NETWORK:-vm_default}"
MARK="flightdeck-demo-egress"

subnet() {
  docker network inspect "$NETWORK" -f '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null
}

clear_rules() {
  # Delete every rule carrying our comment, however many there are, without touching anything else.
  while iptables -S "$CHAIN" 2>/dev/null | grep -q -- "--comment \"$MARK\""; do
    local rule
    rule=$(iptables -S "$CHAIN" | grep -m1 -- "--comment \"$MARK\"" | sed 's/^-A /-D /')
    # shellcheck disable=SC2086
    iptables $rule
  done
  echo "egress: rules cleared"
}

apply_rules() {
  local net
  net=$(subnet)
  if [ -z "$net" ]; then
    echo "egress: network $NETWORK has no subnet yet; is the stack up?" >&2
    exit 1
  fi
  clear_rules
  # Inserted in reverse order: the DROP goes in first and the exemptions are pushed above it.
  iptables -I "$CHAIN" 1 -s "$net" -j DROP -m comment --comment "$MARK"
  iptables -I "$CHAIN" 1 -s "$net" -d "$net" -j RETURN -m comment --comment "$MARK"
  iptables -I "$CHAIN" 1 -s "$net" -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN -m comment --comment "$MARK"
  echo "egress: applied to $net"
}

case "${1:-}" in
  apply) apply_rules ;;
  clear) clear_rules ;;
  show)  iptables -S "$CHAIN" | grep -- "$MARK" || echo "egress: no rules" ;;
  *) echo "usage: $0 {apply|clear|show}" >&2; exit 2 ;;
esac
