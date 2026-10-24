/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  darkMode: "class",
  theme: {
    extend: {
      colors: {
        // Primary brand (MASAREN logo blue), matches mobile MasarenTheme.brand (#0250A3)
        brand: {
          DEFAULT: "#0250A3",
          light: "#0077C8", // azure
          lighter: "#3EB6E0",
          50: "#EAF3FF",
          100: "#D2E6FF",
          200: "#A9D2FF",
          300: "#6FB2F5",
          400: "#2F8DE0",
          500: "#0077C8", // azure
          600: "#0250A3",
          700: "#013E80",
          800: "#022E60",
          900: "#011B3A",
        },
        // Secondary accent (MASAREN logo green), MasarenTheme.green (#2A9D45)
        accent: {
          DEFAULT: "#2A9D45",
          light: "#3EBD5C",
          50: "#E8F8EC",
          100: "#C9EFD2",
          200: "#9BE3AC",
          400: "#5CC873",
          500: "#2A9D45",
          600: "#1F7E35",
          700: "#176229",
        },
        // gold -> brand blue (legacy name kept so old class usage stays valid)
        gold: {
          DEFAULT: "#0250A3",
          light: "#0077C8",
          dark: "#013E80",
        },
        navy: {
          DEFAULT: "#050910",
          50: "#F0F4FF",
          100: "#DCE6F5",
          300: "#7A8FAD",
          500: "#3D4F6B",
          700: "#0D1425",
          800: "#0A1020",
          900: "#050910",
        },
        // Surfaces (Material 3 light)
        canvas: "#F0F4FF",
        surface: "#ffffff",
        ink: "#0D1425",
        muted: "#3D4F6B",
        line: "#DCE6F5",
        like: "#E25555",
      },
      fontFamily: {
        // Flutter uses Google Fonts Cairo across the whole app, mirror it on web.
        sans: ["Cairo", "Inter", "system-ui", "sans-serif"],
        ar: ["Cairo", "Inter", "sans-serif"],
        display: ["Cairo", "Inter", "sans-serif"],
      },
      boxShadow: {
        glow: "0 0 0 1px rgba(2,80,163,0.18), 0 10px 30px rgba(15,27,61,0.10)",
        "glow-gold": "0 0 24px rgba(2,80,163,0.25)",
        card: "0 1px 2px rgba(15,27,61,0.06), 0 4px 16px rgba(15,27,61,0.06)",
        "card-hover": "0 2px 6px rgba(15,27,61,0.10), 0 12px 28px rgba(15,27,61,0.10)",
        float: "0 8px 30px rgba(15,27,61,0.18)",
        fab: "0 10px 24px rgba(2,80,163,0.40)",
      },
      backdropBlur: { xs: "2px" },
      borderRadius: {
        xl: "0.75rem", // 12px  (Material 3 control radius)
        "2xl": "1rem", // 16px  (card radius)
        "3xl": "1.25rem", // 20px
      },
      keyframes: {
        "fade-up": {
          "0%": { opacity: "0", transform: "translateY(12px)" },
          "100%": { opacity: "1", transform: "translateY(0)" },
        },
        shimmer: {
          "0%": { backgroundPosition: "-400px 0" },
          "100%": { backgroundPosition: "400px 0" },
        },
        float: {
          "0%,100%": { transform: "translateY(0)" },
          "50%": { transform: "translateY(-6px)" },
        },
        pop: {
          "0%": { transform: "scale(0.8)", opacity: "0" },
          "100%": { transform: "scale(1)", opacity: "1" },
        },
        "nav-in": {
          "0%": { opacity: "0", transform: "translateY(8px)" },
          "100%": { opacity: "1", transform: "translateY(0)" },
        },
      },
      animation: {
        "fade-up": "fade-up 0.5s ease-out both",
        shimmer: "shimmer 1.4s linear infinite",
        float: "float 6s ease-in-out infinite",
        pop: "pop 0.18s ease-out both",
        "nav-in": "nav-in 0.25s ease-out both",
      },
    },
  },
  plugins: [],
};
