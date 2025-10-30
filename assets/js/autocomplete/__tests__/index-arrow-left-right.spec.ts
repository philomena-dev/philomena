import { autocompleteTest } from './context';

// Covers index.ts ArrowLeft/ArrowRight deferred refresh path
autocompleteTest('left/right arrows defer refresh without breaking selection', async ({ ctx, expect }) => {
  await ctx.setInput('for<>');

  // Initial suggestions present
  expect(ctx.snapUi().suggestions.length).toBeGreaterThan(0);

  // Move cursor left and right to trigger deferred refresh
  await ctx.keyDown('ArrowLeft');
  await ctx.keyDown('ArrowRight');

  // Suggestions should still be present and input unchanged around the cursor
  const snap = ctx.snapUi();
  expect(snap.suggestions.length).toBeGreaterThan(0);
  expect(snap.input.replace(/[<>]/g, '')).toBe('for');
});
