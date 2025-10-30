import { beforeEach, afterEach, expect, test, vi } from 'vitest';
import { listenAutocomplete } from '../index';
import { AutocompletableInput } from '../input';
import store from '../../utils/store';

const enableKey = 'enable_search_ac';

let originalFromElement: typeof AutocompletableInput.fromElement;

beforeEach(() => {
  // Ensure clean DOM and store before each test
  document.body.innerHTML = '';
  // Set global enable flag so inputs with conditions are considered enabled
  store.set(enableKey, true);
  originalFromElement = AutocompletableInput.fromElement;
});

afterEach(() => {
  // Restore original implementation
  AutocompletableInput.fromElement = originalFromElement;
  document.body.innerHTML = '';
});

test('refreshNativeAutocomplete continues when fromElement returns null', () => {
  // Element A: valid autocompletable input that should be processed
  const a = document.createElement('input');
  a.name = 'q';
  a.value = '';
  a.setAttribute('data-autocomplete', 'properties');
  a.setAttribute('data-autocomplete-condition', enableKey);
  document.body.appendChild(a);

  // Element B: matches the query selector but we will force fromElement to return null for it
  const b = document.createElement('input');
  b.name = 'q';
  b.value = '';
  b.setAttribute('data-autocomplete', 'properties');
  b.setAttribute('data-autocomplete-condition', enableKey);
  document.body.appendChild(b);

  // Spy wrapper to return null for element B and delegate to the original for others
  const spy = vi.fn((el: unknown) => {
    if (el === b) return null;
    return originalFromElement.call(AutocompletableInput, el);
  });

  AutocompletableInput.fromElement = spy as unknown as typeof AutocompletableInput.fromElement;

  // This triggers initial refreshNativeAutocomplete() inside
  listenAutocomplete();

  // Assert fromElement was called for both elements plus once for active element resolution during initial refresh
  expect(spy).toHaveBeenCalledTimes(3);
  expect(spy).toHaveBeenCalledWith(a);
  expect(spy).toHaveBeenCalledWith(b);

  // Element A should have native autocomplete disabled (off) because isEnabled() is true
  expect(a.autocomplete).toBe('off');

  // Element B should be left untouched due to the `continue` branch. Default is empty string or browser default.
  // We only assert that we did not force it to 'off' here, which proves the code continued without touching it.
  expect(b.autocomplete).not.toBe('off');
});
