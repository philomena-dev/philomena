import type { Container, Node, PluginCreator } from 'postcss';

interface Options {
  // The theme stylesheets
  themes: string[];
  // Stylesheets whose declarations are kept whatever their names
  keep?: string[];
}

const fileOf = (node: Node) => node.source?.input.file ?? '';

/**
 * Keeps only the color tokens (`--*-color`) of the theme stylesheets. They load after application.css and import
 * the framework's tokens again, whose sizes and other values would reset what application.css sets.
 */
const postcssThemeColors: PluginCreator<Options> = (options = { themes: [] }) => ({
  postcssPlugin: 'philomena-theme-colors',
  OnceExit(root) {
    if (!options.themes.includes(fileOf(root))) return;

    root.walkDecls(decl => {
      if (!/^--.*-color$/.test(decl.prop) && !options.keep?.includes(fileOf(decl))) decl.remove();
    });

    const prune = (container: Container) => {
      container.each(node => {
        if (!('nodes' in node) || !node.nodes) return;

        prune(node);
        if (node.nodes.every(child => child.type === 'comment')) node.remove();
      });
    };

    prune(root);
  },
});

postcssThemeColors.postcss = true;

export default postcssThemeColors;
