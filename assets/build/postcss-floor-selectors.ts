import type { PluginCreator, Rule } from 'postcss';
import parser, { type Node, type Pseudo, type Selector } from 'postcss-selector-parser';
import { selectorSpecificity, specificityOfMostSpecificListItem } from '@csstools/selector-specificity';
import { enhancements } from './enhancements.ts';
import { lacking } from './floor.ts';

// Never in the markup, only there to give an expanded :is() alternative the specificity of the whole :is()
const padding = 'does-not-exist';

const isPseudo = (node: Node, ...names: string[]): node is Pseudo =>
  node.type === 'pseudo' && names.includes(node.value.toLowerCase());

const isComplex = (selector: Selector) => selector.nodes.some(node => node.type === 'combinator');

export const inKeyframes = (rule: Rule) =>
  /keyframes$/i.test((rule.parent as { name?: string } | undefined)?.name ?? '');

/**
 * Whether the build drops selectors that use `node`: a standard pseudo-class or pseudo-element that a floor browser
 * lacks and that is not an accepted enhancement. Vendor-prefixed ones are meant for some browsers only.
 */
export function droppedSelector(node: Node) {
  if (node.type !== 'pseudo') return false;

  const name = node.value.replace(/^:+/, '');
  const path = `css.selectors.${name}`;

  return !name.startsWith('-') && !(path in enhancements) && Boolean(lacking(path)?.length);
}

/** Whether `selector` is what :not() takes in Selectors Level 3: one simple selector, not a negation or a group */
export const isSimple = (selector: Selector) =>
  selector.nodes.length === 1 &&
  !parser.isPseudoElement(selector.nodes[0]) &&
  !isPseudo(selector.nodes[0], ':not', ':is', ':where');

const needsLowering = (not: Pseudo) => not.nodes.length !== 1 || !isSimple(not.nodes[0]);

/** A compound `selector` without the spaces it had around it in a list */
function trimmed(selector: Selector) {
  selector.walk(node => {
    node.spaces = { before: '', after: '' };
  });
  return selector;
}

/** Adds selectors that match nothing to `selector` until it has the specificity `target` */
export function pad(selector: Selector, target: { a: number; b: number; c: number }) {
  const own = selectorSpecificity(selector);
  const make = { a: parser.id, b: parser.className, c: parser.tag };

  for (const kind of ['a', 'b', 'c'] as const) {
    for (let i = own[kind]; i < target[kind]; i++) {
      selector.append(
        parser.pseudo({
          value: ':not',
          nodes: [parser.selector({ value: '', nodes: [make[kind]({ value: padding })] })],
        }),
      );
    }
  }
}

/**
 * Puts the simple selectors of `alternative` in place of `pseudo`, keeping the type selector at the start of the
 * compound. Returns false when the result can match nothing (two different type selectors).
 */
function splice(pseudo: Pseudo, alternative: Selector) {
  const selector = pseudo.parent as Selector;
  let start = selector.index(pseudo);

  while (start > 0 && selector.at(start - 1).type !== 'combinator') start--;

  const first = selector.at(start);
  const nodes = alternative.nodes.map(node => node.clone());
  const type = nodes.find(node => node.type === 'tag' || node.type === 'universal');

  if (type && first !== pseudo) {
    nodes.splice(nodes.indexOf(type), 1);

    if (first.type === 'tag' && type.type === 'tag' && first.value !== type.value) return false;
    if (first.type === 'universal' || (first.type !== 'tag' && type.type === 'tag')) {
      selector.insertBefore(first, type);
      if (first.type === 'universal') first.remove();
    }
  }

  pseudo.replaceWith(...nodes);
  return true;
}

/**
 * :not(a, b) and :not(:is(a, b)) as :not(a):not(b), without padding inside :not(). Any other argument, such as a
 * compound, a complex selector or a negation, has no Selectors Level 3 form.
 */
function lowerNot(not: Pseudo) {
  const alternatives = not.nodes.flatMap(selector => lower(selector, false)).map(trimmed);
  const other = alternatives.find(alternative => !isSimple(alternative));

  if (other) throw new Error(`:not(${other}) has no form that floor browsers parse, restructure the rule`);

  not.replaceWith(...alternatives.map(alternative => parser.pseudo({ value: ':not', nodes: [alternative] })));
}

/** The selectors that `selector` stands for in Selectors Level 3, those of :is() `padded` to its specificity */
function lower(selector: Selector, padded = true): Selector[] {
  let not: Pseudo | undefined;

  selector.walkPseudos(pseudo => {
    if (!not && isPseudo(pseudo, ':not') && needsLowering(pseudo)) not = pseudo;
  });

  if (not) {
    lowerNot(not);
    return lower(selector, padded);
  }

  const group = selector.nodes.find(node => isPseudo(node, ':is', ':where')) as Pseudo | undefined;
  if (!group) return [selector];

  const complex = group.nodes.find(isComplex);
  if (complex) throw new Error(`${group.value}(${complex}) has a combinator inside a compound, restructure the rule`);

  const target = padded && isPseudo(group, ':is') ? specificityOfMostSpecificListItem(group.nodes) : undefined;

  return group.nodes.flatMap(alternative => {
    const copy = selector.clone();
    const option = trimmed(alternative.clone());

    if (target) pad(option, target);

    return splice(copy.at(selector.index(group)) as Pseudo, option) ? lower(copy, padded) : [];
  });
}

/**
 * Rewrites selectors into Selectors Level 3, which every floor browser parses: :is() and :where() become the list of
 * their alternatives, each at its own specificity (those of :is() padded to at least that of the :is(), except
 * inside :not()), and :not() takes one simple selector at a time, which counts every argument. Selectors with a
 * standard pseudo-class or pseudo-element that a floor browser lacks (:has(), :user-invalid) are dropped, so that
 * current browsers render what the floor renders.
 */
const postcssFloorSelectors: PluginCreator<void> = () => ({
  postcssPlugin: 'philomena-floor-selectors',
  OnceExit(root) {
    root.walkRules(rule => {
      if (inKeyframes(rule)) return;

      let lowered: Selector[];

      try {
        lowered = parser()
          .astSync(rule.selector)
          .nodes.flatMap(selector => lower(selector))
          .filter(selector => {
            let dead = false;
            selector.walk(node => {
              dead ||= droppedSelector(node);
            });
            return !dead;
          });
      } catch (error) {
        throw rule.error((error as Error).message);
      }

      if (lowered.length) rule.selectors = lowered.map(selector => String(selector).trim());
      else rule.remove();
    });
  },
});

postcssFloorSelectors.postcss = true;

export default postcssFloorSelectors;
