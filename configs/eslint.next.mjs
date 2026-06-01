// Canonical penwern-ci ESLint config for Next.js projects.
// Synced into each js-next repo's `eslint.config.mjs` byte-identical.
//
// eslint-config-next >= 16 is flat-config native: import its core-web-vitals
// array directly and spread it (the old FlatCompat.extends("next/core-web-vitals")
// bridge no longer works, v16 ships flat configs that break the eslintrc compat
// layer). eslint-config-next ships bundled with `next`.
//
// Hold ESLint at 9.x: eslint-config-next 16 calls internals (scopeManager.addGlobals)
// that ESLint 10 removed, so `eslint .` crashes under 10. Move both together once
// eslint-config-next ships ESLint 10 support.
import next from "eslint-config-next/core-web-vitals";

export default [
  ...next,
  { ignores: [".next/**", "out/**", "node_modules/**", "coverage/**"] },
  {
    // The flat-config file itself is the only legitimate place where an anonymous
    // default export is required, so exempt it to suppress the canonical's self-warning.
    files: ["eslint.config.mjs"],
    rules: { "import/no-anonymous-default-export": "off" },
  },
];
