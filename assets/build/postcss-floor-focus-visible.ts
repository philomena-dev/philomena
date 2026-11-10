import type { PluginCreator, Rule } from 'postcss';
import parser from 'postcss-selector-parser';

/** The selector with `:focus-visible` as the `.focus-visible` class that the focus-visible polyfill sets */
export const classTwin = (selector: string) =>
  parser(root =>
    root.walkPseudos(pseudo => {
      if (pseudo.value.toLowerCase() === ':focus-visible') {
        pseudo.replaceWith(parser.className({ value: 'focus-visible' }));
      }
    }),
  ).processSync(selector);

/**
 * Writes every rule for `:focus-visible` with the `.focus-visible` class of the polyfill loaded by js/app.ts, which
 * floor browsers match, followed by a native twin of the same specificity, which current browsers match before the
 * polyfill runs and without scripts. A floor browser drops a whole rule that names `:focus-visible`, so the native
 * twin takes only the selectors that use it.
 */
const postcssFloorFocusVisible: PluginCreator<void> = () => ({
  postcssPlugin: 'philomena-floor-focus-visible',
  OnceExit(root) {
    const rules: Rule[] = [];
    root.walkRules(/:focus-visible/i, rule => {
      rules.push(rule);
    });

    for (const rule of rules) {
      const classes = rule.selectors.map(classTwin);
      const natives = rule.selectors.filter((selector, i) => classes[i] !== selector);

      if (!natives.length) continue;

      rule.cloneAfter({ selectors: natives });
      rule.selectors = classes;
    }
  },
});

postcssFloorFocusVisible.postcss = true;

export default postcssFloorFocusVisible;
