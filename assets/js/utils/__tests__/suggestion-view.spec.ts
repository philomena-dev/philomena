import {
  HistorySuggestionComponent,
  ItemSelection,
  PropertySuggestionComponent,
  Suggestion,
  Suggestions,
  SuggestionsPopupComponent,
  TagSuggestionComponent,
} from '../suggestions-view.ts';
import { TagSuggestion } from 'utils/suggestions-model.ts';
import { afterEach, expect } from 'vitest';
import { fireEvent } from '@testing-library/dom';
import { assertNotNull } from '../assert.ts';
import { $, $$ } from '../dom.ts';
import { literalProperty, numericProperty } from '../../autocomplete/properties/maps';
import { MatchedPropertyParts, SuggestedProperty } from '../../autocomplete/properties';

const mockedMatchedPropertyParts: MatchedPropertyParts = {
  propertyName: 's',
  hasOperatorSyntax: false,
  hasValueSyntax: false,
};

const mockedSuggestions: Suggestions = {
  history: ['foo bar', 'bar baz', 'baz qux'].map(content => new HistorySuggestionComponent(content, 0)),
  tags: [
    { images: 10, canonical: ['artist:assasinmonkey'] },
    { images: 10, canonical: ['artist:hydrusbeta'] },
    { images: 10, canonical: ['artist:the sexy assistant'] },
    { images: 10, canonical: ['artist:devinian'] },
    { images: 10, canonical: ['artist:moe'] },
  ].map(suggestion => new TagSuggestionComponent(suggestion)),
  properties: [
    new SuggestedProperty(mockedMatchedPropertyParts, 'score', numericProperty, null, null),
    new SuggestedProperty(mockedMatchedPropertyParts, 'sha512_hash', literalProperty, null, null),
    new SuggestedProperty(mockedMatchedPropertyParts, 'size', numericProperty, null, null),
    new SuggestedProperty(mockedMatchedPropertyParts, 'source_count', numericProperty, null, null),
    new SuggestedProperty(mockedMatchedPropertyParts, 'source_url', literalProperty, null, null),
  ].map(property => new PropertySuggestionComponent(property)),
};

function mockBaseSuggestionsPopup(includeMockedSuggestions = false): [SuggestionsPopupComponent, HTMLInputElement] {
  const input = document.createElement('input');
  const popup = new SuggestionsPopupComponent();

  if (includeMockedSuggestions) {
    popup.setSuggestions(mockedSuggestions);
  }

  document.body.append(input);
  popup.showForElement(input);

  return [popup, input];
}

const selectedItemClassName = 'highlighted';

const { history, tags } = mockedSuggestions;
const item = (index: number) => $$<HTMLElement>('.combobox-suggestion-item')[index];

