import { autocompleteTest } from './context';
import { fireEvent } from '@testing-library/dom';

// Covers onKeyDown early return when event target is not the active input
autocompleteTest('keydown events on other targets are ignored', async ({ ctx, expect }) => {
  await ctx.focusInput();

  // Keydown on body (not the input) should be ignored by AC
  fireEvent.keyDown(document.body, { code: 'ArrowDown' });
  await vi.runAllTimersAsync();

  // No suggestions appear and input unchanged
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "",
      "suggestions": [],
    }
  `);
});
