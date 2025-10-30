import { autocompleteTest } from '../context';

autocompleteTest('does not fetch server suggestions when property value is being typed', async ({ ctx, expect }) => {
  await ctx.setName('q');

  // Type a property with a value (contains colon) to trigger the skip logic
  await ctx.setInput('tag_count:10');

  // Only the initial index fetch should have happened
  expect(fetch).toHaveBeenCalledTimes(1);

  // Property suggestions are shown locally and should not trigger a server fetch
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "tag_count:10<>",
      "suggestions": [
        "(property) tag_count:10",
        "(property) tag_count.gt:10",
        "(property) tag_count.gte:10",
        "(property) tag_count.lt:10",
        "(property) tag_count.lte:10",
      ],
    }
  `);
});