describe('Suggestions', () => {
  let popup: SuggestionsPopupComponent | undefined;
  let input: HTMLInputElement | undefined;

  afterEach(() => {
    if (input) {
      input.remove();
      input = undefined;
    }

    if (popup) {
      popup.hide();
      popup.setSuggestions({ history: [], tags: [], properties: [] });
      popup = undefined;

      // Make sure we clean up leftover popups, just so we only have one instance at a time.
      for (const popupElement of $$<HTMLElement>('.autocomplete')) {
        popupElement.remove();
      }
    }
  });

  describe('SuggestionsPopup', () => {
    it('should create the popup container', () => {
      [popup, input] = mockBaseSuggestionsPopup();

      expect($<HTMLElement>('.autocomplete')).toBeInstanceOf(HTMLElement);
      assert(popup.isHidden);
    });

    it('should hide the popup when there are no suggestions to show', () => {
      [popup, input] = mockBaseSuggestionsPopup();

      popup.setSuggestions({ history: [], tags: [], properties: [] });
      popup.showForElement(input);

      assert(popup.isHidden);
    });

    it('should render suggestions', () => {
      [popup, input] = mockBaseSuggestionsPopup(true);

      expect($$<HTMLElement>('.combobox-suggestion-item').length).toBe(
        mockedSuggestions.history.length + mockedSuggestions.tags.length + mockedSuggestions.properties.length,
      );
    });

    it('should be placed under the field in page coordinates, wherever the page and the field scrolled', () => {
      [popup, input] = mockBaseSuggestionsPopup(true);

      const popupContainer = assertNotNull($<HTMLElement>('.autocomplete'));

      vi.spyOn(input, 'getBoundingClientRect').mockReturnValue({ left: 30, bottom: 50 } as DOMRect);
      vi.stubGlobal('scrollX', 5);
      vi.stubGlobal('scrollY', 100);
      popup.showForElement(input);

      expect(popupContainer.style.left).toBe('35px');
      expect(popupContainer.style.top).toBe('150px');

      vi.unstubAllGlobals();
    });

    it('should not be displayed when input is detached from document', () => {
      [popup, input] = mockBaseSuggestionsPopup(true);

      assert(!popup.isHidden);

      input.remove();
      popup.showForElement(input);

      assert(popup.isHidden);
    });

    it('should initially select first element when selectDown is called', () => {
      [popup, input] = mockBaseSuggestionsPopup(true);

      popup.selectDown();

      expect($<HTMLElement>('.combobox-suggestion-item:first-child')).toHaveClass(selectedItemClassName);
    });

    it('should initially select last element when selectUp is called', () => {
      [popup, input] = mockBaseSuggestionsPopup(true);

      popup.selectUp();

      expect($<HTMLElement>('.combobox-suggestion-item:last-child')).toHaveClass(selectedItemClassName);
    });

    it('should jump to the next lower block when selectCtrlDown is called', () => {
      [popup, input] = mockBaseSuggestionsPopup(true);

      popup.selectCtrlDown();

      expect(popup.selectedSuggestion).toBe(mockedSuggestions.tags[0]);
      expect(item(history.length)).toHaveClass(selectedItemClassName);

      popup.selectCtrlDown();

      expect(popup.selectedSuggestion).toBe(mockedSuggestions.properties[0]);
      expect(item(history.length + tags.length)).toHaveClass(selectedItemClassName);

      popup.selectCtrlDown();

      expect(popup.selectedSuggestion).toBe(mockedSuggestions.properties[mockedSuggestions.properties.length - 1]);
      expect($<HTMLElement>('.combobox-suggestion-item:last-child')).toHaveClass(selectedItemClassName);

      // Should loop around
      popup.selectCtrlDown();
      expect(popup.selectedSuggestion).toBe(mockedSuggestions.history[0]);
      expect($<HTMLElement>('.combobox-suggestion-item:first-child')).toHaveClass(selectedItemClassName);
    });

    it('should jump to the next upper block when selectCtrlUp is called', () => {
      [popup, input] = mockBaseSuggestionsPopup(true);

      popup.selectCtrlUp();

      expect(popup.selectedSuggestion).toBe(mockedSuggestions.properties[mockedSuggestions.properties.length - 1]);
      expect($<HTMLElement>('.combobox-suggestion-item:last-child')).toHaveClass(selectedItemClassName);

      popup.selectCtrlUp();

      expect(popup.selectedSuggestion).toBe(mockedSuggestions.tags[mockedSuggestions.tags.length - 1]);
      expect(item(history.length + tags.length - 1)).toHaveClass(selectedItemClassName);

      popup.selectCtrlUp();

      expect(popup.selectedSuggestion).toBe(mockedSuggestions.history[mockedSuggestions.history.length - 1]);
      expect($<HTMLElement>(`.autocomplete-history:nth-child(${mockedSuggestions.history.length})`)).toHaveClass(
        selectedItemClassName,
      );

      popup.selectCtrlUp();

      expect(popup.selectedSuggestion).toBe(mockedSuggestions.history[0]);
      expect($<HTMLElement>('.combobox-suggestion-item:first-child')).toHaveClass(selectedItemClassName);

      // Should loop around
      popup.selectCtrlUp();

      expect(popup.selectedSuggestion).toBe(mockedSuggestions.properties[mockedSuggestions.properties.length - 1]);
      expect($<HTMLElement>('.combobox-suggestion-item:last-child')).toHaveClass(selectedItemClassName);
    });

    it('should do nothing on selection changes when empty', () => {
      [popup, input] = mockBaseSuggestionsPopup();

      popup.selectDown();
      popup.selectUp();
      popup.selectCtrlDown();
      popup.selectCtrlUp();

      expect($<HTMLElement>(`.${selectedItemClassName}`)).toBeNull();
    });

    it('should loop around when selecting next on last and previous on first', () => {
      [popup, input] = mockBaseSuggestionsPopup(true);

      const firstItem = assertNotNull($<HTMLElement>('.combobox-suggestion-item:first-child'));
      const lastItem = assertNotNull($<HTMLElement>('.combobox-suggestion-item:last-child'));

      popup.selectUp();

      expect(lastItem).toHaveClass(selectedItemClassName);

      popup.selectDown();

      expect($<HTMLElement>(`.${selectedItemClassName}`)).toBeNull();

      popup.selectDown();

      expect(firstItem).toHaveClass(selectedItemClassName);

      popup.selectUp();

      expect($<HTMLElement>(`.${selectedItemClassName}`)).toBeNull();

      popup.selectUp();

      expect(lastItem).toHaveClass(selectedItemClassName);
    });

    it('should return selected item value', () => {
      [popup, input] = mockBaseSuggestionsPopup(true);

      expect(popup.selectedSuggestion).toBe(null);

      popup.selectDown();

      expect(popup.selectedSuggestion).toBe(mockedSuggestions.history[0]);
    });

    it('should emit an event when an item was clicked with a mouse', () => {
      [popup, input] = mockBaseSuggestionsPopup(true);

      const itemSelectedHandler = vi.fn<(event: ItemSelection) => void>();

      popup.onItemSelected(itemSelectedHandler);

      const firstItem = assertNotNull($<HTMLElement>('.combobox-suggestion-item'));

      fireEvent.click(firstItem);

      expect(itemSelectedHandler).toBeCalledTimes(1);
      expect(itemSelectedHandler).toBeCalledWith({
        ctrlKey: false,
        shiftKey: false,
        suggestion: mockedSuggestions.history[0],
      });
    });
  });

  describe('HistorySuggestion', () => {
    it('should render the suggestion', () => {
      expectHistoryRender('foo bar').toMatchInlineSnapshot(`
        {
          "label": "<mark></mark>foo bar",
          "value": "foo bar",
        }
      `);
    });
  });

  describe('TagSuggestion', () => {
    it('should format suggested tags as tag name and the count', () => {
      expectTagRender({ canonical: ['safe'], images: 10 }).toMatchInlineSnapshot(`
        {
          "label": "safe | 10",
          "value": "safe",
        }
      `);
      expectTagRender({ canonical: ['safe'], images: 10_000 }).toMatchInlineSnapshot(`
        {
          "label": "safe | 10 000",
          "value": "safe",
        }
      `);
      expectTagRender({ canonical: ['safe'], images: 100_000 }).toMatchInlineSnapshot(`
        {
          "label": "safe | 100 000",
          "value": "safe",
        }
      `);
      expectTagRender({ canonical: ['safe'], images: 1000_000 }).toMatchInlineSnapshot(`
        {
          "label": "safe | 1 000 000",
          "value": "safe",
        }
      `);
      expectTagRender({ canonical: ['safe'], images: 10_000_000 }).toMatchInlineSnapshot(`
        {
          "label": "safe | 10 000 000",
          "value": "safe",
        }
      `);
    });

    it('should display alias -> canonical for aliased tags', () => {
      expectTagRender({ images: 10, canonical: 'safe', alias: ['rating:safe'] }).toMatchInlineSnapshot(
        `
        {
          "label": "rating:safe → safe | 10",
          "value": "safe",
        }
      `,
      );
    });

    it('should display alias -> canonical for aliased tags with match parts', () => {
      expectTagRender({ images: 10, canonical: 'rating:safe', alias: [{ matched: 'safe' }] }).toMatchInlineSnapshot(
        `
        {
          "label": "<mark>safe</mark> → rating:safe | 10",
          "value": "rating:safe",
        }
      `,
      );
    });
  });

  describe('PropertySuggestion', () => {
    it('should render the suggestion', () => {
      const property = new SuggestedProperty(
        {
          propertyName: 'score',
          hasOperatorSyntax: false,
          hasValueSyntax: false,
        },
        'score',
        numericProperty,
      );

      expectPropertyRender(property).toMatchInlineSnapshot(`
        {
          "label": "<mark>score</mark>",
          "value": "score",
        }
      `);
    });

    it('should highlight matched part of the property', () => {
      const property = new SuggestedProperty(
        {
          propertyName: 'first_seen_at',
          hasValueSyntax: false,
          hasOperatorSyntax: false,
        },
        'first_seen_at',
        literalProperty,
        null,
        // Value is hypothetical, we don't have suggestions of that kind at the moment of writing the test, but we need
        // to check how both value and operator are working together.
        '3 days ago',
      );

      expectPropertyRender(property).toMatchInlineSnapshot(`
        {
          "label": "<mark>first_seen_at</mark>:3 days ago",
          "value": "first_seen_at:3 days ago",
        }
      `);

      // Should also highlight the colon if value syntax was typed by the user.
      property.matchedParts.hasValueSyntax = true;
      expectPropertyRender(property).toMatchInlineSnapshot(`
        {
          "label": "<mark>first_seen_at:</mark>3 days ago",
          "value": "first_seen_at:3 days ago",
        }
      `);

      // And then it should start highlighting the value.
      property.matchedParts.value = '3 days';
      expectPropertyRender(property).toMatchInlineSnapshot(`
        {
          "label": "<mark>first_seen_at:3 days</mark> ago",
          "value": "first_seen_at:3 days ago",
        }
      `);

      // Now check when operator is suggested but not typed yet
      property.matchedParts.hasValueSyntax = false;
      property.matchedParts.value = undefined;
      property.operator = 'gte';
      expectPropertyRender(property).toMatchInlineSnapshot(`
        {
          "label": "<mark>first_seen_at</mark>.gte:3 days ago",
          "value": "first_seen_at.gte:3 days ago",
        }
      `);

      // And when operator syntax is typed by the user.
      property.matchedParts.hasOperatorSyntax = true;
      expectPropertyRender(property).toMatchInlineSnapshot(`
        {
          "label": "<mark>first_seen_at.</mark>gte:3 days ago",
          "value": "first_seen_at.gte:3 days ago",
        }
      `);

      // And when user started typing the operator itself.
      property.matchedParts.operator = 'gt';
      expectPropertyRender(property).toMatchInlineSnapshot(`
        {
          "label": "<mark>first_seen_at.gt</mark>e:3 days ago",
          "value": "first_seen_at.gte:3 days ago",
        }
      `);

      // And when both operator and value are present.
      property.matchedParts.hasValueSyntax = true;
      property.matchedParts.value = '3 days';
      property.matchedParts.operator = 'gte';
      expectPropertyRender(property).toMatchInlineSnapshot(`
        {
          "label": "<mark>first_seen_at.gte:3 days</mark> ago",
          "value": "first_seen_at.gte:3 days ago",
        }
      `);
    });

    it('should render colon and dot for operators and values', () => {
      const property = new SuggestedProperty(
        {
          propertyName: 'score',
          hasOperatorSyntax: false,
          hasValueSyntax: false,
        },
        'score',
        numericProperty,
      );

      // No value or operator.
      expectPropertyRender(property).toMatchInlineSnapshot(`
        {
          "label": "<mark>score</mark>",
          "value": "score",
        }
      `);

      // Only operator is provided.
      property.operator = 'gt';
      expectPropertyRender(property).toMatchInlineSnapshot(`
        {
          "label": "<mark>score</mark>.gt:",
          "value": "score.gt:",
        }
      `);

      // Both value and operator are provided.
      property.value = '100';
      expectPropertyRender(property).toMatchInlineSnapshot(`
        {
          "label": "<mark>score</mark>.gt:100",
          "value": "score.gt:100",
        }
      `);

      // Only value is provided.
      property.operator = null;
      expectPropertyRender(property).toMatchInlineSnapshot(`
        {
          "label": "<mark>score</mark>:100",
          "value": "score:100",
        }
      `);
    });
  });
});

// The text of a rendered suggestion and its addon, the highlighted parts marked
function renderedLabel(suggestion: Suggestion) {
  const [label] = suggestion.render();
  const text = assertNotNull(label.querySelector('.combobox-suggestion-item-main-text'));
  const addon = label.querySelector('.combobox-suggestion-item-addon')?.textContent;
  const parts = [...text.childNodes].map(node =>
    node.nodeName === 'MARK' ? `<mark>${node.textContent}</mark>` : node.textContent,
  );

  return [parts.join(''), addon].filter(Boolean).join(' | ');
}

function expectHistoryRender(content: string) {
  const suggestion = new HistorySuggestionComponent(content, 0);

  return expect({ label: renderedLabel(suggestion), value: suggestion.value() });
}

function expectTagRender(params: TagSuggestion) {
  const suggestion = new TagSuggestionComponent(params);

  return expect({ label: renderedLabel(suggestion), value: suggestion.value() });
}

function expectPropertyRender(property: SuggestedProperty) {
  const suggestion = new PropertySuggestionComponent(property);

  return expect({ label: renderedLabel(suggestion), value: suggestion.value() });
}
