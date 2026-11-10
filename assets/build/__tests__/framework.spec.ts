import path from 'node:path';
import postcss, { type Root, type Rule } from 'postcss';
import { build, type Rollup } from 'vite';
import { checkCss } from '../css-gate.ts';

const assets = path.resolve(import.meta.dirname, '../..');

// The rule of the stylesheet that declares `prop` as `value`, with its declarations by property
function declaring(root: Root, prop: string, value: string) {
  const rule = root.nodes.find(
    (node): node is Rule => node.type === 'rule' && node.some(d => 'prop' in d && d.prop === prop && d.value === value),
  );
  const declarations: Record<string, string> = {};
  rule?.walkDecls(decl => {
    declarations[decl.prop] = decl.value;
  });

  return { selectors: rule?.selectors, declarations };
}

describe('the vendored framework', () => {
  let css: string;

  // The whole framework, which application.css imports only in part, built as `vite build` builds a stylesheet
  beforeAll(async () => {
    const output = (await build({
      configFile: path.join(assets, 'vite.config.ts'),
      logLevel: 'silent',
      publicDir: false,
      build: { write: false },
      plugins: [
        {
          name: 'framework-input',
          config(config) {
            Object.assign(config.build?.rollupOptions ?? {}, {
              input: { framework: '@philomena/philomena-css/css/index.css' },
            });
          },
        },
      ],
    })) as Rollup.RollupOutput;

    css = String((output.output.find(file => file.fileName === 'framework.css') as Rollup.OutputAsset).source);
  }, 60_000);

  it('passes the CSS gate', () => {
    expect(css).toContain('.button');
    expect(checkCss(css)).toEqual([]);
  });

  // css/elements/misc.css spaces paragraphs where the rhythm does not, from these two properties
  it('marks the children of flow containers and leaves the flow margin invalid elsewhere', () => {
    const root = postcss.parse(css);
    const universal = declaring(root, '--flow', 'initial');

    expect(universal.selectors).toEqual([expect.stringMatching(/^\*?(:not\(does-not-exist\))+$/)]);
    expect(universal.declarations['--flow-margin']).toMatch(/^calc\(var\(--flow\)\s*\*/);
    expect(declaring(root, '--flow', '1').selectors).toEqual(expect.arrayContaining(['.content>*', '.card>*']));
  });
});
