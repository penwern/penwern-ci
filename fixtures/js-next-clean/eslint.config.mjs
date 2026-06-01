// Canonical penwern-ci ESLint config for Next.js projects.
// Synced into each js-next repo's `eslint.config.mjs` byte-identical.
// eslint-config-next >= 16 is flat-config native: spread its core-web-vitals array.
import next from "eslint-config-next/core-web-vitals";

export default [
  ...next,
  { ignores: [".next/**", "out/**", "node_modules/**", "coverage/**"] },
];
