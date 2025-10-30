import { autocompleteTest } from './context';

// Covers the early-return path in onKeyDown when Enter is pressed without a selected suggestion
autocompleteTest('Enter with no selected suggestion is a no-op', async ({ ctx, expect }) => {
  await ctx.focusInput();

  // Type something to show suggestions but don't move selection
  await ctx.setInput('mar');
  const before = ctx.snapUi();

  // Press Enter with no selection
  await ctx.keyDown('Enter', { key: 'Enter' });

  // UI should remain unchanged (no preventDefault side effects or confirmation)
  expect(ctx.snapUi()).toEqual(before);
});
