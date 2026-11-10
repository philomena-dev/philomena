import { resolve } from 'path';
import browserslist from 'browserslist';
import bcd, { type Identifier, type SimpleSupportStatement } from '@mdn/browser-compat-data/forLegacyNode';

/**
 * How the browserslist families of .browserslistrc map to browser-compat-data (`data`, what the CSS gate judges) and
 * to Vite's build targets (`target`). A family without `data` is not judged: browser-compat-data has no record of it.
 * Samsung Internet is left out of the judgment on purpose: the oldest version the `since` line brings in, 13.0, is a
 * Chromium 83, which lacks features (flex gap, the `revert` keyword) that the explicit floors have.
 */
const families: Record<string, { data?: string; target?: string }> = {
  chrome: { data: 'chrome', target: 'chrome' },
  edge: { data: 'edge', target: 'edge' },
  firefox: { data: 'firefox', target: 'firefox' },
  safari: { data: 'safari', target: 'safari' },
  ios_saf: { data: 'safari_ios', target: 'ios' },
  opera: { data: 'opera', target: 'opera' },
  and_chr: { data: 'chrome_android' },
  and_ff: { data: 'firefox_android' },
  android: { data: 'webview_android' },
  op_mob: { data: 'opera_android' },
  samsung: {},
  and_qq: {},
  and_uc: {},
  baidu: {},
  kaios: {},
};

/** The oldest version of every browser family in the list, `ios_saf 14.0-14.4` as `14.0` */
export function oldest(list: string[]): Record<string, string> {
  const result: Record<string, string> = {};

  for (const entry of list) {
    const [family, range] = entry.split(' ');
    const version = range.split('-')[0];

    if (!families[family]) throw new Error(`.browserslistrc brings in ${family}, which build/floor.ts does not map`);
    if (!(family in result) || versionAtMost(version, result[family])) result[family] = version;
  }

  return result;
}

const resolved = Object.entries(oldest(browserslist(undefined, { path: resolve(import.meta.dirname, '..') })));

/**
 * The oldest browsers Philomena supports (assets/.browserslistrc), keyed by their browser-compat-data names. The
 * build lowers its output for them and the CSS gate checks it against them.
 */
export const floor: Record<string, string> = Object.fromEntries(
  resolved.flatMap(([family, version]) => (families[family].data ? [[families[family].data, version]] : [])),
);

/** The floor as `build.target`, which `build.cssTarget` defaults to */
export const buildTarget = resolved.flatMap(([family, version]) =>
  families[family].target ? [families[family].target + version] : [],
);

/** The browser-compat-data entry at a dotted path such as `css.selectors.has` */
export function feature(path: string): Identifier | undefined {
  let node: Identifier | undefined = bcd as unknown as Identifier;

  for (const key of path.split('.')) node = node?.[key];

  return node?.__compat ? node : undefined;
}

function versionAtMost(version: string, limit: string) {
  const a = version.replace('≤', '').split('.').map(Number);
  const b = limit.split('.').map(Number);

  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    const d = (a[i] ?? 0) - (b[i] ?? 0);
    if (d !== 0) return d < 0;
  }

  return true;
}

function supports(statement: SimpleSupportStatement, version: string, name: string, spelling: string) {
  const added = statement.version_added;
  // Alternative names of selectors are written as `:-webkit-any()`
  const spelt = statement.alternative_name?.replace(/^:+|\(\)$/g, '') ?? (statement.prefix ?? '') + name;

  return (
    spelt === spelling &&
    !statement.flags &&
    typeof added === 'string' &&
    added !== 'preview' &&
    versionAtMost(added, version) &&
    !(statement.version_removed && versionAtMost(statement.version_removed, version))
  );
}

/**
 * The floor browsers that lack the feature at `path`, as it is spelt in the CSS (a prefixed or alternative name of
 * the feature, its own name by default), or undefined when browser-compat-data does not know the feature.
 */
export function lacking(path: string, spelling?: string): string[] | undefined {
  const support = feature(path)?.__compat?.support as Record<string, SimpleSupportStatement | SimpleSupportStatement[]>;
  if (!support) return undefined;

  const name = path.slice(path.lastIndexOf('.') + 1);

  return Object.keys(floor).filter(b => ![support[b]].flat().some(s => supports(s, floor[b], name, spelling ?? name)));
}
