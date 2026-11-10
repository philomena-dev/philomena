import postcss, { type ChildNode, type PluginCreator, type Rule } from 'postcss';
import parser from 'postcss-selector-parser';
import { selectorSpecificity } from '@csstools/selector-specificity';
import { inKeyframes, pad } from './postcss-floor-selectors.ts';

// The first rule of the-new-css-reset, which unsets every element but a few
const resetSelector = '*:where(:not(html,iframe,canvas,img,svg,video,audio):not(svg *,symbol *))';
const kept = ['iframe', 'canvas', 'img', 'video', 'audio'];

const isPseudoElement = (node: parser.Node) =>
  node.type === 'pseudo' && /^(::|:(before|after|first-line|first-letter)$)/i.test(node.value);

/** Adds `by` type selectors that match nothing to every selector of `rule` that has only type selectors */
function raise(rule: Rule, by: number) {
  rule.selectors = rule.selectors.map(selector =>
    parser(root => {
      const [complex] = root.nodes;
      const { a, b, c } = selectorSpecificity(complex);
      // The reset does not style pseudo-elements, so rules for them keep their place
      if (a === 0 && b === 0 && !complex.some(isPseudoElement)) pad(complex, { a, b, c: c + by });
    }).processSync(selector),
  );
}

/**
 * Rewrites the first rule of the-new-css-reset, whose :not() arguments floor browsers can't parse, into
 * `* xhtml|*:not(iframe)…`: `* xhtml|*` is every HTML element but the root, which leaves out svg and everything
 * inside it, and the elements it keeps are left alone, with their size attributes. That is a specificity of (0,0,5)
 * where the reset has none, so every other selector of only type selectors is raised by as much: the order of the
 * rules is the same as with the reset at zero specificity.
 */
const postcssFloorReset: PluginCreator<void> = () => ({
  postcssPlugin: 'philomena-floor-reset',
  prepare() {
    let reset: Rule | undefined;

    return {
      Once(root) {
        root.walkRules(rule => {
          if (rule.selector.replace(/,\s+/g, ',') !== resetSelector) return;

          reset = rule;
          rule.selector = `* xhtml|*${kept.map(type => `:not(${type})`).join('')}`;

          // @namespace follows @charset and @import and precedes everything else, such as the reset itself
          const next = root.nodes.find(
            node => node.type !== 'comment' && !(node.type === 'atrule' && /^(charset|import)$/i.test(node.name)),
          ) as ChildNode;
          next.before(
            postcss.atRule({
              name: 'namespace',
              params: 'xhtml url("http://www.w3.org/1999/xhtml")',
              source: rule.source,
            }),
          );
        });
      },
      // After the floor-selectors plugin, so that the specificity is that of the selectors the build emits
      OnceExit(root) {
        root.walkRules(rule => {
          if (reset && rule !== reset && !inKeyframes(rule)) raise(rule, kept.length);
        });
      },
    };
  },
});

postcssFloorReset.postcss = true;

export default postcssFloorReset;
