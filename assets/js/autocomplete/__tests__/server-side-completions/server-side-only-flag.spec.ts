import { autocompleteTest } from '../context';
import store from '../../../utils/store';

autocompleteTest(
  'when SERVER_SIDE_COMPLETIONS_ONLY is set, local tag suggestions are hidden',
  async ({ ctx, expect }) => {
    // Enable the flag that forces server-side only completions
    store.set('SERVER_SIDE_COMPLETIONS_ONLY', true);

    // Type a very short prefix that would normally produce local suggestions
    await ctx.setInput('f');

    // With the flag on, local tag suggestions are cleared before showing
    // and since term length < 3, no server request is made; popup stays empty
    expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "f<>",
      "suggestions": [],
    }
  `);
  },
);
