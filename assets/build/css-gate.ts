import postcss, { type AtRule, type Container, type Declaration, type Rule } from 'postcss';
import valueParser from 'postcss-value-parser';
import selectorParser from 'postcss-selector-parser';
import type { Plugin } from 'vite';
import bcd, { type CompatStatement, type Identifier } from '@mdn/browser-compat-data/forLegacyNode';
import { enhancements } from './enhancements.ts';
import { floor, lacking } from './floor.ts';
import { classTwin } from './postcss-floor-focus-visible.ts';
import { inKeyframes, isSimple } from './postcss-floor-selectors.ts';

/** A feature that some piece of CSS needs: a browser-compat-data path, spelled as the CSS spells it */
interface Need {
  path: string;
  spelling?: string;
  // Another spelling that browser-compat-data may record it under
  alias?: string;
}

const prefixed = (name: string) => /^-[a-z]+-/.test(name);
const unprefixed = (name: string) => name.replace(/^-[a-z]+-/, '');
const prefixOf = (name: string) => name.slice(0, name.length - unprefixed(name).length);

/** Function names and units, by the `<code>` names in the descriptions of browser-compat-data's CSS types */
function index(pattern: RegExp, node: Identifier, path: string, found: Record<string, string> = {}) {
  for (const [key, child] of Object.entries(node) as [string, Identifier][]) {
    if (key === '__compat') continue;
    const description = child.__compat?.description ?? '';

    for (const match of description.matchAll(pattern)) found[match[1].toLowerCase()] ??= `${path}.${key}`;
    index(pattern, child, `${path}.${key}`, found);
  }

  return found;
}

const functionPattern = /<code>([-a-z0-9]+)\(\)<\/code>/gi;
// Functions of the CSS types first, then those that browser-compat-data only records for some properties
const functions = index(
  functionPattern,
  bcd.css.properties,
  'css.properties',
  index(functionPattern, bcd.css.types, 'css.types'),
);
// Legacy aliases that browser-compat-data records under the modern name
functions.rgba = functions.rgb;
functions.hsla = functions.hsl;

const units = index(/<code>([a-z]+)<\/code>(?=[^<]*\bunits?\b|, <code>)/gi, bcd.css.types, 'css.types');

// Selectors that browser-compat-data only knows under another name, such as :-webkit-any() or :-moz-focusring
const alternatives: Record<string, string> = {};
for (const [name, entry] of Object.entries(bcd.css.selectors) as [string, Identifier][]) {
  for (const statement of Object.values((entry.__compat as CompatStatement).support).flat()) {
    if (statement.alternative_name) alternatives[statement.alternative_name.replace(/^:+|\(\)$/g, '')] = name;
  }
}

function selectorNeeds(selector: selectorParser.Selector): Need[] {
  const needs: Need[] = [];

  selector.walk(node => {
    if (node.type === 'nesting') needs.push({ path: 'css.selectors.nesting' });
    if (node.type === 'attribute' && node.insensitive) {
      needs.push({ path: 'css.selectors.attribute.case_insensitive_modifier' });
    }
    if (node.type === 'attribute' && node.sensitive) {
      needs.push({ path: 'css.selectors.attribute.case_sensitive_modifier' });
    }
    if (typeof (node as { namespace?: unknown }).namespace === 'string') {
      needs.push({ path: 'css.selectors.namespace' });
    }
    if (node.type !== 'pseudo') return;

    const name = node.value.replace(/^:+/, '').toLowerCase();
    const known = bcd.css.selectors[name] ? name : alternatives[name];
    // A vendor pseudo-element that browser-compat-data does not know is meant for that vendor's browsers only
    if (known || !prefixed(name)) needs.push({ path: `css.selectors.${known ?? name}`, spelling: name });

    // Selectors Level 4 :not(), which takes any list
    if (name === 'not' && !(node.nodes.length === 1 && isSimple(node.nodes[0]))) {
      needs.push({ path: 'css.selectors.not.selector_list' });
    }
    if (/^nth(-last)?-child$/.test(name) && /\sof\s/i.test(String(node))) {
      needs.push({ path: `css.selectors.${name}.of_syntax` });
    }
  });

  return needs;
}

