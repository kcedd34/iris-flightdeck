# FlightDeck for InterSystems IRIS: one image, built and run by `docker compose up -d`.
# IRIS for Health: IRIS_IMAGE=intersystemsdc/irishealth-community:2026.2-zpm docker compose up -d --build

ARG IRIS_IMAGE=intersystemsdc/iris-community:2026.2-zpm

# ── IRIS ───────────────────────────────────────────────────────────────────────────────────────
FROM ${IRIS_IMAGE}

USER root
RUN mkdir -p /opt/flightdeck /durable && chown -R irisowner:irisowner /opt/flightdeck /durable
USER irisowner

COPY --chown=irisowner:irisowner module.xml /opt/flightdeck/module.xml
COPY --chown=irisowner:irisowner backend /opt/flightdeck/backend
COPY --chown=irisowner:irisowner docker/first-start.sh /opt/flightdeck/docker/first-start.sh
# Prebuilt, committed web assets (research R13): no Node or npm registry access during install.
COPY --chown=irisowner:irisowner frontend/dist /opt/flightdeck/frontend/dist
RUN chmod +x /opt/flightdeck/docker/first-start.sh

# Durable %SYS in the named volume mounted at /durable (never a bind mount from the host).
ENV ISC_DATA_DIRECTORY=/durable/iris

EXPOSE 52773

# The stock entrypoint's post-start hook crashes and shuts IRIS down on these images
# (specs/001-foundation-shell/research.md R2), so IRIS starts through iris-main directly and
# FlightDeck's own first-start script runs once IRIS is up.
ENTRYPOINT ["/tini", "--", "/iris-main", "--check-caps", "false", "-a", "/opt/flightdeck/docker/first-start.sh"]

HEALTHCHECK --interval=15s --timeout=5s --start-period=180s --retries=5 \
  CMD wget -q -O /dev/null http://localhost:52773/flightdeck/ || exit 1
