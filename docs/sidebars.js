/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  intro: [
    "intro/overview",
    "intro/vision",
    "intro/workflow-and-pipelines",
    "workflows",
  ],
  concepts: [
    {
      type: "category",
      label: "Core Concepts",
      collapsed: false,
      items: [
        "concepts/why-masareen",
        "concepts/profiles-and-identities",
        "concepts/opportunities",
        "concepts/verified-evidence",
      ],
    },
  ],
  backend: [
    {
      type: "category",
      label: "Backend",
      items: [
        "backend/architecture",
        "backend/services",
        "backend/auth",
        "backend/verification-engine",
        "backend/api",
      ],
    },
  ],
  frontend: [
    {
      type: "category",
      label: "Frontend",
      items: [
        "frontend/overview",
        "frontend/web",
        "frontend/mobile",
      ],
    },
  ],
  guides: [
    {
      type: "category",
      label: "How-To Guides",
      items: [
        "guides/quickstart",
        "guides/individual-user",
        "guides/organization",
        "guides/submit-evidence",
        "guides/admin",
      ],
    },
  ],
};

export default sidebars;
