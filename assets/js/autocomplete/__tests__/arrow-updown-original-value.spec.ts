import { autocompleteTest } from './context';

// Covers updateInputWithOriginalValue path when no suggestions exist and ArrowDown is pressed
autocompleteTest('arrow keys restore original value when no suggestions exist', async ({ ctx, expect }) => {
  // Start focused with empty input and no suggestions
  await ctx.focusInput();
  expect(ctx.snapUi()).toEqual({ input: '', suggestions: [] });

  // Press ArrowDown: with nothing selected, AC should restore original value (still empty)
  await ctx.keyDown('ArrowDown');

  expect(ctx.snapUi()).toEqual({ input: '', suggestions: [] });
});
