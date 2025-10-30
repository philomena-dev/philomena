import { autocompleteTest } from './context';
import { AutocompletableInput } from '../input';

// Documents behavior: lexer strips leading dash in multi-tags; prefix stays empty
autocompleteTest('multi-tags term does not use removal prefix', async ({ ctx, expect }) => {
  // Type a value with a leading dash and place the cursor at the end
  await ctx.setInput('-for<>');

  // Read the parsed snapshot directly
  const input = AutocompletableInput.fromElement(document.activeElement);
  expect(input).not.toBeNull();

  const snapshot = (input as AutocompletableInput).snapshot;
  expect(snapshot.activeTerm).not.toBeNull();

  // In multi-tags mode the dash is not treated as a removal prefix (prefix stays empty),
  // and the lexer normalizes the term without the dash.
  expect(snapshot.activeTerm!.prefix).toBe('');
  expect(snapshot.activeTerm!.term).toBe('for');
});
