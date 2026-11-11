import { makeEl } from './dom.ts';
import { MatchPart, TagSuggestion } from './suggestions-model.ts';
import { SuggestedProperty } from '../autocomplete/properties';

/** The label of a suggestion item: an icon, the text and an optional addon at its end */
function itemLabel(icon: string, text: (HTMLElement | string)[], addon?: HTMLElement): HTMLElement[] {
  return [
    makeEl('div', { className: 'combobox-suggestion-item-label' }, [
      makeEl('i', { className: `fa-solid ${icon}` }),
      makeEl('span', { className: 'combobox-suggestion-item-text' }, [
        makeEl('span', { className: 'combobox-suggestion-item-main-text' }, text),
      ]),
      ...(addon ? [addon] : []),
    ]),
  ];
}

interface SuggestionComponent {
  readonly type: string;

  value(): string;

  render(): HTMLElement[];
}

export class TagSuggestionComponent implements SuggestionComponent {
  readonly type = 'tag';
  data: TagSuggestion;

  constructor(data: TagSuggestion) {
    this.data = data;
  }

  value(): string {
    if (typeof this.data.canonical === 'string') {
      return this.data.canonical;
    }

    return this.data.canonical.map(part => (typeof part === 'string' ? part : part.matched)).join('');
  }

  render(): HTMLElement[] {
    return itemLabel(
      'fa-tag',
      this.renderLabel(),
      makeEl('span', {
        className: 'combobox-suggestion-item-addon',
        textContent: TagSuggestionComponent.renderImageCount(this.data.images),
      }),
    );
  }

  renderLabel(): (HTMLElement | string)[] {
    const { data } = this;

    if (!data.alias) {
      return TagSuggestionComponent.renderMatchParts(data.canonical);
    }

    return [...TagSuggestionComponent.renderMatchParts(data.alias), ` → ${data.canonical}`];
  }

  static renderMatchParts(parts: MatchPart[]): (HTMLElement | string)[] {
    return parts.map(part => {
      if (typeof part === 'string') {
        return part;
      }

      return makeEl('mark', { textContent: part.matched });
    });
  }

  static renderImageCount(count: number): string {
    // The old implementation here was using new Intl.NumberFormat('fr'), but we
    // moved to a manual impl here to avoid platform-specific differences in
    // `Intl` implementation. It depends on the ICU package availability.
    const chars = [...count.toString()];

    for (let i = chars.length - 3; i > 0; i -= 3) {
      chars.splice(i, 0, ' ');
    }

    return chars.join('');
  }
}

export class HistorySuggestionComponent implements SuggestionComponent {
  readonly type = 'history';

  /**
   * Full query string that was previously searched and retrieved from the history.
   */
  content: string;

  /**
   * Length of the prefix in the suggestion that matches the prefix of the current input.
   */
  matchLength: number;

  constructor(content: string, matchIndex: number) {
    this.content = content;
    this.matchLength = matchIndex;
  }

  value(): string {
    return this.content;
  }

  render(): HTMLElement[] {
    return itemLabel(
      'fa-history',
      [makeEl('mark', { textContent: this.content.slice(0, this.matchLength) }), this.content.slice(this.matchLength)],
      makeEl(
        'span',
        { className: 'combobox-suggestion-item-addon autocomplete-history-delete', title: 'Delete this history item' },
        [makeEl('i', { className: 'fa-solid fa-xmark' })],
      ),
    );
  }
}

export class PropertySuggestionComponent implements SuggestionComponent {
  readonly type = 'property';
  suggestion: SuggestedProperty;

  constructor(content: SuggestedProperty) {
    this.suggestion = content;
  }

  value(): string {
    return this.suggestion.toString();
  }

  render(): HTMLElement[] {
    return itemLabel('fa-circle-info', this.#renderSuggestionWithHighlighting());
  }

  #renderSuggestionWithHighlighting(): (HTMLElement | string)[] {
    const renderedSuggestion = this.value();
    const matchedLength = this.suggestion.calculateMatchedLength();

    const resultElements: (HTMLElement | string)[] = [
      makeEl('mark', { textContent: renderedSuggestion.slice(0, matchedLength) }),
    ];

    if (matchedLength !== renderedSuggestion.length) {
      resultElements.push(renderedSuggestion.slice(matchedLength));
    }

    return resultElements;
  }
}

export type Suggestion = TagSuggestionComponent | HistorySuggestionComponent | PropertySuggestionComponent;

export interface Suggestions {
  history: HistorySuggestionComponent[];
  tags: TagSuggestionComponent[];
  properties: PropertySuggestionComponent[];
}

export interface ItemSelection {
  suggestion: Suggestion;
  shiftKey: boolean;
  ctrlKey: boolean;
}

interface SuggestionItem {
  element: HTMLElement;
  suggestion: Suggestion;
}

export interface HistoryItemDeleteDetail {
  suggestion: HistorySuggestionComponent;
  clickEvent: PointerEvent;
}

declare global {
  interface ItemSelectedEvent extends CustomEvent<ItemSelection> {
    target: HTMLElement;
  }

  interface HistoryItemDeleteEvent extends CustomEvent<HistoryItemDeleteDetail> {
    target: HTMLElement;
  }

  interface GlobalEventHandlersEventMap {
    itemselected: ItemSelectedEvent;
    historyitemdelete: HistoryItemDeleteEvent;
  }
}

/**
 * Responsible for rendering the suggestions dropdown.
 */
