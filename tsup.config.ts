import { defineConfig } from "tsup";

export default defineConfig({
  entry: ["src/index.ts"],
  // Dual package — modern bundlers pick `import` (ESM), legacy CJS
  // consumers fall back via `require`. Keeps the package compatible
  // with every Node + bundler combo without forcing consumers to
  // care about extension routing.
  format: ["esm", "cjs"],
  dts: true,
  sourcemap: true,
  clean: true,
  // ABIs are pure data — no need to bundle a runtime around them.
  // splitting:false keeps tree-shakers simple (one chunk per format).
  splitting: false,
  treeshake: true,
});
