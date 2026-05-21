// Canonical penwern-ci ESLint config for vanilla / non-framework JS projects.
// Synced into each js-vanilla repo's `eslint.config.mjs` byte-identical.
// Caller must have eslint, @eslint/js, globals as devDependencies.
import js from "@eslint/js";
import globals from "globals";

// Pydio Cells / Curate runtime globals — available at execution time because
// curate-dev-js (and any sibling Curate UI extensions) are injected into the
// Pydio Cells <head>. Declared here so no-undef doesn't fire on legitimate uses.
const pydioRuntimeGlobals = {
  pydio: "readonly",
  PydioApi: "readonly",
  Curate: "readonly",
  UploaderModel: "readonly",
};

export default [
  js.configs.recommended,
  {
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
      globals: { ...globals.browser, ...globals.node, ...pydioRuntimeGlobals },
    },
  },
  { ignores: ["dist/**", "build/**", "node_modules/**", "coverage/**"] },
];
