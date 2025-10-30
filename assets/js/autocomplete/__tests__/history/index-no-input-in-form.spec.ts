import { autocompleteTest } from '../context';

autocompleteTest('history submit handler ignores forms without autocomplete inputs', async ({ ctx, expect }) => {
  // Create a separate form without any autocomplete-capable inputs
  const form = document.createElement('form');
  document.body.appendChild(form);

  // Submitting this form should not throw and should not affect suggestions
  form.submit();
  await ctx.setInput('');

  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "",
      "suggestions": [],
    }
  `);
});
