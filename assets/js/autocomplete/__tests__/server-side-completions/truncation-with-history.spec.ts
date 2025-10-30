import { autocompleteTest } from '../context';
import store from '../../../utils/store';

autocompleteTest('server suggestions are truncated by leftover slots after history', async ({ ctx, expect }) => {
  // Allow many history suggestions when typing to occupy most slots
  store.set('autocomplete_search_history_max_suggestions_when_typing', 9);

  // Pre-populate a bunch of history entries
  const historyValues = ['foo', 'far', 'faz', 'fob', 'fib', 'fud', 'fig', 'fee', 'fem'];

  for (const val of historyValues) {
    await ctx.submitForm(val);
  }

  // Type a term that has both history and tag matches
  await ctx.setInput('f');

  // We expect 9 history items and only 1 tag suggestion (10 max - 9 history)
  const ui = ctx.snapUi();
  const historyCount = ui.suggestions.filter(s => String(s).startsWith('(history)')).length;
  const tagCount = ui.suggestions.filter(
    s => typeof s === 'string' && !String(s).startsWith('(history)') && !String(s).includes('-----------'),
  ).length;

  expect(historyCount).toBe(9);
  expect(tagCount).toBe(1);
});
