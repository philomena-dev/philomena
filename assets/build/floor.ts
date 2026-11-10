import { resolve } from 'path';
import browserslist from 'browserslist';
import bcd, { type Identifier, type SimpleSupportStatement } from '@mdn/browser-compat-data/forLegacyNode';

// The browserslist families of .browserslistrc, by their browser-compat-data name and Vite build target name
const families: Record<string, { data: string; target: string }> = {
  chrome: { data: 'chrome', target: 'chrome' },
  edge: { data: 'edge', target: 'edge' },
  firefox: { data: 'firefox', target: 'firefox' },
  safari: { data: 'safari', target: 'safari' },
  ios_saf: { data: 'safari_ios', target: 'ios' },
};

/** The oldest version of every browser family in the list, `ios_saf 14.5-14.8` as `14.5` */
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
  resolved.map(([family, version]) => [families[family].data, version]),
);

/** The floor as `build.target`, which `build.cssTarget` defaults to */
export const buildTarget = resolved.map(([family, version]) => families[family].target + version);

/** The browser-compat-data entry at a dotted path such as `css.selectors.has` */
export function feature(path: string): Identifier | undefined {
  let node: Identifier | undefined = bcd as unknown as Identifier;

  for (const key of path.split('.')) node = node?.[key];

  return node?.__compat ? node : undefined;
}

// Browser versions have at most a major and a minor part
function value(version: string) {
  const [major, minor = 0] = version.replace('≤', '').split('.').map(Number);
  return major * 1000 + minor;
}

function versionAtMost(version: string, limit: string) {
  return value(version) <= value(limit);
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
