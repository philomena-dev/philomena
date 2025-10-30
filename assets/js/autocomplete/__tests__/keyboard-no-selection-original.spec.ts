import { autocompleteTest } from './context';

autocompleteTest('ArrowUp with no selection keeps original input', async ({ ctx, expect }) => {
  await ctx.setInput('f');

  // Immediately press ArrowUp before any selection exists
  await ctx.keyDown('ArrowUp');

  // When no item is selected, ArrowUp moves selection to the last item
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "flower<>",
      "suggestions": [
        "forest  3",
        "force field  1",
        "fog  1",
        "👉 flower  1",
      ],
    }
  `);
});
