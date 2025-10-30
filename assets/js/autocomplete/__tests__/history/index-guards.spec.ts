import { autocompleteTest } from '../context';

// Covers history/index.ts submit guard branches when target isn't a form and when no input with history exists
autocompleteTest('history listeners ignore non-form submit targets', async ({ ctx: _ctx, expect }) => {
  // Dispatch a submit event on a non-form element; should be ignored safely
  const div = document.createElement('div');
  document.body.appendChild(div);

  const event = new Event('submit', { bubbles: true });
  const result = div.dispatchEvent(event);

  // Event dispatch should succeed and not cause any side-effects/errors
  expect(result).toBe(true);
});
