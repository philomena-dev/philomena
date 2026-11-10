import { spawnSync } from 'node:child_process';
import { mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import postcss from 'postcss';
import { preprocessCSS, resolveConfig, type ResolvedConfig } from 'vite';

const assets = path.resolve(import.meta.dirname, '../..');
const themes = path.join(assets, 'css/themes');
const contrastScript = path.join(assets, 'vendor/philomena-css/scripts/contrast.mjs');
const hues = readdirSync(themes).filter(name => name.endsWith('.css'));

// The header bars keep the colors of Philomena's themes, light text on a mid-tone bar that the framework's ratio for
// its own header does not reach
const headerPairs = ['header text', 'header brand', 'navbar item hovered'];

// The two theme blocks the contrast script reads. data-theme="light" outranks :root, so the light colors are the dark
// ones with the light rules applied over them. The @supports rules hold display-p3 copies of the sRGB values.
function themeBlocks(css: string) {
  const dark = new Map<string, string>();
  const lightOnly = new Map<string, string>();
  const targets: Record<string, Map<string, string>> = { ':root': dark, ':root[data-theme="light"]': lightOnly };

  for (const node of postcss.parse(css).nodes) {
    if (node.type !== 'rule') continue;

    node.walkDecls(decl => {
      targets[node.selector]?.set(decl.prop, decl.value);
    });
  }

  const block = (selector: string, tokens: Map<string, string>) =>
    `${selector} {\n${[...tokens].map(([prop, value]) => `  ${prop}: ${value};\n`).join('')}}\n`;

  return block(':root', dark) + block(':root[data-theme="light"]', new Map([...dark, ...lightOnly]));
}

// The pairs below the minimum ratio, as `mode: label`
function failingPairs(report: string) {
  let mode = '';

  return report.split('\n').flatMap(line => {
    mode = line.match(/^(LIGHT|DARK) THEME/)?.[1].toLowerCase() ?? mode;
    const label = line.match(/^ {2}(.+?) +#\w{6} on #\w{6} +[\d.]+ +FAIL$/)?.[1];

    return label && !headerPairs.includes(label) ? [`${mode}: ${label}`] : [];
  });
}

describe('theme contrast', () => {
  let config: ResolvedConfig;
  let dir: string;

  beforeAll(async () => {
    config = await resolveConfig({ configFile: path.join(assets, 'vite.config.ts'), logLevel: 'silent' }, 'build');
    dir = mkdtempSync(path.join(tmpdir(), 'theme-contrast-'));
  });

  afterAll(() => rmSync(dir, { recursive: true, force: true }));

  it.each(hues)("gives %s the framework's contrast in both modes", async hue => {
    const file = path.join(themes, hue);
    const { code } = await preprocessCSS(readFileSync(file, 'utf8'), file, config);
    const stylesheet = path.join(dir, hue);

    writeFileSync(stylesheet, themeBlocks(code));
    const { stdout, stderr } = spawnSync(process.execPath, [contrastScript, stylesheet], { encoding: 'utf8' });

    expect(stderr).toBe('');
    expect(stdout).toMatch(/LIGHT THEME[\s\S]+DARK THEME[\s\S]+minimum/);
    expect(failingPairs(stdout)).toEqual([]);
  });
});
