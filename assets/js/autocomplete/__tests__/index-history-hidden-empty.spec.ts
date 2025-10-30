import { autocompleteTest } from './context';
import store from '../../utils/store';

autocompleteTest('when history is hidden, empty input shows no suggestions', async ({ ctx, expect }) => {
  // Hide history entirely
  store.set('autocomplete_search_history_hidden', true);

  // Focus without typing; empty input should not show history due to hidden setting
  await ctx.focusInput();

  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "",
      "suggestions": [],
    }
  `);
});
