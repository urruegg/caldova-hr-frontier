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
