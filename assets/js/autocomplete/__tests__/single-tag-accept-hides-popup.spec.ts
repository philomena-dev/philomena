import { autocompleteTest } from './context';
import { $ } from '../../utils/dom';

// Covers the single-tag early accept path (Enter/Comma hides the popup)
autocompleteTest('single-tag: pressing Enter hides the popup without selecting', async ({ ctx, expect }) => {
  // Switch the field to single-tag mode
  const input = $<HTMLInputElement>('.test-input')!;
  input.dataset.autocomplete = 'single-tag';

  // Show some suggestions
  await ctx.setInput('mar');
  expect(ctx.snapUi().suggestions.length).toBeGreaterThan(0);

  // Press Enter in single-tag mode: should hide the popup immediately
  await ctx.keyDown('Enter', { key: 'Enter' });

  expect(ctx.snapUi().suggestions).toEqual([]);
});
