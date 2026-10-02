import {
  makeStyles,
  tokens,
  Text,
  Badge,
} from "@fluentui/react-components";
import { navItems } from "./navigation";

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
