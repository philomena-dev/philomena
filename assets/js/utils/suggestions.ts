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

    return [prefix, makeEl('span', { textContent: ` ${imageCount}` })];
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

export interface SelectionChangedEventDetail {
  selectedSuggestion: Suggestion | null;
}

/**
 * Responsible for rendering the suggestions dropdown.
 */
export class SuggestionsDropdown {
  static selectedSuggestionClassName = 'autocomplete__item--selected';

  private readonly container: HTMLElement;
  private selectionIndex: number = -1;
  private suggestionItems: SuggestionItem[];

  constructor() {
    this.container = makeEl('div', {
      className: 'autocomplete hidden',
    });

    // Make the container connected to DOM to make sure it's rendered when we unhide it
    document.body.appendChild(this.container);
    this.suggestionItems = [];
  }

  get selectedSuggestion(): Suggestion | null {
    return this.selectedSuggestionItem?.suggestion ?? null;
  }

  private get selectedSuggestionItem(): SuggestionItem | null {
    if (this.selectionIndex < 0) {
      return null;
    }

    return this.suggestionItems[this.selectionIndex];
  }

  get isActive(): boolean {
    return !this.container.classList.contains('hidden');
  }

  hide() {
    this.clearSelection();
    this.container.classList.add('hidden');
  }

  private clearSelection() {
    this.setSelection(-1);
  }

  private setSelection(index: number) {
    if (this.selectionIndex === index) {
      return;
    }

    if (index < -1 || index >= this.suggestionItems.length) {
      throw new Error(`setSelection(): invalid selection index: ${index}`);
    }

    this.selectedSuggestionItem?.element.classList.remove(SuggestionsDropdown.selectedSuggestionClassName);
    this.selectionIndex = index;

    if (index >= 0) {
      this.selectedSuggestionItem?.element.classList.add(SuggestionsDropdown.selectedSuggestionClassName);
    }
  }

  setSuggestions(params: Suggestions): SuggestionsDropdown {
    this.clearSelection();

    this.suggestionItems = [];
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

    this.suggestionItems.push(item);
    this.container.appendChild(element);
  }

  private watchItem(item: SuggestionItem) {
    item.element.addEventListener('click', () => {
      this.hide();
      this.container.dispatchEvent(new CustomEvent('item_selected', { detail: item.suggestion }));
    });
  }

  private changeSelection(direction: number) {
    if (this.suggestionItems.length === 0) {
      return;
    }

    const index = this.selectionIndex + direction;

    if (index === -1 || index >= this.suggestionItems.length) {
      this.clearSelection();
    } else if (index < -1) {
      this.setSelection(this.suggestionItems.length - 1);
    } else {
      this.setSelection(index);
    }
  }

  selectNext() {
    this.changeSelection(1);
  }

  selectPrevious() {
    this.changeSelection(-1);
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