export class SuggestionsPopupComponent {
  /**
   * Index of the currently selected suggestion. -1 means an imaginary item
   * before the first item that represents the state where no item is selected.
   */
  private cursor = -1;
  private items: SuggestionItem[];
  private readonly container: HTMLElement;

  constructor() {
    this.container = makeEl('div', {
      className: 'combobox-suggestions autocomplete hidden',
      tabIndex: -1,
    });

    document.body.appendChild(this.container);
    this.items = [];
  }

  get selectedSuggestion(): Suggestion | null {
    return this.selectedItem?.suggestion ?? null;
  }

  private get selectedItem(): SuggestionItem | null {
    if (this.cursor < 0) {
      return null;
    }

    return this.items[this.cursor];
  }

  get isHidden(): boolean {
    return this.container.classList.contains('hidden');
  }

  hide() {
    this.clearSelection();
    this.container.classList.add('hidden');
  }

  private clearSelection() {
    this.setSelection(-1);
  }

  private setSelection(index: number) {
    if (this.cursor === index) {
      return;
    }

    this.selectedItem?.element.classList.remove('highlighted');
    this.cursor = index;

    if (index >= 0) {
      this.selectedItem?.element.classList.add('highlighted');
    }
  }

  setSuggestions(params: Suggestions): SuggestionsPopupComponent {
    this.cursor = -1;
    this.items = [];
    this.container.innerHTML = '';

    for (const suggestion of params.history) {
      this.appendSuggestion(suggestion);
    }

    if (params.tags.length > 0 && params.history.length > 0) {
      this.container.appendChild(makeEl('hr', { className: 'autocomplete-separator' }));
    }

    for (const suggestion of params.tags) {
      this.appendSuggestion(suggestion);
    }

    if ((params.tags.length || params.history.length) && params.properties.length) {
      this.container.appendChild(makeEl('hr', { className: 'autocomplete-separator' }));
    }

    for (const suggestion of params.properties) {
      this.appendSuggestion(suggestion);
    }

    return this;
  }

  private appendSuggestion(suggestion: Suggestion) {
    const element = makeEl('div', { className: 'combobox-suggestion-item' }, suggestion.render());
    element.classList.toggle('autocomplete-history', suggestion.type === 'history');

    const item: SuggestionItem = { element, suggestion };

    this.watchItem(item);

    this.items.push(item);
    this.container.appendChild(element);
  }

  private watchItem(item: SuggestionItem) {
    item.element.addEventListener('click', event => {
      if (
        item.suggestion.type === 'history' &&
        event.target instanceof HTMLElement &&
        event.target.closest('.autocomplete-history-delete')
      ) {
        const detail: HistoryItemDeleteDetail = {
          suggestion: item.suggestion,
          clickEvent: event,
        };
        this.container.dispatchEvent(new CustomEvent('historyitemdelete', { detail }));
        return;
      }

      const detail: ItemSelection = {
        suggestion: item.suggestion,
        shiftKey: event.shiftKey,
        ctrlKey: event.ctrlKey,
      };

      this.container.dispatchEvent(new CustomEvent('itemselected', { detail }));
    });
  }

  private changeSelection(direction: number) {
    if (this.items.length === 0) {
      return;
    }

    const index = this.cursor + direction;

    if (index === -1 || index >= this.items.length) {
      this.clearSelection();
    } else if (index < -1) {
      this.setSelection(this.items.length - 1);
    } else {
      this.setSelection(index);
    }
  }

  selectDown() {
    this.changeSelection(1);
  }

  selectUp() {
    this.changeSelection(-1);
  }

  /**
   * The user wants to jump to the next lower block of types of suggestions.
   */
  selectCtrlDown() {
    if (this.items.length === 0) {
      return;
    }

    if (this.cursor >= this.items.length - 1) {
      this.setSelection(0);
      return;
    }

    let index = this.cursor + 1;
    const type = this.itemType(index);

    while (index < this.items.length - 1 && this.itemType(index) === type) {
      index += 1;
    }

    this.setSelection(index);
  }

  /**
   * The user wants to jump to the next upper block of types of suggestions.
   */
  selectCtrlUp() {
    if (this.items.length === 0) {
      return;
    }

    if (this.cursor <= 0) {
      this.setSelection(this.items.length - 1);
      return;
    }

    let index = this.cursor - 1;
    const type = this.itemType(index);

    while (index > 0 && this.itemType(index) === type) {
      index -= 1;
    }

    this.setSelection(index);
  }

  /**
   * Returns the item's prototype that can be viewed as the item's type identifier.
   */
  private itemType(index: number) {
    return this.items[index].suggestion.type;
  }

  showForElement(targetElement: HTMLElement) {
    if (!targetElement.isConnected || this.items.length === 0) {
      // Hide the popup because there are no suggestions to show. We have to do it
      // explicitly, because a border is still rendered even for an empty popup.
      // Also don't attempt to show the popup for disconnected node. Otherwise, it
      // will be shown out of place.
      this.hide();
      return;
    }

    // The popup is a child of the body, so it is placed in page coordinates
    const { left, bottom } = targetElement.getBoundingClientRect();

    this.container.style.left = `${left + window.scrollX}px`;
    this.container.style.top = `${bottom + window.scrollY}px`;
    this.container.classList.remove('hidden');
  }

  onItemSelected(callback: (event: ItemSelection) => void) {
    this.container.addEventListener('itemselected', event => {
      callback(event.detail);
    });
  }

  onHistoryItemDeleteClicked(callback: (detail: HistoryItemDeleteDetail) => void) {
    this.container.addEventListener('historyitemdelete', event => {
      callback(event.detail);
    });
  }
}
