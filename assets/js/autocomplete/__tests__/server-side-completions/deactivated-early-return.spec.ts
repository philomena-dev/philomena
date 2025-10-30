import { autocompleteTest } from '../context';
import { fireEvent } from '@testing-library/dom';

autocompleteTest('scheduled server callback exits early when autocomplete is inactive', async ({ ctx, expect }) => {
  // Trigger a schedule for server-side suggestions
  await ctx.setInput('mar');

  // Deactivate autocomplete before the scheduled callback runs
  fireEvent.click(document.body);

  // Flush timers to let any scheduled callbacks try to run
  await vi.runAllTimersAsync();

  // Autocomplete should remain hidden (no suggestions shown)
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "mar<>",
      "suggestions": [],
    }
  `);
});
