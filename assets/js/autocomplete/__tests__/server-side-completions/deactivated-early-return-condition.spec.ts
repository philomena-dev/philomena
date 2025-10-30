import { autocompleteTest } from '../context';
import store from '../../../utils/store';

// Covers scheduleServerSideSuggestions early exit when the component becomes inactive
// between scheduling and callback by flipping a custom condition key that doesn't trigger
// the global settings watcher (so the schedule isn't aborted).
autocompleteTest('server callback exits early if AC deactivated via custom condition key', async ({ ctx, expect }) => {
  // Force server scheduling by hiding local tag suggestions
  store.set('SERVER_SIDE_COMPLETIONS_ONLY', true);

  // Append a separate input that uses a custom condition key not watched by listenAutocomplete
  const form = document.querySelector('form')!;
  const input = document.createElement('input');
  input.className = 'alt-input';
  input.setAttribute('data-autocomplete', 'multi-tags');
  input.setAttribute('data-autocomplete-condition', 'custom_flag');
  form.appendChild(input);

  // Enable AC for the custom input and focus it
  store.set('custom_flag', true);
  input.focus();
  await vi.runAllTimersAsync();

  // Type a term that would schedule server-side suggestions
  input.value = 'mar';
  input.selectionStart = 3;
  input.selectionEnd = 3;
  input.dispatchEvent(new Event('input', { bubbles: true }));

  // Deactivate AC without triggering the settings watcher (no abort)
  // IMPORTANT: flip the flag before flushing timers so the scheduled callback
  // sees isActive() === false and exits early.
  store.set('custom_flag', false);

  // Let any debounced callbacks run
  await vi.runAllTimersAsync();

  // Snapshot should remain stable and not include any server tags
  // The popup should remain without server suggestions because the callback exited early
  const suggestions = ctx.snapSuggestions();
  expect(suggestions).toEqual([]);
});
