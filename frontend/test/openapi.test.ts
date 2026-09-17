import { describe, expect, it } from "vitest";
import flightdeck from "../../specs/001-foundation-shell/contracts/flightdeck-api.openapi.json";
import iam from "./fixtures/iam-v1.swagger.json";
import mgmnt from "./fixtures/mgmnt-v2.swagger.json";
import { example, normalize } from "../src/domains/rest-apis/openapi";

describe("OpenAPI normalizer (feature 002 research R9)", () => {
  it("normalizes FlightDeck's own OpenAPI 3.0 document", () => {
    const spec = normalize(flightdeck as Record<string, unknown>);
    expect(spec.format).toBe("openapi-3.0");
    expect(spec.basePath).toBe("/api/flightdeck/v1");
    const session = spec.paths.find((p) => p.path === "/session")!;
    expect(session.operations.map((o) => o.method).sort()).toEqual(["DELETE", "GET", "POST"]);
    const vitals = spec.paths.find((p) => p.path === "/vitals")!.operations[0]!;
    const ok = vitals.responses.find((r) => r.status === "200")!;
    expect(ok.schema?.properties?.vitals?.type).toBe("array");
    expect(ok.schema?.properties?.vitals?.items?.properties?.id).toBeDefined();
    expect(vitals.parameters.some((p) => p.name === "X-FlightDeck-Tab" && p.in === "header")).toBe(true);
  });

  it("normalizes a specification-first OpenAPI 2.0 document from the instance", () => {
    const spec = normalize(iam as Record<string, unknown>);
    expect(spec.format).toBe("openapi-2.0");
    expect(spec.basePath).toBe("/api/iam");
    expect(spec.paths.length).toBeGreaterThan(0);
  });

  it("resolves 2.0 definitions and body parameters", () => {
    const spec = normalize(mgmnt as Record<string, unknown>);
    const ops = spec.paths.flatMap((p) => p.operations);
    expect(ops.some((o) => o.responses.some((r) => r.schema && (r.schema.properties || r.schema.items)))).toBe(true);
    expect(JSON.stringify(spec)).not.toContain('"$ref"');
  });

  it("cuts reference cycles and builds skeleton bodies", () => {
    const cyclic = {
      openapi: "3.0.3",
      info: { title: "t", version: "1" },
      paths: { "/n": { post: { requestBody: { content: { "application/json": { schema: { $ref: "#/components/schemas/Node" } } } }, responses: { 200: { description: "ok" } } } } },
      components: { schemas: { Node: { type: "object", properties: { name: { type: "string" }, child: { $ref: "#/components/schemas/Node" } } } } },
    };
    const op = normalize(cyclic).paths[0]!.operations[0]!;
    expect(op.requestBody?.schema.properties?.child?.ref).toBe("#/components/schemas/Node");
    expect(example(op.requestBody!.schema)).toEqual({ name: "", child: {} });
  });
});
