import { makeEl } from './dom.ts';
import { handleError } from './requests.ts';
import { LocalAutocompleter } from './local-autocompleter.ts';

export class TagSuggestion {
  /**
   * If present, then this suggestion is for a tag alias.
   * If absent, then this suggestion is for the `canonical` tag name.
   */
  aliasName?: string;

  /**
   * The canonical name of the tag (non-alias).
   */
  canonicalName: string;

  /**
   * Number of images tagged with this tag.
   */
  imageCount: number;

  /**
   * Length of the prefix in the suggestion that matches the prefix of the current input.
   */
  matchLength: number;

  constructor(props: { aliasName?: string; canonicalName: string; imageCount: number; matchLength: number }) {
    this.aliasName = props.aliasName;
    this.canonicalName = props.canonicalName;
    this.imageCount = props.imageCount;
    this.matchLength = props.matchLength;
  }

  value(): string {
    return this.canonicalName;
  }

  render(): HTMLElement[] {
    const { aliasName, canonicalName, imageCount } = this;

    const label = aliasName ? `${aliasName} → ${canonicalName}` : canonicalName;

    const prefix = makeEl('div');

    prefix.append(
      makeEl('i', {
        className: 'fa-solid fa-tag',
      }),
      makeEl('span', {
        textContent: ` ${label.slice(0, this.matchLength)}`,
        className: 'autocomplete-item-tag__match',
      }),
      makeEl('span', {
        textContent: label.slice(this.matchLength),
      }),
    );

    return [
      prefix,
      makeEl('span', {
        className: 'autocomplete-item-tag__count',
        textContent: ` ${imageCount}`,
      }),
    ];
  }
}

export class HistorySuggestion {
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
    return [
      makeEl('i', {
        className: 'autocomplete-item-history__icon fa-solid fa-history',
      }),
      makeEl('span', {
        textContent: ` ${this.content.slice(0, this.matchLength)}`,
        className: 'autocomplete-item-history__match',
      }),
      makeEl('span', {
        textContent: this.content.slice(this.matchLength),
      }),
    ];
  }
}

export type Suggestion = TagSuggestion | HistorySuggestion;

export interface Suggestions {
  history: HistorySuggestion[];
  tags: TagSuggestion[];
}

interface SuggestionItem {
  element: HTMLElement;
  suggestion: Suggestion;
}

/**
 * Responsible for rendering the suggestions dropdown.
 */
export class SuggestionsPopup {
  /**
   * Index of the currently selected suggestion. -1 means an imaginary item
   * before the first item that represents the state where no item is selected.
   */
  private cursor: number = -1;
  private items: SuggestionItem[];
  private readonly container: HTMLElement;

  constructor() {
    this.container = makeEl('div', {
      className: 'autocomplete hidden',
      tabIndex: -1,
    });

    // Make the container connected to DOM to make sure it's rendered when we unhide it
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

    if (index < -1 || index >= this.items.length) {
      throw new Error(`setSelection(): invalid selection index: ${index}`);
    }

    const selectedClass = 'autocomplete__item--selected';

    this.selectedItem?.element.classList.remove(selectedClass);
    this.cursor = index;

    if (index >= 0) {
      this.selectedItem?.element.classList.add(selectedClass);
    }
  }

  setSuggestions(params: Suggestions): SuggestionsPopup {
    this.cursor = -1;
    this.items = [];
    this.container.innerHTML = '';

    for (const suggestion of params.history) {
      this.appendSuggestion(suggestion);
    }

    if (params.tags.length > 0) {
      this.container.appendChild(makeEl('hr', { className: 'autocomplete__separator' }));
    }

    for (const suggestion of params.tags) {
      this.appendSuggestion(suggestion);
    }

    return this;
  }

  appendSuggestion(suggestion: Suggestion) {
    const type = suggestion instanceof TagSuggestion ? 'tag' : 'history';

    const element = makeEl('div', {
      className: `autocomplete__item autocomplete-item-${type}`,
    });
    element.append(...suggestion.render());

    const item: SuggestionItem = { element, suggestion };

    this.watchItem(item);

    this.items.push(item);
    this.container.appendChild(element);
  }

  private watchItem(item: SuggestionItem) {
    item.element.addEventListener('pointerdown', event => {
      if (event.button !== 0) {
        return;
      }

      // This prevent focusing on the element and thus losing focus on the input field.
      // This ensures that the user can always continue typing in the input, and we
      // don't need to refocus the input back if the user clicks on the suggestion.
      event.preventDefault();

      this.container.dispatchEvent(new CustomEvent('item_selected', { detail: item.suggestion }));
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
    return this.items[index].suggestion instanceof TagSuggestion ? 'tag' : 'history';
  }

  showForElement(targetElement: HTMLElement) {
    this.container.style.position = 'absolute';
    this.container.style.left = `${targetElement.offsetLeft}px`;

    let topPosition = targetElement.offsetTop + targetElement.offsetHeight;

    if (targetElement.parentElement) {
      topPosition -= targetElement.parentElement.scrollTop;
    }

    this.container.style.top = `${topPosition}px`;
    this.container.classList.remove('hidden');
  }

  onItemSelected(callback: (event: CustomEvent<Suggestion>) => void) {
    this.container.addEventListener('item_selected', callback as EventListener);
  }
}

const cachedSuggestions = new Map<string, Promise<Suggestion[]>>();

export async function fetchSuggestions(endpoint: string, targetTerm: string): Promise<Suggestion[]> {
  const normalizedTerm = targetTerm.trim().toLowerCase();

  if (cachedSuggestions.has(normalizedTerm)) {
    return cachedSuggestions.get(normalizedTerm)!;
  }

  const promisedSuggestions: Promise<Suggestion[]> = fetch(`${endpoint}${targetTerm}`)
    .then(handleError)
    .then(response => response.json())
    .catch(() => {
      // Deleting the promised result from cache to allow retrying
      cachedSuggestions.delete(normalizedTerm);

      // And resolve failed promise with empty array
      return [];
    });

  cachedSuggestions.set(normalizedTerm, promisedSuggestions);

  return promisedSuggestions;
}

export function purgeSuggestionsCache() {
  cachedSuggestions.clear();
}

export async function fetchLocalAutocomplete(): Promise<LocalAutocompleter> {
  const now = new Date();
  const cacheKey = `${now.getUTCFullYear()}-${now.getUTCMonth()}-${now.getUTCDate()}`;

  return await fetch(`/autocomplete/compiled?vsn=2&key=${cacheKey}`, {
    credentials: 'omit',
    cache: 'force-cache',
  })
    .then(handleError)
    .then(resp => resp.arrayBuffer())
    .then(buf => new LocalAutocompleter(buf));
}
