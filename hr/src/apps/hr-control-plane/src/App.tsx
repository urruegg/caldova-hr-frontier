import { useState } from "react";
import { FluentProvider, makeStyles, Button } from "@fluentui/react-components";
import { gfLightTheme } from "./theme";
import { AppHeader } from "./components/AppHeader";
import { NavRail } from "./components/NavRail";
import { MainRegion } from "./components/MainRegion";
import { AppFooter } from "./components/AppFooter";
import { ActionDrawer } from "./components/ActionDrawer";

const useStyles = makeStyles({
  shell: {
    display: "flex",
    flexDirection: "column",
    height: "100vh",
  },
  body: {
    display: "flex",
    flexGrow: 1,
    minHeight: 0,
  },
});

/**
 * HR Control Plane — wireframe shell.
 *
 * Reproduces the five structural regions of docs/brand/hr-control-plane-mockup.html
 * (header, nav rail, main, footer, action drawer) themed with the GF BrandKit
 * (docs/brand/gf-fluent-theme.ts). No Dataverse connector, no data, no
 * business logic — only local UI state for nav selection and drawer
 * open/closed. See docs/specs/2026-09-24-hr-control-plane-code-app-wireframe-design.md.
 */
function App() {
  const styles = useStyles();
  const [selectedNav, setSelectedNav] = useState("focus");
  const [drawerOpen, setDrawerOpen] = useState(false);

  return (
    <FluentProvider theme={gfLightTheme} className={styles.shell}>
      <AppHeader />
      <div className={styles.body}>
        <NavRail selected={selectedNav} onSelect={setSelectedNav} />
        <MainRegion selected={selectedNav} />
      </div>
      <AppFooter />
      <Button
        appearance="secondary"
        onClick={() => setDrawerOpen(true)}
        style={{ position: "fixed", bottom: 16, right: 16 }}
      >
        Open action area (wireframe)
      </Button>
      <ActionDrawer open={drawerOpen} onClose={() => setDrawerOpen(false)} />
    </FluentProvider>
  );
}

export default App;
