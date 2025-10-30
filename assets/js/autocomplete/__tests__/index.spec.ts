import { autocompleteTest } from './context';
import store from '../../utils/store';

autocompleteTest(
  'native autocomplete toggles with settings and unrelated keys are ignored',
  async ({ ctx, expect }) => {
    // Ensure context is initialized
    await ctx.focusInput();

    const input = document.querySelector<HTMLInputElement>('input.test-input');
    expect(input).not.toBeNull();

    // Initially enabled via context -> native autocomplete off
    expect(input!.autocomplete).toBe('off');

    // Changing an unrelated key should not trigger refresh path for native autocomplete
    store.set('some_unrelated_key', true);
    await vi.runAllTimersAsync();
    expect(input!.autocomplete).toBe('off');

    // Disabling the feature should switch native autocomplete back on
    store.set('enable_search_ac', false);
    await vi.runAllTimersAsync();
    expect(input!.autocomplete).toBe('on');

    // Re-enable again to ensure it flips back
    store.set('enable_search_ac', true);
    await vi.runAllTimersAsync();
    expect(input!.autocomplete).toBe('off');

    // Toggling an autocomplete* key should pass the filter and refresh
    store.set('autocomplete_search_history_hidden', true);
    await vi.runAllTimersAsync();
    expect(input!.autocomplete).toBe('off');
  },
);

// Keep one test per file when using TestContext to avoid shared DOM/listeners between tests.
