import { autocompleteTest } from './context';
import store from '../../utils/store';

autocompleteTest('history suggestions fill the popup and skip server/local tags', async ({ ctx, expect }) => {
  // Increase the number of history suggestions while typing to equal maxSuggestions
  store.set('autocomplete_search_history_max_suggestions_when_typing', 10);

  // Populate history with many entries sharing the same prefix
  for (let i = 0; i < 12; i++) {
    await ctx.submitForm(`z${i}`);
  }

  // Now type the matching prefix so that history alone fills the popup
  await ctx.setInput('z');

  const ui = ctx.snapUi();

  // Only history suggestions should be present and there should be 10 of them
  expect(ui.suggestions.length).toBe(10);
  expect(ui.suggestions.every(s => s.startsWith('(history) z'))).toBe(true);
});
