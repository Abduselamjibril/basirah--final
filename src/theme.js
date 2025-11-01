import { createContext, useState, useMemo } from "react";
import { createTheme } from "@mui/material/styles";

// New color design tokens based on the BASIRAH Identity Guideline
export const tokens = (mode) => ({
  ...(mode === "dark"
    ? {
        // --- DARK MODE PALETTE ---
        grey: {
          100: "#e0e0e0", 
          200: "#c2c2c2",
          300: "#a3a3a3",
          400: "#858585",
          500: "#666666",
          600: "#525252",
          700: "#3d3d3d",
          800: "#292929",
          900: "#141414",
        },
        primary: { // Based on Oxford Blue: #041f47
          100: "#d3d7de",
          200: "#a8afbd",
          300: "#7c879c",
          400: "#515f7b",
          500: "#25375a",
          600: "#041f47", // The main Oxford Blue
          700: "#031939",
          800: "#02132b",
          900: "#010d1d", // Deepest blue for backgrounds
        },
        greenAccent: { // Based on Caribbean Green: #00c895
          100: "#e5f9f4",
          200: "#ccf2e9",
          300: "#b2ecde",
          400: "#99e5d3",
          500: "#00c895", // The main Caribbean Green
          600: "#00a077",
          700: "#007859",
          800: "#00503c",
          900: "#00281e",
        },
        redAccent: { // For destructive actions like logout
          100: "#f8dcdb",
          200: "#f1b9b7",
          300: "#e99592",
          400: "#e2726e",
          500: "#db4f4a",
          600: "#af3f3b",
          700: "#832f2c",
          800: "#58201e",
          900: "#2c100f",
        },
        blueAccent: { // Kept for components like ProgressCircle
          100: "#e1e2fe",
          200: "#c3c6fd",
          300: "#a4a9fc",
          400: "#868dfb",
          500: "#6870fa",
          600: "#535ac8",
          700: "#3e4396",
          800: "#2a2d64",
          900: "#151632",
        },
      }
    : {
        // --- LIGHT MODE PALETTE ---
        grey: {
          100: "#141414",
          200: "#292929",
          300: "#3d3d3d",
          400: "#525252",
          500: "#666666",
          600: "#858585",
          700: "#a3a3a3",
          800: "#c2c2c2",
          900: "#e0e0e0",
        },
        primary: { // Based on Oxford Blue: #041f47
          100: "#f0f2f5",
          200: "#e1e7f0",
          300: "#d1d9e6",
          400: "#c2cce1",
          500: "#b2c0dd",
          600: "#041f47", // Main Oxford Blue for primary elements
          700: "#031939",
          800: "#02132b",
          900: "#010d1d",
        },
        greenAccent: { // Based on Caribbean Green: #00c895
          100: "#e5f9f4",
          200: "#ccf2e9",
          300: "#b2ecde",
          400: "#99e5d3",
          500: "#00c895", // The main Caribbean Green
          600: "#00a077",
          700: "#007859",
          800: "#00503c",
          900: "#00281e",
        },
        redAccent: {
          100: "#2c100f",
          200: "#58201e",
          300: "#832f2c",
          400: "#af3f3b",
          500: "#db4f4a",
          600: "#e2726e",
          700: "#e99592",
          800: "#f1b9b7",
          900: "#f8dcdb",
        },
        blueAccent: {
          100: "#151632",
          200: "#2a2d64",
          300: "#3e4396",
          400: "#535ac8",
          500: "#6870fa",
          600: "#868dfb",
          700: "#a4a9fc",
          800: "#c3c6fd",
          900: "#e1e2fe",
        },
      }),
});

// mui theme settings
export const themeSettings = (mode) => {
  const colors = tokens(mode);
  return {
    palette: {
      mode: mode,
      ...(mode === "dark"
        ? {
            primary: {
              main: colors.primary[600], // Oxford Blue
              light: colors.primary[500],
            },
            secondary: {
              main: colors.greenAccent[500], // Caribbean Green
            },
            neutral: {
              dark: colors.grey[700],
              main: colors.grey[500],
              light: colors.grey[100],
            },
            background: {
              default: colors.primary[900], // Deepest blue for main background
              paper: colors.primary[800],   // Slightly lighter for cards, sidebars
            },
          }
        : {
            primary: {
              main: colors.primary[600], // Oxford Blue
            },
            secondary: {
              main: colors.greenAccent[500], // Caribbean Green
              dark: colors.greenAccent[700],
            },
            neutral: {
              dark: colors.grey[700],
              main: colors.grey[500],
              light: colors.grey[900], // Lighter grey for light mode
            },
            background: {
              default: "#fcfcfc",      // Clean white background
              paper: "#ffffff",         // Pure white for cards
            },
          }),
    },
    typography: {
      fontFamily: ["Source Sans Pro", "sans-serif"].join(","),
      fontSize: 12,
      h1: { fontFamily: ["Source Sans Pro", "sans-serif"].join(","), fontSize: 40 },
      h2: { fontFamily: ["Source Sans Pro", "sans-serif"].join(","), fontSize: 32 },
      h3: { fontFamily: ["Source Sans Pro", "sans-serif"].join(","), fontSize: 24 },
      h4: { fontFamily: ["Source Sans Pro", "sans-serif"].join(","), fontSize: 20 },
      h5: { fontFamily: ["Source Sans Pro", "sans-serif"].join(","), fontSize: 16 },
      h6: { fontFamily: ["Source Sans Pro", "sans-serif"].join(","), fontSize: 14 },
    },
  };
};

export const ColorModeContext = createContext({
  toggleColorMode: () => {},
});

export const useMode = () => {
  const [mode, setMode] = useState("dark");
  const colorMode = useMemo(
    () => ({
      toggleColorMode: () =>
        setMode((prev) => (prev === "light" ? "dark" : "light")),
    }),
    []
  );
  const theme = useMemo(() => createTheme(themeSettings(mode)), [mode]);
  return [theme, colorMode];
};