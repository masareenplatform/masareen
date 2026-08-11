import React from 'react';
import ComponentCreator from '@docusaurus/ComponentCreator';

export default [
  {
    path: '/docs/',
    component: ComponentCreator('/docs/', 'd9a'),
    routes: [
      {
        path: '/docs/',
        component: ComponentCreator('/docs/', 'ecc'),
        routes: [
          {
            path: '/docs/',
            component: ComponentCreator('/docs/', 'a51'),
            routes: [
              {
                path: '/docs/backend/api',
                component: ComponentCreator('/docs/backend/api', '6b3'),
                exact: true,
                sidebar: "backend"
              },
              {
                path: '/docs/backend/architecture',
                component: ComponentCreator('/docs/backend/architecture', '965'),
                exact: true,
                sidebar: "backend"
              },
              {
                path: '/docs/backend/auth',
                component: ComponentCreator('/docs/backend/auth', 'f21'),
                exact: true,
                sidebar: "backend"
              },
              {
                path: '/docs/backend/services',
                component: ComponentCreator('/docs/backend/services', '6b5'),
                exact: true,
                sidebar: "backend"
              },
              {
                path: '/docs/backend/verification-engine',
                component: ComponentCreator('/docs/backend/verification-engine', '22d'),
                exact: true,
                sidebar: "backend"
              },
              {
                path: '/docs/concepts/opportunities',
                component: ComponentCreator('/docs/concepts/opportunities', 'd17'),
                exact: true,
                sidebar: "concepts"
              },
              {
                path: '/docs/concepts/profiles-and-identities',
                component: ComponentCreator('/docs/concepts/profiles-and-identities', '8b5'),
                exact: true,
                sidebar: "concepts"
              },
              {
                path: '/docs/concepts/verified-evidence',
                component: ComponentCreator('/docs/concepts/verified-evidence', 'bbc'),
                exact: true,
                sidebar: "concepts"
              },
              {
                path: '/docs/concepts/why-masareen',
                component: ComponentCreator('/docs/concepts/why-masareen', 'ee3'),
                exact: true,
                sidebar: "concepts"
              },
              {
                path: '/docs/frontend/mobile',
                component: ComponentCreator('/docs/frontend/mobile', 'a0e'),
                exact: true,
                sidebar: "frontend"
              },
              {
                path: '/docs/frontend/overview',
                component: ComponentCreator('/docs/frontend/overview', '1ec'),
                exact: true,
                sidebar: "frontend"
              },
              {
                path: '/docs/frontend/web',
                component: ComponentCreator('/docs/frontend/web', 'f90'),
                exact: true,
                sidebar: "frontend"
              },
              {
                path: '/docs/guides/admin',
                component: ComponentCreator('/docs/guides/admin', '9a9'),
                exact: true,
                sidebar: "guides"
              },
              {
                path: '/docs/guides/individual-user',
                component: ComponentCreator('/docs/guides/individual-user', '50e'),
                exact: true,
                sidebar: "guides"
              },
              {
                path: '/docs/guides/organization',
                component: ComponentCreator('/docs/guides/organization', '3cd'),
                exact: true,
                sidebar: "guides"
              },
              {
                path: '/docs/guides/quickstart',
                component: ComponentCreator('/docs/guides/quickstart', '189'),
                exact: true,
                sidebar: "guides"
              },
              {
                path: '/docs/guides/submit-evidence',
                component: ComponentCreator('/docs/guides/submit-evidence', '9f8'),
                exact: true,
                sidebar: "guides"
              },
              {
                path: '/docs/intro/vision',
                component: ComponentCreator('/docs/intro/vision', 'dd8'),
                exact: true,
                sidebar: "intro"
              },
              {
                path: '/docs/intro/workflow-and-pipelines',
                component: ComponentCreator('/docs/intro/workflow-and-pipelines', 'ec8'),
                exact: true,
                sidebar: "intro"
              },
              {
                path: '/docs/workflows',
                component: ComponentCreator('/docs/workflows', '524'),
                exact: true,
                sidebar: "intro"
              },
              {
                path: '/docs/',
                component: ComponentCreator('/docs/', '677'),
                exact: true,
                sidebar: "intro"
              }
            ]
          }
        ]
      }
    ]
  },
  {
    path: '*',
    component: ComponentCreator('*'),
  },
];
