/* ============================================================
 * Caldova product theme — Fluent 2
 * Caldova HR Agentic Platform
 *
 * For @fluentui/react-components in the Power Apps code app.
 *
 * The inherited values are an interim product palette pending an
 * approved Caldova design standard. They are not an official corporate
 * identity. Names and provenance wording changed; palette values,
 * contrast targets, semantic-state colours, and dark-mode behavior did not.
 * ============================================================ */

import {
  createLightTheme,
  createDarkTheme,
  type BrandVariants,
  type Theme,
} from "@fluentui/react-components";

/** Brand ramp. Primary (#1965A3) sits at step 60. */
export const caldovaBrandRamp: BrandVariants = {
  10: "#04121E",
  20: "#08243C",
  30: "#0C3559",
  40: "#104776",
  50: "#145893",
  60: "#1965A3", // PRIMARY — 6.05:1 on white
  70: "#2C76B0",
  80: "#4488BE",
  90: "#5F9ACB",
  100: "#7CACD8", // dark-mode primary — 7.28:1 on #1B1A19
  110: "#99BFE4",
  120: "#B5D1EC",
  130: "#CFE1F3",
  140: "#E2EDF8",
  150: "#EFF5FB",
  160: "#F7FAFD",
};

const caldovaFontFamily =
  '"Segoe UI Variable Display", "Segoe UI Variable Text", "Segoe UI", ' +
  "system-ui, -apple-system, sans-serif";

/** Shared overrides applied to both themes. */
const caldovaShared = {
  fontFamilyBase: caldovaFontFamily,
  borderRadiusSmall: "2px",
  borderRadiusMedium: "4px",
  borderRadiusLarge: "8px",
} satisfies Partial<Theme>;

export const caldovaLightTheme: Theme = {
  ...createLightTheme(caldovaBrandRamp),
  ...caldovaShared,
};

export const caldovaDarkTheme: Theme = {
  ...createDarkTheme(caldovaBrandRamp),
  ...caldovaShared,
};

/* ------------------------------------------------------------
 * Semantic colours.
 *
 * Deliberately NOT branded: Fluent's semantic set is
 * accessibility-tuned, and users read success/warning/danger by
 * colour before they read the word. Recolouring them to brand
 * blue costs comprehension and buys nothing.
 * ---------------------------------------------------------- */
export const caldovaSemantic = {
  light: {
    success: "#0F7B3F", successBg: "#DFF6E6",
    warning: "#AF5700", warningBg: "#FFF4E0",
    danger:  "#A4262C", dangerBg:  "#FDE7E9",
    info:    "#0F6CBD", infoBg:    "#EFF6FC",
  },
  dark: {
    success: "#5EC98A", successBg: "#10301C",
    warning: "#E8A33D", warningBg: "#3A2609",
    danger:  "#F1707B", dangerBg:  "#3B1014",
    info:    "#7CACD8", infoBg:    "#08243C",
  },
} as const;

/** Data-visualisation series. Ordered for categorical use. */
export const caldovaDataViz = [
  "#1965A3", // brand
  "#4AA6E5", // sky
  "#0F7B3F", // success
  "#AF5700", // warning
  "#A4262C", // danger
  "#605E5C", // neutral
] as const;

/** Supported locales. DE is a first-class locale, not an afterthought. */
export const caldovaLocales = ["en", "de", "it", "fr", "es"] as const;
export type CaldovaLocale = (typeof caldovaLocales)[number];
export const caldovaDefaultLocale: CaldovaLocale = "en";

/**
 * Identifiers that are NEVER translated or localised, in any locale.
 * A translated identifier cannot be traced back to its source document.
 */
export const caldovaNonLocalisedPatterns = [
  /^UC-\d{4}$/,           // use cases
  /^(FR|NFR|BR|AC|D|TD)-\d+$/, // requirements and decisions
  /^ADR-\d{4}$/,          // decision records
  /^RUN-\d{4}-\d{4}-\d{2}$/, // agent runs
  /^PKG-\d{4}-\d{4}-\d{2}$/, // employee packages
  /^caldova_[a-z]+$/,           // Dataverse tables
] as const;
