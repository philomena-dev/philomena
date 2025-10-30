import { autocompleteTest } from '../context';
import { fireEvent } from '@testing-library/dom';

autocompleteTest('focusin on inputs without historyId does nothing', async ({ ctx, expect }) => {
  const input = document.createElement('input');
  input.setAttribute('data-autocomplete', 'multi-tags');
  // No data-autocomplete-history-id attribute on purpose
  document.body.appendChild(input);

  // Focus the input to trigger focusin
  input.focus();
  fireEvent.focusIn(input);
  await vi.runAllTimersAsync();

  // Ensure the existing autocomplete state remains unaffected
  await ctx.setInput('');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "",
      "suggestions": [],
    }
  `);
});
