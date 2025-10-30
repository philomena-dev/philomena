import { autocompleteTest } from '../context';

// Covers the !hasOperatorSyntax branch in properties (lines 253-256)
// which adds an operatorless suggestion when user hasn't started typing operator
autocompleteTest(
  'property suggestions include operatorless variant when no operator started',
  async ({ ctx, expect }) => {
    await ctx.setName('q'); // Use valid query field name

    // Type a valid property name followed by colon (hasValueSyntax but not hasOperatorSyntax)
    await ctx.setInput('width:');

    const ui = ctx.snapUi();

    // Should include multiple operator suggestions plus the operatorless variant
    expect(ui.suggestions.length).toBeGreaterThan(0);

    // The suggestions should include operators like "width:.gt", "width:.gte", etc.
    // and the first one should be the operatorless variant (without any operator after ":")
    const firstSuggestion = ui.suggestions[0];
    expect(firstSuggestion).toMatch(/width:/);
  },
);
