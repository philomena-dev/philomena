import fs from 'fs';
import path from 'path';
import autoprefixer from 'autoprefixer';
import postcssMixins from 'postcss-mixins';
import postcssSimpleVars from 'postcss-simple-vars';
import postcssRelativeColor from '@csstools/postcss-relative-color-syntax';
import { defineConfig, UserConfig, ConfigEnv } from 'vite';

export default defineConfig(({ command }: ConfigEnv): UserConfig => {
  const isDev = command !== 'build';
  const targets = new Map();

  fs.readdirSync(path.resolve(__dirname, 'css/themes/')).forEach(name => {
    const m = name.match(/([-a-z]+).css/);

    if (m)
      targets.set(`css/${m[1]}`, `./css/themes/${m[1]}.css`);
  });

  fs.readdirSync(path.resolve(__dirname, 'css/options/')).forEach(name => {
    const m = name.match(/([-a-z]+).css/);

    if (m)
      targets.set(`css/options/${m[1]}`, `./css/options/${m[1]}.css`);
  });

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
          ...Object.fromEntries(targets)
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
        plugins: [postcssMixins(), postcssSimpleVars(), postcssRelativeColor(), autoprefixer]
      }
    }
  };
});
