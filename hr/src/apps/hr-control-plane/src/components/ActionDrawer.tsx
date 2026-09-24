import {
  makeStyles,
  tokens,
  Text,
  Button,
} from "@fluentui/react-components";
import { DismissRegular } from "@fluentui/react-icons";

const useStyles = makeStyles({
  overlay: {
    position: "fixed",
    inset: 0,
    backgroundColor: "rgba(0, 0, 0, 0.2)",
  },
  drawer: {
    position: "fixed",
    top: 0,
    right: 0,
    bottom: 0,
    width: "360px",
    backgroundColor: tokens.colorNeutralBackground1,
    boxShadow: tokens.shadow28,
    display: "flex",
    flexDirection: "column",
  },
  head: {
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    padding: tokens.spacingHorizontalM,
    borderBottomWidth: "1px",
    borderBottomStyle: "solid",
    borderBottomColor: tokens.colorNeutralStroke2,
  },
  body: {
    flexGrow: 1,
    padding: tokens.spacingHorizontalM,
    color: tokens.colorNeutralForeground3,
  },
});

interface ActionDrawerProps {
  open: boolean;
  onClose: () => void;
}

/** Action area — the mockup's aside.drawer contextual side panel
 * (resolve/assign/escalate actions in the original design). Wireframe only:
 * open/closed is local UI state, no actions are wired. */
export function ActionDrawer({ open, onClose }: ActionDrawerProps) {
  const styles = useStyles();

  if (!open) return null;

  return (
    <>
      <div className={styles.overlay} onClick={onClose} aria-hidden="true" />
      <aside className={styles.drawer} role="dialog" aria-modal="true" aria-labelledby="drawerTitle">
        <div className={styles.head}>
          <Text id="drawerTitle" weight="semibold">
            Action area
          </Text>
          <Button
            appearance="subtle"
            icon={<DismissRegular />}
            aria-label="Close"
            onClick={onClose}
          />
        </div>
        <div className={styles.body}>
          <Text>Wireframe placeholder — no actions are wired yet.</Text>
        </div>
      </aside>
    </>
  );
}
