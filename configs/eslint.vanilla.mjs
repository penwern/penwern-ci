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
    rules: {
      // Universally-accepted "_" prefix convention for intentionally-unused identifiers
      // (loop vars, callback params required by signature, destructured-but-skipped fields).
      "no-unused-vars": [
        "error",
        {
          varsIgnorePattern: "^_",
          argsIgnorePattern: "^_",
          caughtErrorsIgnorePattern: "^_",
          destructuredArrayIgnorePattern: "^_",
        },
      ],
    },
  },
  // Underscore-prefixed source files are conventional template/placeholder files
  // (Webpack and similar build tools skip them; they often contain placeholder syntax).
  {
    ignores: ["dist/**", "build/**", "node_modules/**", "coverage/**", "**/_*-template.js"],
  },
];