/**
 * The subfeature of `prop` at `key` under the property in browser-compat-data, as a value spelled with `prefix` or
 * the prefix of the property
 */
function subfeature(prop: string, key: string, prefix = ''): Need {
  const name = prefix + key.slice(key.lastIndexOf('.') + 1);
  return { path: `css.properties.${unprefixed(prop)}.${key}`, spelling: name, alias: prefixOf(prop) + name };
}

const decorationLines = /^(none|underline|overline|line-through|blink|inherit|initial|unset|revert|revert-layer)$/i;

/** The thickness, style and color in a text-decoration shorthand, which browser-compat-data records on their own */
function decorationNeeds(prop: string, nodes: valueParser.Node[]): Need[] {
  return nodes
    .filter(node => (node.type === 'word' && !decorationLines.test(node.value)) || node.type === 'function')
    .filter(node => !/^var$/i.test(node.value))
    .map(node => {
      const thickness =
        node.type === 'function'
          ? /^(calc|min|max|clamp)$/i.test(node.value)
          : /^(auto|from-font)$/i.test(node.value) || Boolean(valueParser.unit(node.value));
      return subfeature(prop, thickness ? 'includes_thickness' : 'includes_color-and-style');
    });
}

function valueNeeds(prop: string, value: string, grid = false): Need[] {
  const base = unprefixed(prop);
  const parsed = valueParser(value);
  const needs = base === 'text-decoration' ? decorationNeeds(prop, parsed.nodes) : [];
  // browser-compat-data spells some keywords in camel case, such as currentColor
  const keywords = new Map(Object.keys(bcd.css.properties[base] ?? {}).map(key => [key.toLowerCase(), key]));

  if (base === 'content' && parsed.nodes.some(node => node.type === 'div' && node.value === '/')) {
    needs.push(subfeature(prop, 'alt_text'));
  }

  // Two keywords of display, such as `inline flex`, are a syntax of their own
  if (base === 'display' && parsed.nodes.filter(node => node.type === 'word').length > 1) {
    needs.push(subfeature(prop, 'multi-keyword_values'));
  }

  parsed.walk(node => {
    // A parenthesized group is a function without a name
    if (node.type === 'function' && node.value) {
      const name = node.value.toLowerCase();
      const bare = unprefixed(name);
      // An entry of the property by the same name may be a keyword, such as the linear of transition
      const entry = bcd.css.properties[base]?.[bare]?.__compat;
      const own = entry?.description?.includes(`<code>${bare}()</code>`) && `css.properties.${base}.${bare}`;
      const spelling = prefixed(name) ? name : undefined;
      needs.push({ path: own || (functions[bare] ?? `css.types.${bare}`), spelling });
      if (node.nodes[0]?.value === 'from' && functions[name]) {
        needs.push({ path: `${functions[name]}.relative_syntax` });
      }
      if (node.nodes[0]?.value === 'in' && bcd.css.types.gradient[bare]) {
        needs.push({ path: `css.types.gradient.${bare}.interpolation_color_space` });
      }
      // The arguments of a vendor function follow that vendor's syntax
      if (prefixed(name)) return false;
    }

    if (node.type !== 'word') return;

    const unit = valueParser.unit(node.value);
    if (unit && units[unit.unit.toLowerCase()]) needs.push({ path: units[unit.unit.toLowerCase()] });

    const word = node.value.toLowerCase();
    if (bcd.css.types.global_keywords[word]) needs.push({ path: `css.types.global_keywords.${word}` });
    // A value keyword is recorded as prefixed itself (`-moz-fit-content`) or with the prefix of its property
    const keyword = keywords.get(unprefixed(word));
    // Some alignment keywords came later to flex containers, which browser-compat-data records as _in_flex subfeatures
    // or as the start and end keywords themselves; in a grid they are as old as grid layout
    const inGrid = grid && /^(start|end)$/.test(word) && bcd.css.properties[base]?.context_grid;
    if (!prop.startsWith('--') && keyword && keyword !== '__compat') {
      needs.push(subfeature(prop, inGrid ? 'context_grid' : keyword, prefixOf(word)));
    }
    const flex = `${unprefixed(word)}_in_flex`;
    if (!grid && bcd.css.properties[base]?.context_flex?.[flex]) needs.push(subfeature(prop, `context_flex.${flex}`));
  });

  return needs;
}

