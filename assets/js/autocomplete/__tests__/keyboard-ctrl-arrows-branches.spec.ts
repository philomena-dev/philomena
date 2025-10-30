import { autocompleteTest } from './context';

// Covers the event.ctrlKey branches in ArrowUp/ArrowDown handling (lines 338, 346, 354)
autocompleteTest('Ctrl+ArrowDown and Ctrl+ArrowUp navigate selections', async ({ ctx, expect }) => {
  await ctx.setInput('f');

  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "f<>",
      "suggestions": [
        "forest  3",
        "force field  1",
        "fog  1",
        "flower  1",
      ],
    }
  `);

  // Ctrl+ArrowDown should call selectCtrlDown (jumps to last item since all are same type)
  await ctx.keyDown('ArrowDown', { key: 'ArrowDown', ctrlKey: true });

  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "flower<>",
      "suggestions": [
        "forest  3",
        "force field  1",
        "fog  1",
        "👉 flower  1",
      ],
    }
  `);

  // Ctrl+ArrowUp should call selectCtrlUp (jumps to first item since all are same type)
  await ctx.keyDown('ArrowUp', { key: 'ArrowUp', ctrlKey: true });

  // Should jump to first item
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "forest<>",
      "suggestions": [
        "👉 forest  3",
        "force field  1",
        "fog  1",
        "flower  1",
      ],
    }
  `);
});
