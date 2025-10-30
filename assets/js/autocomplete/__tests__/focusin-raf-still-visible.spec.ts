import { autocompleteTest } from './context';
import { fireEvent } from '@testing-library/dom';

// Covers the deferred refresh path in onFocusIn where the popup becomes visible before rAF runs
autocompleteTest('focusin deferred refresh cancels if popup becomes visible before rAF', async ({ ctx, expect }) => {
  // Ensure popup is hidden initially
  expect(ctx.snapUi().suggestions).toEqual([]);

  // Trigger focusin which schedules a rAF refresh
  fireEvent.focusIn(document);

  // Before rAF callback runs, make popup visible (simulate user interaction making it visible)
  const popup = document.querySelector('.autocomplete') as HTMLElement;
  popup.classList.remove('hidden');

  // Flush timers (includes rAF)
  await vi.runAllTimersAsync();

  // Popup remains visible (no extra refresh hid it)
  expect(popup.classList.contains('hidden')).toBe(false);
});
