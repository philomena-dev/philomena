import autoprefixer from 'autoprefixer';
import postcssLogical, { type pluginOptions } from 'postcss-logical';
import type { AcceptedPlugin } from 'postcss';
import postcssFloorFocusVisible from './postcss-floor-focus-visible.ts';
import postcssFloorReset from './postcss-floor-reset.ts';
import postcssFloorSelectors from './postcss-floor-selectors.ts';
import postcssFloorSupports from './postcss-floor-supports.ts';
import postcssFloorValues from './postcss-floor-values.ts';

// The framework is written for left-to-right pages, so logical properties are static physical ones. text-align and
// caption-side keep their start and end values, which every floor browser has and computes as written.
function logical() {
  const plugin = postcssLogical({ inlineDirection: 'left-to-right', blockDirection: 'top-to-bottom' } as pluginOptions);
  const { Declaration } = plugin as { Declaration: Record<string, unknown> };

  delete Declaration['text-align'];
  delete Declaration['caption-side'];
  return plugin;
}

/**
 * The PostCSS stage that brings the CSS down to the floor browsers, after the authoring plugins and before Vite's
 * own lowering for `build.cssTarget`.
 */
export default function cssCompat(): AcceptedPlugin[] {
  return [
    logical(),
    postcssFloorValues(),
    postcssFloorFocusVisible(),
    postcssFloorSelectors(),
    // Rewrites the reset before the floor-selectors plugin runs and raises selectors after it
    postcssFloorReset(),
    postcssFloorSupports(),
    // Reads .browserslistrc
    autoprefixer(),
  ];
}
