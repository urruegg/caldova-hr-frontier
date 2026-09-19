# ADR-0004: Domain Solution Architecture, Naming and Publisher

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Cross-cutting (all solution domains) |
| **References** | [Approved Intake Design](../specs/2026-09-17-architecture-baseline-intake-design.md), [Source Inventory](../reviews/2026-09-17-architecture-baseline-source-inventory.json) |

This candidate is not an accepted repository decision until attended review approves it.

## Context

The source assessment describes an empty Power Platform solution as the intended starting point, with a publisher already defined in its exported zip. Three decisions follow from that and must be fixed **before the first component is created**, because Power Platform will not let any of them change afterwards:

> *"When you change a solution publisher prefix, you should do it before you create any new apps or metadata items because you can't change the names of metadata items after they're created."*
> — [Create a solution](https://learn.microsoft.com/en-us/power-apps/maker/data-platform/create-solution)

> *"Once you introduce a publisher for a component in a managed solution, you can't change the publisher for the component."*
> — [Solution concepts](https://learn.microsoft.com/en-us/power-platform/alm/solution-concepts-alm)

The three decisions are: how solutions are organised, what they are called, and which publisher owns them.

---

## Proposed Decision

### 1. Two domains, one solution each

The proposed source layout is organised by **domain folder**, with sub-domains expressed as solutions inside that folder. In this proposed baseline, each domain holds exactly one solution.

```text
src/
├── infra/                                 # Infrastructure domain
│   └── solutions/
│       └── <Company>HRFrontierInfra/      # platform foundation
└── hr/                                    # HR domain
    └── solutions/
        └── <Company>HRFrontierHR/         # the HR employee journey
```

| Solution | Contains |
|---|---|
| `<Company>HRFrontierInfra` | Custom connectors, connection references, environment variable definitions, security roles, shared component collections, any cross-domain plumbing |
| `<Company>HRFrontierHR` | Dataverse journey model, Power Automate orchestration, Power Apps experiences, the Power App, Copilot Studio agents |

**Deployment order is always proposed as Infra → HR.** The HR solution depends on the Infra solution; the reverse is never true.

### 2. Naming convention

```text
<Company>HRFrontier<Domain>
```

`<Company>` is a manifest parameter (`CompanyToken`). For the reference tenant it is `Caldova`, producing `CaldovaHRFrontierInfra` and `CaldovaHRFrontierHR`.

The `HR` suffix on the HR-domain solution is mildly redundant against `HRFrontier`. That is accepted deliberately: a predictable, scriptable pattern is worth more than a slightly shorter name, and it keeps room for additional sub-domain solutions (`<Company>HRFrontierHRAnalytics`) without a naming exception.

### 3. Publisher

**One publisher, taken from the supplied solution zip.** Its unique name and prefix will be recorded in the tenant manifest and reused for every solution — not re-created.

| Field | Reference tenant |
|---|---|
| Prefix | **`ur`** — logical names therefore begin `ur_` |
| Unique name and display name | As carried in the supplied solution zip |

The prefix is a **manifest parameter**, so a downstream tenant may choose its own. Doing so creates its **own solution lineage** — see §Consequences.

---

## Rationale

### Why two solutions rather than four or five

1. **Deployment simplicity wins at this scale.** Four solutions meant four ordered imports, four version numbers and four places for a dependency to go wrong, to buy independent release cadence that a showcase does not need.
2. **The dependency graph is genuinely two-layer.** Everything in Infra is consumed by HR; nothing in HR is consumed by Infra. That is a clean boundary, and clean boundaries are what justify a solution split.
3. **Sub-domains remain expressible.** The domain folder holds solutions, plural. When the HR domain needs independent release cadence — analytics, or a second journey — it gets a second solution in the same folder without restructuring.
4. **Fewer solutions, fewer layering surprises.** Solution layering is the most common source of "why did my change not take effect"; two layers is materially easier to reason about than four.

### Why the publisher comes from the zip

The supplied solution zip already carries a publisher. Creating a second publisher and re-homing components across it is not possible for managed components, and creating a parallel publisher is exactly the mistake the Microsoft guidance warns about. Adopting the supplied publisher is the only option that keeps a single publisher across the proposed estate.

---

## Consequences

### Positive

- Two imports, in a fixed order, for a full deployment.
- One publisher, so component ownership can move between solutions later if the domain split needs revisiting.
- Domain folders give reviewers and `CODEOWNERS` a clear boundary.
- Sub-domain growth is additive rather than structural.

### Negative

- **Coarser release granularity.** A change to a single flow re-imports the whole HR solution. Acceptable for a showcase; revisit if a domain grows past comfortable import times.
- **Custom connectors now sit alongside their connection references.** This is the main risk and is called out below.
- **A larger solution takes longer to export, unpack and import**, and produces bigger pull request diffs.

### 🚩 The custom connector risk — verify this early

Microsoft's guidance is explicit:

> *"You must import custom connectors first, then the connection reference with the agent solution."*
> — [Import and export agents](https://learn.microsoft.com/en-us/microsoft-copilot-studio/authoring-solutions-import-export)

The four-solution design satisfied that by isolating connectors. With two solutions, custom connectors and their connection references sit **in the same solution**, and the platform must resolve that dependency intra-solution rather than across an import boundary.

**This should work, and it is not guaranteed.** Treat it as a verification item, not an assumption:

- Verify a clean import of `<Company>HRFrontierInfra` into an empty TEST environment **before** building on it.
- If the import fails on connector dependency resolution, the fallback is a third solution — `<Company>HRFrontierInfraConnectors` — imported first. That is a small, contained change: one folder, one extra import step, no logical name changes.

Related known issue to watch: copying an environment breaks connection references for custom connectors, and canvas apps do not recognise connection references on custom connectors.

### Prefix and downstream tenants

A tenant that adopts `ur` shares logical names with the reference tenant and can import the same managed artefacts directly.

A tenant that chooses its own prefix creates its **own solution lineage**:

| | Shared `ur` prefix | Own prefix |
|---|---|---|
| Logical names | Identical to reference | Different throughout |
| Can import reference managed solutions | **Yes** | **No** |
| Build path | Import the published managed artefact | Build from schema definitions with its prefix |
| Upstream improvements | Arrive as a solution upgrade | Must be re-applied from source |

This is a platform constraint, not a policy choice: there is no supported way to re-prefix existing components. The decision must be made once, before the first table, and recorded in the manifest.

**Default: `ur`.** Choose your own only if the tenant intends to evolve the solution independently.

---

## Alternatives Considered

**Four solutions (Connectors, Core, Apps, Agents).** The previous design. Rejected as more ceremony than this showcase needs, though it did isolate the connector dependency cleanly — which is why the fallback above returns to a variant of it.

**One solution for everything.** Rejected: it would put infrastructure plumbing and HR business logic in one layer with no boundary, and would make a future second journey domain impossible to separate.

**One solution per journey stage.** Rejected: journey stages share the same Dataverse tables, so stage-level solutions would carve a single data model across five layers — the worst case for layering confusion.

**A new publisher for the repository.** Rejected: the solution zip already carries one, and a second publisher would permanently fragment component ownership.

---

## References

- [Approved Intake Design](../specs/2026-09-17-architecture-baseline-intake-design.md) — the governed intake and bootstrap design; Infrastructure detail enters in Phase 3.
- Future HR employee-journey documentation will own the Dataverse model detail.
- [ADR-0003](0003-bicep-and-powershell-for-infrastructure-as-code.md) — proposed IaC toolchain
