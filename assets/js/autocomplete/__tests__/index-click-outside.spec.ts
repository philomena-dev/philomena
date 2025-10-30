import { autocompleteTest } from './context';

autocompleteTest('clicking outside hides the popup and clears active input', async ({ ctx, expect }) => {
  await ctx.setInput('f');
  // Ensure suggestions visible
  expect(ctx.snapUi().suggestions.length).toBeGreaterThan(0);

  // Click outside the input
  document.body.click();
  await vi.runAllTimersAsync();

  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "f<>",
      "suggestions": [],
    }
  `);
});
