import { spawnSync } from 'node:child_process';
import { closeSync, mkdtempSync, openSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import postcss from 'postcss';
import { preprocessCSS, resolveConfig, type ResolvedConfig } from 'vite';

const assets = path.resolve(import.meta.dirname, '../..');
const cssDir = path.join(assets, 'css');
const contrastScript = path.join(assets, 'vendor/philomena-css/scripts/contrast.mjs');
const stylesheets = [
  'application.css',
  ...readdirSync(path.join(cssDir, 'themes'))
    .filter(name => name.endsWith('.css'))
    .map(name => `themes/${name}`),
];

// The header bars keep the colors of Philomena's themes, light text on a mid-tone bar that the framework's ratio for
// its own header does not reach
const headerPairs = ['light', 'dark'].flatMap(mode =>
  ['header text', 'header brand', 'navbar item hovered'].map(label => `${mode}: ${label}`),
);

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

// Every pair the report marks as failing, as `mode: label`
function failingPairs(report: string) {
  let mode = '';

  return report.split('\n').flatMap(line => {
    mode = line.match(/^(LIGHT|DARK) THEME/)?.[1].toLowerCase() ?? mode;
    const label = line.match(/^ {2}(.+?) +#\w{6} on #\w{6} +[\d.]+ +FAIL$/)?.[1];

    return label ? [`${mode}: ${label}`] : [];
  });
}

// The number of failing pairs the report's summary gives, undefined without a summary
function failureCount(report: string) {
  const summary = report.match(/^(?:(\d+) pair\(s\) below the minimum|All pairs meet the minimum ratios)$/m);

  return summary ? Number(summary[1] ?? 0) : undefined;
}

describe('theme contrast', () => {
  let config: ResolvedConfig;
  let dir: string;

  beforeAll(async () => {
    config = await resolveConfig({ configFile: path.join(assets, 'vite.config.ts'), logLevel: 'silent' }, 'build');
    dir = mkdtempSync(path.join(tmpdir(), 'theme-contrast-'));
  });

  afterAll(() => rmSync(dir, { recursive: true, force: true }));

  it.each(stylesheets)("gives %s the framework's contrast in both modes", async name => {
    const file = path.join(cssDir, name);
    const { code } = await preprocessCSS(readFileSync(file, 'utf8'), file, config);
    const stylesheet = path.join(dir, name.replace('/', '-'));

    writeFileSync(stylesheet, themeBlocks(code));
    // The script exits right after printing, which cuts a report written to a pipe short; a file gets all of it
    const report = openSync(`${stylesheet}.txt`, 'w');
    const { status, stderr } = spawnSync(process.execPath, [contrastScript, stylesheet], {
      encoding: 'utf8',
      stdio: ['ignore', report, 'pipe'],
    });
    closeSync(report);
    const stdout = readFileSync(`${stylesheet}.txt`, 'utf8');
    const failing = failingPairs(stdout);
    const count = failureCount(stdout);

    expect(stderr).toBe('');
    expect(count).toBe(failing.length);
    expect(status).toBe(count === 0 ? 0 : 1);
    expect(failing.filter(pair => !headerPairs.includes(pair))).toEqual([]);
  });
});
