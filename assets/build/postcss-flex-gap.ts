import postcss, { type PluginCreator, type Rule } from 'postcss';
import valueParser from 'postcss-value-parser';
import parser from 'postcss-selector-parser';
import { inKeyframes } from './postcss-floor-selectors.ts';

/**
 * The floor browsers without flex gap are the ones without `<string>` list markers (Safari and iOS 14.0;
 * build/__tests__/postcss-flex-gap.spec.ts checks it against browser-compat-data), so this condition selects them.
 */
export const fallbackCondition = 'not (list-style-type: "")';

type Flex = Partial<Record<'display' | 'direction' | 'wrap', string>>;
type Margins = Record<'container' | 'children' | 'following', Record<string, string>>;

const keywords = {
  direction: ['row', 'row-reverse', 'column', 'column-reverse'],
  wrap: ['nowrap', 'wrap', 'wrap-reverse'],
};

export const isGap = (prop: string) => prop === 'gap' || prop === 'row-gap' || prop === 'column-gap';

const hasGap = (rule: Rule) => rule.some(node => node.type === 'decl' && isGap(node.prop));

/** The display, flex direction and flex wrap that `rule` declares */
function flexOf(rule: Rule) {
  const flex: Flex = {};

  rule.each(node => {
    if (node.type !== 'decl') return;
    const words = node.value.split(/\s+/);

    if (node.prop === 'display') flex.display = node.value;
    for (const key of ['direction', 'wrap'] as const) {
      if (node.prop === `flex-${key}` || node.prop === 'flex-flow') {
        flex[key] = words.find(word => keywords[key].includes(word)) ?? flex[key];
      }
    }
  });

  return flex;
}

/** The classes, ids and type of the last compound of `selector` */
function subject(selector: string) {
  const names = new Set<string>();

  parser(root => {
    const nodes = root.first.nodes;
    for (let i = nodes.length - 1; i >= 0 && nodes[i].type !== 'combinator'; i--) names.add(String(nodes[i]));
  }).processSync(selector);

  return names;
}

/** The rules before `rule` that style the elements of `selector`, as their last compound is a subset of its */
function related(rule: Rule, selector: string, rules: Rule[]) {
  const own = subject(selector);

  return rules
    .slice(0, rules.indexOf(rule))
    .filter(other => other.selectors.some(s => [...subject(s)].every(name => own.has(name))));
}

/** The flex layout of `rule`, the parts it does not declare taken from the last rule in `base` that does */
function resolve(rule: Rule, base: Rule[]) {
  const flex = flexOf(rule);

  for (const key of ['display', 'direction', 'wrap'] as const) {
    flex[key] ??= base
      .map(flexOf)
      .reverse()
      .find(other => other[key] !== undefined)?.[key];
  }

  return flex;
}

function gapsOf(rule: Rule) {
  const gaps = { row: '0', column: '0', important: false };

  rule.each(node => {
    if (node.type !== 'decl' || !isGap(node.prop)) return;

    const values = valueParser(node.value)
      .nodes.filter(n => n.type !== 'space')
      .map(n => (n.value === 'normal' ? '0' : valueParser.stringify(n)));

    if (values.some(value => /^(inherit|initial|unset|revert)$/.test(value))) {
      throw node.error(`${node.prop}: ${node.value} has no margin fallback, use a length`);
    }

    if (node.prop !== 'column-gap') gaps.row = values[0];
    if (node.prop !== 'row-gap') gaps.column = values[values.length - 1];
    gaps.important ||= node.important;
  });

  return gaps;
}

/**
 * The margins standing in for the gaps of a flex container, on the container itself, on every child and on every
 * child but the first. A nowrap row or column spaces every child but the first; a wrapping container gives every
 * child the gaps at its end and pulls its own end edges in by as much.
 */
function marginsOf(flex: Flex, row: string, column: string): Margins {
  if (/grid/.test(flex.display ?? '')) return { container: {}, children: {}, following: {} };

  if (flex.wrap !== undefined && flex.wrap !== 'nowrap') {
    return {
      container: { 'margin-right': `calc(-1 * ${column})`, 'margin-bottom': `calc(-1 * ${row})` },
      children: { 'margin-right': column, 'margin-bottom': row },
      following: {},
    };
  }

  const direction = flex.direction ?? 'row';
  const side = { row: 'left', 'row-reverse': 'right', column: 'top', 'column-reverse': 'bottom' }[direction];

  return { container: {}, children: {}, following: { [`margin-${side}`]: direction.startsWith('row') ? column : row } };
}

function fallback(rule: Rule, rules: Rule[]) {
  const block = postcss.atRule({ name: 'supports', params: fallbackCondition });
  const { row, column, important } = gapsOf(rule);

  for (const selector of rule.selectors) {
    const base = related(rule, selector, rules);
    const flex = resolve(rule, base);
    const own = marginsOf(flex, row, column);
    const margins: Margins = { container: {}, children: {}, following: {} };

    // A rule for the same elements with other gaps leaves margins this one has to take back
    for (const other of base.filter(hasGap)) {
      const theirs = marginsOf(resolve(other, base.slice(0, base.indexOf(other))), '0', '0');
      Object.assign(margins.container, theirs.container);
      Object.assign(margins.children, theirs.children, theirs.following);
    }

    if (!/grid/.test(flex.display ?? '')) Object.assign(margins.container, { 'row-gap': '0', 'column-gap': '0' });
    Object.assign(margins.container, own.container);
    Object.assign(margins.children, own.children);
    Object.assign(margins.following, own.following);

    const selectors = { container: selector, children: `${selector} > *`, following: `${selector} > * + *` };
    for (const part of ['container', 'children', 'following'] as const) {
      const decls = Object.entries(margins[part]).map(([prop, value]) => postcss.decl({ prop, value, important }));
      if (decls.length) block.append(postcss.rule({ selector: selectors[part] }).append(decls));
    }
  }

  if (block.nodes?.length) rule.after(block);
}

/**
 * Lays out flex containers with margins instead of gaps in the floor browsers that lack flex gap, behind
 * `fallbackCondition`. The display, flex direction and wrap come from the rule, or else from the rules before it
 * for the same elements.
 */
const postcssFlexGap: PluginCreator<void> = () => ({
  postcssPlugin: 'philomena-flex-gap',
  OnceExit(root) {
    const rules: Rule[] = [];

    root.walkRules(rule => {
      if (!inKeyframes(rule)) rules.push(rule);
    });

    rules.filter(hasGap).forEach(rule => fallback(rule, rules));
  },
});

postcssFlexGap.postcss = true;

export default postcssFlexGap;
