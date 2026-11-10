import postcss, { type PluginCreator } from 'postcss';

// The first rule of the-new-css-reset, which unsets every element but a few
const resetSelector = '*:where(:not(html,iframe,canvas,img,svg,video,audio):not(svg *,symbol *))';

/**
 * Rewrites the first rule of the-new-css-reset, whose :not() arguments floor browsers can't parse, keeping its zero
 * specificity: `* xhtml|*` is every HTML element but the root, which leaves out svg and everything inside it. The
 * replaced elements it also leaves out get their browser styles back right after, along with the reset's box-sizing
 * (this rule outranks the reset's `*` one); their size attributes are lost, size them with CSS.
 */
const postcssFloorReset: PluginCreator<void> = () => ({
  postcssPlugin: 'philomena-floor-reset',
  OnceExit(root) {
    root.walkRules(rule => {
      if (rule.selector.replace(/,\s+/g, ',') !== resetSelector) return;

      rule.selector = '* xhtml|*';
      rule.after(
        postcss
          .rule({ selector: 'iframe, canvas, img, video, audio' })
          .append(
            postcss.decl({ prop: 'all', value: 'revert' }),
            postcss.decl({ prop: 'box-sizing', value: 'border-box' }),
          ),
      );

      const imports = root.nodes.filter(node => node.type === 'atrule' && /^(charset|import)$/i.test(node.name));
      const namespace = postcss.atRule({ name: 'namespace', params: 'xhtml url("http://www.w3.org/1999/xhtml")' });

      if (imports.length) imports[imports.length - 1].after(namespace);
      else root.prepend(namespace);
    });
  },
});

postcssFloorReset.postcss = true;

export default postcssFloorReset;
