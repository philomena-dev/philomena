import type { Container, Node, Plugin } from 'postcss';

interface Options {
  // The theme stylesheets
  themes: string[];
}

const fileOf = (node: Node) => node.source?.input.file ?? '';

/**
 * Keeps only the color tokens (`--*-color`) of the theme stylesheets. They load after application.css and import
 * the framework's tokens again, whose sizes and other values would reset what application.css sets.
 */
export default function postcssThemeColors({ themes }: Options): Plugin {
  return {
    postcssPlugin: 'philomena-theme-colors',
    OnceExit(root) {
      if (!themes.includes(fileOf(root))) return;

      root.walkDecls(decl => {
        if (!/^--.*-color$/.test(decl.prop)) decl.remove();
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
  };
}