/** The property that `decl` declares, in lower case unless it is a custom property */
const property = (decl: Declaration) => (decl.prop.startsWith('--') ? decl.prop : decl.prop.toLowerCase());

function declarationNeeds(decl: Declaration): Need[] {
  const prop = property(decl);
  const base = unprefixed(prop);
  // Any box may be a flex container unless its own rule makes it a grid, and the container of an item is unknown
  const grid =
    !base.endsWith('-self') &&
    decl.parent?.some(
      node => node.type === 'decl' && property(node) === 'display' && /^(inline-)?grid$/i.test(node.value),
    );
  const needs = valueNeeds(prop, decl.value, grid);
  if (prop.startsWith('--')) return needs;

  if (bcd.css.properties[base]) return [{ path: `css.properties.${base}`, spelling: prop }, ...needs];
  if (bcd.css.properties[prop] || !prefixed(prop)) return [{ path: `css.properties.${prop}` }, ...needs];

  // A vendor property that browser-compat-data does not know is meant for that vendor's browsers only
  return needs;
}

/**
 * The floor browsers that lack something in `needs`, with the paths of what they lack. A property, selector,
 * function, at-rule, media feature or @font-face descriptor that browser-compat-data does not know counts as missing
 * everywhere; the vendor-prefixed selectors and properties the data does not know never get here, being meant for
 * that vendor's browsers.
 * Value keywords and units are judged only where the data records them, so unknown ones pass.
 */
function missing(needs: Need[], guarded: Set<string>, excused = true) {
  const result = new Map<string, Set<string>>();

  for (const need of needs) {
    if (guarded.has(need.path)) continue;
    if (excused && Object.keys(enhancements).some(path => need.path === path || need.path.startsWith(`${path}.`))) {
      continue;
    }

    const alias = need.alias ? lacking(need.path, need.alias) : undefined;
    const browsers = (lacking(need.path, need.spelling) ?? Object.keys(floor)).filter(b => !alias || alias.includes(b));

    for (const browser of browsers) {
      if (!result.has(browser)) result.set(browser, new Set());
      result.get(browser)?.add(need.path);
    }
  }

  return result;
}

const describe = (gaps: Map<string, Set<string>>) =>
  [...new Set([...gaps.values()].flatMap(paths => [...paths]))]
    .map(
      path =>
        `${path} (missing in ${[...gaps]
          .filter(([, p]) => p.has(path))
          .map(([b]) => `${b} ${floor[b]}`)
          .join(', ')})`,
    )
    .join('; ');

/** What `rule` declares */
const body = (rule: Rule) => rule.nodes.map(String).join('; ');

/** What `rule` declares, under each of its selectors */
const signatures = (rule: Rule, selectors = rule.selectors) =>
  selectors.map(selector => `${selector} { ${body(rule)} }`);

const native = (selector: string) => classTwin(selector) !== selector;

/**
 * A selector with :focus-visible needs a class twin, the same but for `.focus-visible`, which floor browsers match, in
 * the rule right before its own, so that no rule between the two wins in one kind of browser only. A selector that
 * only negates :focus-visible needs none, which leaves floor browsers to drop the rule. checkRule reports lists that
 * floor browsers drop for one of their selectors.
 */
function checkFocusVisible(rule: Rule, problems: string[]) {
  let previous = rule.prev();
  // The minifier writes a list of native selectors as one rule each
  while (previous?.type === 'rule' && body(previous) === body(rule) && previous.selectors.every(native)) {
    previous = previous.prev();
  }
  const twins = new Set(previous?.type === 'rule' ? signatures(previous) : []);

  if (!signatures(rule, rule.selectors.filter(native).map(classTwin)).every(twin => twins.has(twin))) {
    problems.push(
      `${rule.selector.slice(0, 120)}: :focus-visible without its .focus-visible twin (css.selectors.focus-visible)`,
    );
  }
}

