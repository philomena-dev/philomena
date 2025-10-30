import { autocompleteTest } from './context';

// Accepting a history suggestion via Enter should submit the form and hide the popup
autocompleteTest('accepting a history suggestion submits the form and hides popup', async ({ ctx, expect }) => {
  // Seed history
  await ctx.submitForm('foo');
  await ctx.submitForm('far');

  // Narrow to only one history match so the first selection is history
  await ctx.setInput('f');

  // Select the first suggestion (history: far)
  await ctx.keyDown('ArrowDown');

  // Spy on form submission
  const form = document.querySelector('form') as HTMLFormElement;
  const submitSpy = vi.spyOn(form, 'requestSubmit').mockImplementation(() => {});

  // Confirm via Enter (no ctrl/shift)
  await ctx.keyDown('Enter');

  expect(submitSpy).toHaveBeenCalledOnce();

  // Popup should be hidden after accepting
  const ui = ctx.snapUi();
  expect(ui.suggestions).toEqual([]);

  submitSpy.mockRestore();
});
