import { makeStyles, tokens, Text, Link } from "@fluentui/react-components";

const useStyles = makeStyles({
  footer: {
    backgroundColor: tokens.colorNeutralBackground1,
    borderTopWidth: "1px",
    borderTopStyle: "solid",
    borderTopColor: tokens.colorNeutralStroke2,
  },
  cols: {
    display: "grid",
    gridTemplateColumns: "repeat(3, 1fr)",
    gap: tokens.spacingHorizontalXL,
    padding: tokens.spacingHorizontalL,
  },
  col: {
    display: "flex",
    flexDirection: "column",
    gap: tokens.spacingVerticalXS,
  },
  colTitle: {
    fontWeight: tokens.fontWeightSemibold,
    color: tokens.colorNeutralForeground3,
    textTransform: "uppercase",
    fontSize: tokens.fontSizeBase200,
  },
  bar: {
    display: "flex",
    justifyContent: "space-between",
    padding: `${tokens.spacingVerticalS} ${tokens.spacingHorizontalL}`,
    borderTopWidth: "1px",
    borderTopStyle: "solid",
    borderTopColor: tokens.colorNeutralStroke2,
    color: tokens.colorNeutralForeground3,
    fontSize: tokens.fontSizeBase200,
  },
  barRight: {
    display: "flex",
    gap: tokens.spacingHorizontalS,
  },
});

/** Footer region — 3-column layout (Platform / Governance / Status) plus a
 * bottom disclaimer bar, mirroring the mockup's footer structure. Governance
 * links use generic themed labels rather than the mockup's specific ADR
 * citations, which predate this repository's ADR renumbering and would be
 * wrong if reproduced verbatim. Status values are placeholders, not live
 * data. */
export function AppFooter() {
  const styles = useStyles();

  return (
    <footer className={styles.footer}>
      <div className={styles.cols}>
        <div className={styles.col}>
          <Text className={styles.colTitle}>Platform</Text>
          <Text weight="semibold">GF HR Agentic Platform</Text>
          <Text size={200}>Level 3 — agentic. Workday is the system of record. Humans decide.</Text>
          <Text size={200}>Control Plane · wireframe</Text>
        </div>
        <div className={styles.col}>
          <Text className={styles.colTitle}>Governance</Text>
          <Link>Write envelope policy</Link>
          <Link>Workday access policy</Link>
          <Link>Process architecture</Link>
          <Link>Platform requirements</Link>
        </div>
        <div className={styles.col}>
          <Text className={styles.colTitle}>Status</Text>
          <Text size={200}>Environment: —</Text>
          <Text size={200}>Agents live: —</Text>
          <Text size={200}>Capacity: —</Text>
          <Text size={200}>Last run: —</Text>
        </div>
      </div>
      <div className={styles.bar}>
        <Text size={200}>Wireframe — no functional code. Not connected to Workday or Dataverse.</Text>
        <div className={styles.barRight}>
          <Text size={200}>Georg Fischer Ltd · Schaffhausen · © 2026</Text>
          <Link>Privacy</Link>
          <Link>Accessibility</Link>
        </div>
      </div>
    </footer>
  );
}