function checkRule(rule: Rule, problems: string[], guarded: Set<string>) {
  const where = rule.selector.slice(0, 120);

  if (rule.parent?.type === 'rule') problems.push(`${where}: nested rule (css.selectors.nesting)`);

  // A selector list is dropped as a whole by a browser that can't parse one of its selectors, enhancements included
  const lists = (inKeyframes(rule) ? [] : selectorParser().astSync(rule.selector).nodes).map(selector => {
    const needs = selectorNeeds(selector);
    const vendor = needs.some(need => prefixed(need.spelling ?? ''));
    return { vendor, gaps: missing(needs, guarded), dropped: missing(needs, guarded, false) };
  });

  for (const { vendor, gaps } of lists) {
    if (gaps.size && !vendor) problems.push(`${where}: ${describe(gaps)}`);
    if (gaps.size === Object.keys(floor).length) problems.push(`${where}: no floor browser matches this selector`);
  }
  if (new Set(lists.map(({ dropped }) => [...dropped.keys()].sort().join())).size > 1) {
    problems.push(`${where}: some floor browsers drop the whole list for one of its selectors, split the rule`);
  }

  // Every floor browser needs one declaration of each property that it understands
  const groups = new Map<string, Declaration[]>();
  rule.each(node => {
    if (node.type !== 'decl') return;
    const prop = unprefixed(property(node));
    // Every browser takes the last declaration of a custom property, whatever its value
    groups.set(prop, prop.startsWith('--') ? [node] : [...(groups.get(prop) ?? []), node]);
  });

  for (const [prop, decls] of groups) {
    // Vendor declarations alone are meant for that vendor's browsers
    if (decls.every(decl => prefixed(decl.prop))) continue;

    const own = decls.find(decl => !prefixed(decl.prop)) as Declaration;
    const left = (covered: Set<string>) => {
      const gaps = decls.map(decl => missing(declarationNeeds(decl), covered));
      return new Map([...missing(declarationNeeds(own), covered)].filter(([b]) => gaps.every(g => g.has(b))));
    };

    const gaps = left(guarded);
    if (gaps.size && left(new Set([...guarded, ...fallbacks(rule, prop)])).size) {
      problems.push(`${where} { ${prop} }: ${describe(gaps)}`);
    }
  }
}

/**
 * The features that an `@supports not (…)` block beside `rule` declares `prop` again for, for its selector. Browsers
 * with the feature skip the block and those without it drop the declaration, so either may come first.
 */
function fallbacks(rule: Rule, prop: string) {
  const paths: string[] = [];

  rule.parent?.each(node => {
    if (
      node.type === 'atrule' &&
      /^supports$/i.test(node.name) &&
      node.some(
        r =>
          r.type === 'rule' &&
          r.selector === rule.selector &&
          r.some(d => d.type === 'decl' && unprefixed(property(d)) === prop),
      )
    ) {
      paths.push(...supportsCondition(node.params).fallbacks);
    }
  });

  return paths;
}

/**
 * The supports() functions of an @supports condition, the features its tests vouch for inside the block, and those
 * that a single negated test gives the block as fallback for
 */
function supportsCondition(params: string) {
  const names: string[] = [];
  const tests: Need[] = [];
  let positive = true;

  (function walk(nodes: valueParser.Node[]) {
    for (const node of nodes) {
      if (node.type === 'word' && /^(not|or)$/i.test(node.value)) positive = false;
      if (node.type !== 'function') continue;

      const colon = node.nodes.findIndex(n => n.type === 'div' && n.value === ':');
      if (node.value) {
        names.push(node.value);
      } else if (colon < 0) {
        walk(node.nodes);
      } else {
        const prop = valueParser.stringify(node.nodes.slice(0, colon)).trim();
        tests.push(
          ...declarationNeeds(postcss.decl({ prop, value: valueParser.stringify(node.nodes.slice(colon + 1)) })),
        );
      }
    }
  })(valueParser(params).nodes);

  const paths = tests.map(test => test.path);
  const negated = /^\s*not\s*\([^()]*\)\s*$/i.test(params);

  return { functions: names, guards: positive ? paths : [], fallbacks: negated ? paths : [] };
}

