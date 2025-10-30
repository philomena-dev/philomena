import { autocompleteTest } from '../context';
import store from '../../../utils/store';
import { fireEvent } from '@testing-library/dom';

// Covers scheduleServerSideSuggestions early exit when the component becomes inactive
// between scheduling and callback (with SERVER_SIDE_COMPLETIONS_ONLY to force scheduling)
autocompleteTest('server callback exits early if AC deactivated (flag forces schedule)', async ({ ctx, expect }) => {
  // Force local tag suggestions to be hidden so server scheduling happens
  store.set('SERVER_SIDE_COMPLETIONS_ONLY', true);

  await ctx.setInput('mar');

  // Deactivate by clicking away before the scheduled callback runs
  fireEvent.click(document.body);

  // Flush timers to run any scheduled callbacks
  await vi.runAllTimersAsync();

  // No suggestions should be shown as AC is inactive
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "mar<>",
      "suggestions": [],
    }
  `);
});
