import {
  makeStyles,
  tokens,
  Text,
  Badge,
} from "@fluentui/react-components";
import type { FluentIcon } from "@fluentui/react-icons";
import {
  TargetRegular,
  ArrowTrendingLinesRegular,
  PlayCircleRegular,
  WarningRegular,
  ClockRegular,
  BotRegular,
  DocumentTableRegular,
  ShieldCheckmarkRegular,
} from "@fluentui/react-icons";

export interface NavItem {
  id: string;
  label: string;
  icon: FluentIcon;
  /** Wireframe placeholder — presence of a count badge is structural,
   * the value itself is never live data. */
  hasCount?: boolean;
}

/** Mirrors docs/brand/hr-control-plane-mockup.html's nav rail order. */
export const navItems: NavItem[] = [
  { id: "focus", label: "Focus", icon: TargetRegular },
  { id: "journey", label: "Journey", icon: ArrowTrendingLinesRegular },
  { id: "runs", label: "Runs", icon: PlayCircleRegular },
  { id: "exceptions", label: "Exceptions", icon: WarningRegular, hasCount: true },
  { id: "followups", label: "Follow-ups", icon: ClockRegular, hasCount: true },
  { id: "agents", label: "Agents", icon: BotRegular },
  { id: "fields", label: "Field List", icon: DocumentTableRegular },
  { id: "audit", label: "Audit", icon: ShieldCheckmarkRegular },
];

const useStyles = makeStyles({
  nav: {
    display: "flex",
    flexDirection: "column",
    width: "212px",
    flexShrink: 0,
    backgroundColor: tokens.colorNeutralBackground2,
    borderRightWidth: "1px",
    borderRightStyle: "solid",
    borderRightColor: tokens.colorNeutralStroke2,
    paddingTop: tokens.spacingVerticalS,
  },
  item: {
    display: "flex",
    alignItems: "center",
    gap: tokens.spacingHorizontalS,
    padding: `${tokens.spacingVerticalS} ${tokens.spacingHorizontalM}`,
    border: "none",
    background: "none",
    cursor: "pointer",
    textAlign: "left",
    color: tokens.colorNeutralForeground2,
  },
  itemSelected: {
    backgroundColor: tokens.colorSubtleBackgroundSelected,
    color: tokens.colorNeutralForeground1,
    fontWeight: tokens.fontWeightSemibold,
  },
  label: {
    flexGrow: 1,
  },
});

interface NavRailProps {
  selected: string;
  onSelect: (id: string) => void;
}

/** Nav rail region — local selection state only (which item is highlighted).
 * No routing, no data, no business logic. */
export function NavRail({ selected, onSelect }: NavRailProps) {
  const styles = useStyles();

  return (
    <nav className={styles.nav} aria-label="Primary">
      {navItems.map((item) => {
        const Icon = item.icon;
        const isSelected = item.id === selected;
        return (
          <button
            key={item.id}
            type="button"
            className={`${styles.item} ${isSelected ? styles.itemSelected : ""}`}
            aria-current={isSelected ? "page" : undefined}
            onClick={() => onSelect(item.id)}
          >
            <Icon />
            <Text className={styles.label}>{item.label}</Text>
            {item.hasCount && (
              <Badge appearance="tint" color="informative" title="Wireframe placeholder — no live count">
                —
              </Badge>
            )}
          </button>
        );
      })}
    </nav>
  );
}
