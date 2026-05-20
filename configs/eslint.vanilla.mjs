// Canonical penwern-ci ESLint config for vanilla / non-framework JS projects.
// Synced into each js-vanilla repo's `eslint.config.mjs` byte-identical.
// Caller must have eslint, @eslint/js, globals as devDependencies.
import js from "@eslint/js";
import globals from "globals";

export default [
  js.configs.recommended,
  {
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
      globals: { ...globals.browser, ...globals.node },
    },
  },
  { ignores: ["dist/**", "build/**", "node_modules/**", "coverage/**"] },
];
