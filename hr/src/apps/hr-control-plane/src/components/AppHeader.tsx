import {
  makeStyles,
  tokens,
  Text,
  Avatar,
  Button,
  Badge,
} from "@fluentui/react-components";
import {
  GlobeRegular,
  ChevronDownRegular,
  AlertRegular,
} from "@fluentui/react-icons";

/**
 * Wireframe only — every value below (env label, capacity %, unread count,
 * persona initials) is a static placeholder, not live data. No connectors,
 * no state, no computation.
 */
const useStyles = makeStyles({
  header: {
    display: "flex",
    alignItems: "center",
    gap: tokens.spacingHorizontalM,
    padding: `${tokens.spacingVerticalSNudge} ${tokens.spacingHorizontalL}`,
    backgroundColor: tokens.colorNeutralBackground1,
    borderBottomWidth: "1px",
    borderBottomStyle: "solid",
    borderBottomColor: tokens.colorNeutralStroke2,
    height: "48px",
    boxSizing: "border-box",
  },
  brandBlock: {
    display: "flex",
    alignItems: "center",
    gap: tokens.spacingHorizontalS,
  },
  wordmark: {
    fontWeight: tokens.fontWeightBold,
    color: tokens.colorBrandForeground1,
  },
  divider: {
    width: "1px",
    height: "20px",
    backgroundColor: tokens.colorNeutralStroke2,
  },
  spacer: {
    flexGrow: 1,
  },
  capacityBar: {
    width: "80px",
    height: "4px",
    borderRadius: tokens.borderRadiusCircular,
    backgroundColor: tokens.colorNeutralStroke2,
    overflow: "hidden",
  },
  capacityFill: {
    height: "100%",
    width: "0%",
    backgroundColor: tokens.colorBrandBackground,
  },
  capacityGroup: {
    display: "flex",
    alignItems: "center",
    gap: tokens.spacingHorizontalXS,
  },
});

/** Header region — logo, environment pill, capacity meter, language/role
 * switches, notification bell, persona avatar. Reproduces the mockup's
 * header structure (docs/brand/hr-control-plane-mockup.html). */
export function AppHeader() {
  const styles = useStyles();

  return (
    <header className={styles.header}>
      <div className={styles.brandBlock}>
        <Text className={styles.wordmark}>GF</Text>
        <span className={styles.divider} aria-hidden="true" />
        <Text weight="semibold">HR Control Plane</Text>
      </div>

      <Badge appearance="outline" color="informative" title="Wireframe placeholder — not a live environment indicator">
        DEV
      </Badge>

      <div className={styles.spacer} />

      <div className={styles.capacityGroup} title="Wireframe placeholder — no live capacity data">
        <Text size={200}>Copilot Studio capacity</Text>
        <span className={styles.capacityBar} aria-hidden="true">
          <span className={styles.capacityFill} />
        </span>
      </div>

      <Button appearance="subtle" icon={<GlobeRegular />} iconPosition="before">
        EN <ChevronDownRegular />
      </Button>

      <Button appearance="subtle" iconPosition="after" icon={<ChevronDownRegular />}>
        Role: HR Operations
      </Button>

      <Button
        appearance="subtle"
        icon={<AlertRegular />}
        aria-label="Notifications (wireframe placeholder)"
      />

      <Avatar name="Wireframe User" initials="—" aria-label="Signed in as (wireframe placeholder)" />
    </header>
  );
}
