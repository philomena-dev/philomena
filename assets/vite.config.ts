import fs from 'fs';
import path from 'path';
import autoprefixer from 'autoprefixer';
import postcssMixins from 'postcss-mixins';
import postcssNested from 'postcss-nested';
import postcssSimpleVars from 'postcss-simple-vars';
import postcssRelativeColor from '@csstools/postcss-relative-color-syntax';
import { defineConfig, UserConfig, ConfigEnv } from 'vite';

export default defineConfig(({ command }: ConfigEnv): UserConfig => {
  const isDev = command !== 'build';

  if (isDev) {
    process.stdin.on('close', () => {
      // eslint-disable-next-line no-process-exit
      process.exit(0);
    });

    process.stdin.resume();
  }

  const themeNames =
    fs.readdirSync(path.resolve(__dirname, 'css/themes/')).map(name => {
      const m = name.match(/([-a-z]+).css/);

      if (m) { return m[1]; }
      return null;
    });

  const themes = new Map();

  for (const name of themeNames) {
    themes.set(`css/${name}`, `./css/themes/${name}.css`);
  }

  return {
    publicDir: 'static',
    plugins: [],
    resolve: {
      alias: {
        common: path.resolve(__dirname, 'css/common/'),
        views: path.resolve(__dirname, 'css/views/'),
        elements: path.resolve(__dirname, 'css/elements/'),
        themes: path.resolve(__dirname, 'css/themes/')
      }
    },
    build: {
      target: 'es2020',
      outDir: path.resolve(__dirname, '../priv/static'),
      emptyOutDir: false,
      sourcemap: isDev,
      manifest: false,
      cssCodeSplit: true,
      rollupOptions: {
        input: {
          'js/app': './js/app.js',
          'css/application': './css/application.css',
          ...Object.fromEntries(themes)
        },
        output: {
          entryFileNames: '[name].js',
          chunkFileNames: '[name].js',
          assetFileNames: '[name][extname]'
        }
      }
    },
    css: {
      postcss:  {
        plugins: [postcssMixins(), postcssNested(), postcssSimpleVars, postcssRelativeColor(), autoprefixer]
      }
    }
  };
});
