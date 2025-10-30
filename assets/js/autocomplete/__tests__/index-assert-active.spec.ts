import { autocompleteTest } from './context';
import store from '../../utils/store';

// Covers assertActive() unhappy path by disabling autocomplete right before confirming a suggestion
// We capture the thrown error via window.onerror to avoid an unhandled exception terminating the test run.
autocompleteTest('clicking a suggestion while AC disabled triggers assertActive error', async ({ ctx, expect }) => {
  await ctx.focusInput();

  // Show some tag suggestions
  await ctx.setInput('mar');

  // Disable autocomplete between rendering and click to force inactive state
  store.set('enable_search_ac', false);

  const firstItem = document.querySelector('.autocomplete .autocomplete__item');
  expect(firstItem).not.toBeNull();

  // Capture the error thrown by assertActive during the click handler
  const errorPromise = new Promise<string>(resolve => {
    const handler = (event: ErrorEvent) => {
      // Prevent Vitest from treating this as an unhandled error
      event.preventDefault();
      window.removeEventListener('error', handler);
      resolve(String(event.error?.message || event.message || ''));
    };
    window.addEventListener('error', handler);
  });

  if (firstItem) {
    firstItem.dispatchEvent(new MouseEvent('click', { bubbles: true }));
  }

  const message = await errorPromise;
  expect(message).toMatch(/BUG: expected autocomplete to be active/);
});
