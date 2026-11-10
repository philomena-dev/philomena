import type { AtRule, ChildNode, PluginCreator } from 'postcss';
import valueParser, { type Node } from 'postcss-value-parser';
import selectorParser from 'postcss-selector-parser';
import { droppedSelector } from './postcss-floor-selectors.ts';

type Truth = boolean | undefined;

function selectorTest(selector: string): Truth {
  let dead = false;

  selectorParser(root =>
    root.walkPseudos(pseudo => {
      dead ||= droppedSelector(pseudo);
    }),
  ).processSync(selector);

  return dead ? false : undefined;
}

function test(node: Node): Truth {
  if (node.type !== 'function') return undefined;

  const declaration = node.nodes.some(n => n.type === 'div' && n.value === ':');
  if (node.value === '' && !declaration) return condition(node.nodes);
  return node.value === 'selector' ? selectorTest(valueParser.stringify(node.nodes)) : undefined;
}

function condition(nodes: Node[]): Truth {
  const parts = nodes.filter(node => node.type !== 'space' && node.type !== 'comment');

  if (parts[0]?.type === 'word' && parts[0].value === 'not') {
    const value = test(parts[1]);
    return value === undefined ? undefined : !value;
  }

  const tests = parts.filter((_, i) => i % 2 === 0).map(part => test(part));
  const any = parts[1]?.value === 'or';

  if (tests.includes(any)) return any;
  return tests.includes(undefined) ? undefined : !any;
}

/** Applies what `rule`'s condition evaluates to when it is known at build time */
function settle(rule: AtRule) {
  const value = condition(valueParser(rule.params).nodes);

  if (value === true) rule.replaceWith(rule.nodes as ChildNode[]);
  else if (value === false) rule.remove();
}

/**
 * Decides at build time the @supports conditions that test a selector the floor-selectors plugin drops: such a
 * selector is missing for the stylesheet everywhere, so the block is dropped (or kept unconditionally, when negated).
 */
const postcssFloorSupports: PluginCreator<void> = () => ({
  postcssPlugin: 'philomena-floor-supports',
  OnceExit(root) {
    root.walkAtRules(/^supports$/i, settle);
  },
});

postcssFloorSupports.postcss = true;

export default postcssFloorSupports;
