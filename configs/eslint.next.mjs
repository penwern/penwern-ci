// Canonical penwern-ci ESLint config for Next.js projects.
// Synced into each js-next repo's `eslint.config.mjs` byte-identical.
// Caller must have eslint (>=9), @eslint/eslintrc, and eslint-config-next as devDependencies
// (eslint-config-next ships bundled with `next` itself in recent versions).
import { FlatCompat } from "@eslint/eslintrc";

const compat = new FlatCompat({ baseDirectory: import.meta.dirname });

export default [
  ...compat.extends("next/core-web-vitals"),
  { ignores: [".next/**", "out/**", "node_modules/**", "coverage/**"] },
  {
    // The flat-config file itself is the only legitimate place where an anonymous
    // default export is required — exempt it to suppress the canonical's self-warning.
    files: ["eslint.config.mjs"],
    rules: { "import/no-anonymous-default-export": "off" },
  },
];