function checkAtRule(rule: AtRule, problems: string[], guarded: Set<string>) {
  const name = rule.name.toLowerCase();
  const where = `@${rule.name} ${rule.params}`.slice(0, 120);
  const needs: Need[] = prefixed(name) ? [] : [{ path: `css.at-rules.${name}` }];

  if (rule.parent?.type === 'rule') needs.push({ path: 'css.selectors.nesting' });

  if (name === 'media') {
    for (const [, written] of rule.params.matchAll(/\(\s*([-a-z]+)\s*[:)]/gi)) {
      const feature = written.toLowerCase().replace(/^(min|max)-/, '');
      if (!prefixed(feature)) needs.push({ path: `css.at-rules.media.${feature}` });
    }
    if (/[<>=]/.test(rule.params.replace(/\([^():]*:[^()]*\)/g, ''))) {
      needs.push({ path: 'css.at-rules.media.range_syntax' });
    }
    valueParser(rule.params).walk(node => {
      if (node.type === 'word' && /^or$/i.test(node.value)) needs.push({ path: 'css.at-rules.media.or_syntax' });
    });
  }

  if (name === 'import') {
    for (const node of valueParser(rule.params).nodes) {
      if (node.type !== 'string' && /^(layer|supports)$/i.test(node.value)) {
        needs.push({ path: `css.at-rules.import.${node.value.toLowerCase()}` });
      }
    }
  }

  if (name === 'supports') {
    for (const fn of supportsCondition(rule.params).functions) needs.push({ path: `css.at-rules.supports.${fn}` });
  }

  const gaps = missing(needs, guarded);
  if (gaps.size) problems.push(`${where}: ${describe(gaps)}`);
}

/** The problems that keep `css` from working in every floor browser, one message each */
export function checkCss(css: string): string[] {
  const root = postcss.parse(css);
  const problems: string[] = [];

  // A feature that a positive @supports tests for is safe inside it: the CSS around the block is the fallback
  (function walk(container: Container, guarded: Set<string>) {
    container.each(node => {
      if (node.type === 'rule') checkRule(node, problems, guarded);
      if (node.type === 'rule' && /:focus-visible/i.test(node.selector)) checkFocusVisible(node, problems);
      if (node.type === 'atrule') checkAtRule(node, problems, guarded);
      // The descriptors of @font-face are judged by their names, not their values
      if (node.type === 'decl' && node.parent?.type === 'atrule') {
        const descriptor = /^font-face$/i.test((node.parent as AtRule).name);
        const needs = descriptor ? [{ path: `css.at-rules.font-face.${property(node)}` }] : declarationNeeds(node);
        const gaps = missing(needs, guarded);
        if (gaps.size) problems.push(`${node.prop}: ${describe(gaps)}`);
      }
      if (node.type === 'atrule' && /^supports$/i.test(node.name)) {
        walk(node, new Set([...guarded, ...supportsCondition(node.params).guards]));
      } else if (node.type === 'rule' || node.type === 'atrule') {
        walk(node, guarded);
      }
    });
  })(root, new Set());

  return [...new Set(problems)];
}

/**
 * Fails the build when an emitted stylesheet uses a selector, at-rule, property, value, function or unit that a
 * browser of the floor (assets/.browserslistrc) lacks, judged by browser-compat-data. It does not judge keywords set
 * through custom properties, keywords that a floor browser has one by one but not in the combination used (two
 * keywords of display and the color space of a gradient are judged), a gradient with a single color stop, the
 * font-family keywords of the font shorthand (`font: 12px system-ui`), math keywords inside calc(), keywords under an
 * alternative name, media queries with `not` in parentheses, @import conditions, @font-face descriptor values, the
 * inside of vendor-prefixed functions, the real container of alignment keywords and support that browser-compat-data
 * calls partial (build/floor.ts). build/enhancements.ts lists the features accepted anyway.
 */
export default function cssGate(): Plugin {
  return {
    name: 'philomena-css-gate',
    apply: 'build',
    generateBundle(_, bundle) {
      const problems = Object.values(bundle)
        .filter(file => file.type === 'asset' && file.fileName.endsWith('.css'))
        .flatMap(file => checkCss(String(file.type === 'asset' && file.source)).map(p => `${file.fileName}: ${p}`));

      if (problems.length) this.error(`CSS the floor browsers can't use:\n  ${problems.join('\n  ')}`);
    },
  };
}
