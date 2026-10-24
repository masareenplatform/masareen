// @ts-check
import { themes as prismThemes } from "prism-react-renderer";

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: "MASAREEN",
  tagline: "Infrastructure for Impact, verified, measurable, trusted.",
  favicon: "img/favicon.ico",

  url: "https://masareen.mediahubnetwork.net",
  baseUrl: "/docs/",

  organizationName: "masareen",
  projectName: "masareen-docs",

  onBrokenLinks: "warn",
  onBrokenMarkdownLinks: "warn",

  i18n: {
    defaultLocale: "en",
    locales: ["en"],
  },

  presets: [
    [
      "classic",
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarPath: "./sidebars.js",
          routeBasePath: "/",
          editUrl: "https://github.com/masareen/masareen-docs/tree/main/",
        },
        blog: false,
        theme: {
          customCss: "./src/css/custom.css",
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      colorMode: {
        defaultMode: "dark",
        respectPrefersColorScheme: true,
      },
      image: "img/masareen-og.png",
      navbar: {
        title: "MASAREEN Docs",
        logo: {
          alt: "MASAREEN",
          src: "img/logo-full.png",
        },
        items: [
          { type: "docSidebar", sidebarId: "intro", position: "left", label: "Introduction" },
          { to: "/docs/concepts/why-masareen", label: "Concepts", position: "left" },
          { to: "/docs/backend/architecture", label: "Backend", position: "left" },
          { to: "/docs/frontend/overview", label: "Frontend", position: "left" },
          { to: "/docs/guides/quickstart", label: "Guides", position: "left" },
          {
            href: "https://masareen.mediahubnetwork.net",
            label: "Open Platform",
            position: "right",
          },
        ],
      },
      footer: {
        style: "dark",
        links: [
          {
            title: "Docs",
            items: [
              { label: "Introduction", to: "/docs/intro/overview" },
              { label: "Architecture", to: "/docs/backend/architecture" },
              { label: "Guides", to: "/docs/guides/quickstart" },
            ],
          },
          {
            title: "Community",
            items: [
              { label: "Platform", href: "https://masareen.mediahubnetwork.net" },
              { label: "Download App", href: "https://masareen.mediahubnetwork.net/downloads/masaren-app-release.apk" },
            ],
          },
        ],
        copyright: `Copyright © ${new Date().getFullYear()} MASAREEN. Built for impact.`,
      },
      prism: {
        theme: prismThemes.github,
        darkTheme: prismThemes.dracula,
        additionalLanguages: ["bash", "json", "yaml", "python", "dart", "typescript"],
      },
    }),
};

export default config;
