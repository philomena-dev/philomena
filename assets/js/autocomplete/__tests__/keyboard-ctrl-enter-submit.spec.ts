import { autocompleteTest } from './context';

autocompleteTest('Ctrl+Enter submits the form when a tag suggestion is selected', async ({ ctx, expect }) => {
  await ctx.setInput('f');

  // Select the first tag suggestion
  await ctx.keyDown('ArrowDown');

  // Submit via Ctrl+Enter
  await ctx.keyDown('Enter', { ctrlKey: true });

  // After submission, the popup should be hidden
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "forest<>",
      "suggestions": [],
    }
  `);
});
