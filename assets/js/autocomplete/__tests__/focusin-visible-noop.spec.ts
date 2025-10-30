import { autocompleteTest } from './context';
import { fireEvent } from '@testing-library/dom';

// Covers onFocusIn early return when popup is already visible
autocompleteTest('focusin does nothing when popup is already visible', async ({ ctx, expect }) => {
  // Show suggestions first
  await ctx.setInput('mar');

  // Ensure popup is visible now
  expect(ctx.snapUi().suggestions.length).toBeGreaterThan(0);

  // Dispatch focusin; since popup is visible, handler should early-return
  fireEvent.focusIn(document);

  // Nothing should change
  expect(ctx.snapUi().suggestions.length).toBeGreaterThan(0);
});
