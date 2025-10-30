import { autocompleteTest } from './context';
import * as dom from '../../utils/dom';
import store from '../../utils/store';

// Ensure store.watchAll guard returns early for unrelated keys (no refreshes happen)
autocompleteTest('settings watcher ignores unrelated keys', async ({ expect }) => {
  const spy = vi.spyOn(dom, '$$');

  // Use a key that isn't 'enable_search_ac' and doesn't start with 'autocomplete'
  store.set('unrelated_key_xyz', 123);

  // Should not have been called from refreshNativeAutocomplete
  expect(spy).not.toHaveBeenCalled();

  spy.mockRestore();
});
