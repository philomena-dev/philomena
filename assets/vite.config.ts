import fs from 'fs';
import path from 'path';
import postcssMixins from 'postcss-mixins';
import postcssSimpleVars from 'postcss-simple-vars';
import postcssRelativeColor from '@csstools/postcss-relative-color-syntax';
import { defineConfig } from 'vitest/config';
import cssCompat from './build/css-compat.ts';
import cssGate from './build/css-gate.ts';
import themeColors from './build/postcss-theme-colors.ts';
import { buildTarget } from './build/floor.ts';
import type { ConfigEnv, ViteUserConfig } from 'vitest/config';

export default defineConfig(({ command, mode }: ConfigEnv): ViteUserConfig => {
  const isDev = command !== 'build' && mode !== 'test';
  // The stylesheets of a directory as build entries, named `{out}/{file name}`
  const stylesheets = (dir: string, out: string): Record<string, string> =>
    Object.fromEntries(
      fs
        .readdirSync(path.resolve(import.meta.dirname, dir))
        .filter(name => name.endsWith('.css'))
        .map(name => [`${out}/${path.basename(name, '.css')}`, path.resolve(import.meta.dirname, dir, name)]),
    );
  const themes = stylesheets('css/themes', 'css');

  return {
    publicDir: 'static',
    plugins: [cssGate()],
    server: {
      host: '0.0.0.0',
      port: 5173,
      cors: true,
      // The workspace root is the repository: serve only the assets and the packages, fonts included
      fs: { allow: [import.meta.dirname, path.resolve(import.meta.dirname, '../node_modules')] },
    },
    build: {
      target: buildTarget,
      outDir: path.resolve(import.meta.dirname, '../priv/static'),
      emptyOutDir: false,
      sourcemap: isDev,
      manifest: false,
      cssCodeSplit: true,
      rollupOptions: {
        input: {
          'js/app': './js/app.ts',
          'css/application': './css/application.css',
          ...themes,
          ...stylesheets('css/options', 'css/options'),
        },
        output: {
          entryFileNames: '[name].js',
          chunkFileNames: '[name].js',
          assetFileNames: '[name][extname]',
        },
      },
    },
    css: {
      postcss: {
        plugins: [
          postcssMixins(),
          postcssSimpleVars(),
          postcssRelativeColor(),
          themeColors({ themes: Object.values(themes) }),
          ...cssCompat(),
        ],
      },
    },
    test: {
      globals: true,
      environment: 'jsdom',
      exclude: ['**/node_modules/**', '.*\\.test\\.ts$', '.*\\.d\\.ts$', '.*\\.spec\\.ts$'],
      // TODO Jest --randomize CLI flag equivalent, consider enabling in the future
      // sequence: { shuffle: true },
      setupFiles: './test/vitest-setup.ts',
      coverage: {
        reporter: ['text', 'html'],
        include: ['js/**/*.{js,ts}', 'build/**/*.ts'],
        exclude: ['js/app.ts', '**/__tests__/**'],
        thresholds: {
          statements: 0,
          branches: 0,
          functions: 0,
          lines: 0,
          '**/query/**/*.ts': {
            statements: 100,
            branches: 100,
            functions: 100,
            lines: 100,
          },
          '**/utils/**/*.ts': {
            statements: 100,
            branches: 100,
            functions: 100,
            lines: 100,
          },
          'build/**/*.ts': {
            statements: 100,
            branches: 100,
            functions: 100,
            lines: 100,
          },
        },
      },
    },
  };
});
