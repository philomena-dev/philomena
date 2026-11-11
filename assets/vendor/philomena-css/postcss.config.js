import postcssMixins from 'postcss-mixins';
import postcssSimpleVars from 'postcss-simple-vars';
import postcssRelativeColor from '@csstools/postcss-relative-color-syntax';

// The same plugins, in the same order, as Philomena itself uses
export default {
  plugins: [postcssMixins(), postcssSimpleVars(), postcssRelativeColor()],
};
