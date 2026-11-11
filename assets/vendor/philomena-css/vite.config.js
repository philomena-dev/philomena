import { defineConfig } from 'vite';

// Browsers from March 2022 (Safari 15.4 is the floor: :focus-visible, aspect-ratio, flex gap, logical shorthands).
// Every relative color is computed at build time by the PostCSS plugin, and nothing newer than
// that can be left for the browser to work out
export const cssTarget = ['chrome100', 'edge100', 'firefox98', 'safari15.4', 'ios15.4'];

// `vite build` builds dist/philomena.css, `vite build --mode min` the minified dist/philomena.min.css
export default defineConfig(({ mode }) => {
  const minify = mode === 'min';
  return {
    publicDir: false,
    logLevel: 'warn',
    build: {
      outDir: 'dist',
      emptyOutDir: false,
      cssTarget,
      cssMinify: minify,
      rolldownOptions: {
        input: { philomena: 'css/index.css' },
        output: { assetFileNames: minify ? 'philomena.min.css' : 'philomena.css' },
      },
    },
  };
});
