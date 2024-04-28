import fs from 'fs';
import path from 'path';
import rollupPluginMultiEntry from '@rollup/plugin-multi-entry';
import { defineConfig } from "vite";

export default defineConfig(({ command }: any) => {
  const isDev = command !== "build";

  if (isDev) {
    process.stdin.on("close", () => {
      process.exit(0);
    });

    process.stdin.resume();
  }

  const themeNames =
    fs.readdirSync(path.resolve(__dirname, 'css/themes')).map(name => {
      const m = name.match(/([-a-z]+).scss/);

      if (m) m[1]
}   );

  const themes = new Map();

  for (const name of themeNames) {
    themes.set(`css/${name}`, `./css/themes/${name}.scss`);
  }

  return {
    publicDir: "static",
    plugins: [rollupPluginMultiEntry()],
    resolve: {
      alias: {
        common: path.resolve(__dirname, 'css/common/'),
        views: path.resolve(__dirname, 'css/views/')
      }
    },
    build: {
      target: "es2020",
      outDir: path.resolve(__dirname, '../priv/static'),
      emptyOutDir: true,
      sourcemap: isDev,
      manifest: false,
      rollupOptions: {
        input: {
          'js/app.js': "./js/app.js",
          ...themes
        },
        output: {
          entryFileNames: "assets/[name].js", // remove hash
          chunkFileNames: "assets/[name].js",
          assetFileNames: "assets/[name][extname]"
        }
      }
    }
  };
});
