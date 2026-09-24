import { makeStyles, shorthands, tokens, Text } from "@fluentui/react-components";
import { navItems } from "./NavRail";

const useStyles = makeStyles({
  main: {
    flexGrow: 1,
    display: "flex",
    flexDirection: "column",
    padding: tokens.spacingHorizontalXXL,
    overflow: "auto",
  },
  placeholder: {
    flexGrow: 1,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    ...shorthands.border("1px", "dashed", tokens.colorNeutralStroke2),
    borderRadius: tokens.borderRadiusLarge,
    color: tokens.colorNeutralForeground3,
    marginTop: tokens.spacingVerticalL,
  },
});

interface MainRegionProps {
  selected: string;
}

/** Main content region — wireframe placeholder only. None of the mockup's
 * fake triage tiles, journey ribbon, or decision-queue table are ported;
 * that is demo data/logic, not shell structure. */
export function MainRegion({ selected }: MainRegionProps) {
  const styles = useStyles();
  const label = navItems.find((item) => item.id === selected)?.label ?? selected;

  return (
    <main className={styles.main} id="main-content" tabIndex={-1}>
      <Text size={600} weight="semibold">
        {label}
      </Text>
      <div className={styles.placeholder}>
        <Text>Wireframe placeholder — screen content to be designed</Text>
      </div>
    </main>
  );
}
