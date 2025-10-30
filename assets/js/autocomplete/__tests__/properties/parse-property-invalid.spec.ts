import { autocompleteTest } from '../context';

// Covers the parsePropertyParts null branch (line 85) via matchProperties early return
autocompleteTest('invalid property syntax returns no suggestions', async ({ ctx, expect }) => {
  // Create an input with properties autocomplete type
  document.body.innerHTML = `
    <form>
      <input
        name="q"
        data-autocomplete="properties"
        data-autocomplete-condition="enable_search_ac"
      />
    </form>
  `;

  await ctx.focusInput();

  // Type invalid patterns that won't match the property regex
  await ctx.setInput('123invalid');
  expect(ctx.snapUi().suggestions).toEqual([]);

  await ctx.setInput('UPPERCASE');
  expect(ctx.snapUi().suggestions).toEqual([]);

  await ctx.setInput('special@char');
  expect(ctx.snapUi().suggestions).toEqual([]);

  await ctx.setInput(' leadingspace');
  expect(ctx.snapUi().suggestions).toEqual([]);
});
