import type { PluginCreator } from 'postcss';

/**
 * Declarations that a floor browser lacks, with one that every floor browser has and that renders the same:
 * `word-break: break-word` is specified as `overflow-wrap: anywhere`, and pages are left-to-right.
 */
const replacements: Record<string, [string, string]> = {
  'overflow-wrap: anywhere': ['word-break', 'break-word'],
  'float: inline-start': ['float', 'left'],
  'float: inline-end': ['float', 'right'],
  'clear: inline-start': ['clear', 'left'],
  'clear: inline-end': ['clear', 'right'],
};

const postcssFloorValues: PluginCreator<void> = () => ({
  postcssPlugin: 'philomena-floor-values',
  Declaration(decl) {
    const replacement = replacements[`${decl.prop}: ${decl.value}`];
    if (replacement) [decl.prop, decl.value] = replacement;
  },
});

postcssFloorValues.postcss = true;

export default postcssFloorValues;
