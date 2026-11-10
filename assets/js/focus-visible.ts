// The polyfill applies itself once evaluated, and the bundler evaluates a required CommonJS module only when the call
// runs. A dynamic import would put it in a chunk of its own, which app.js, a classic script, can't load.
declare const require: (id: 'focus-visible') => void;

/**
 * Applies the focus-visible polyfill in browsers without `:focus-visible`, where the stylesheets match the
 * `.focus-visible` class that it sets instead.
 */
export function polyfillFocusVisible() {
  if (!CSS.supports('selector(:focus-visible)')) require('focus-visible');
}
