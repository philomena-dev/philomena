// DOM events

import '../../types/ujs';

export interface PhilomenaAvailableEventsMap {
  dragstart: DragEvent;
  dragover: DragEvent;
  dragenter: DragEvent;
  dragleave: DragEvent;
  dragend: DragEvent;
  drop: DragEvent;
  click: MouseEvent;
  submit: Event;
  reset: Event;
  fetchcomplete: FetchcompleteEvent;
}

export interface PhilomenaEventElement {
  addEventListener<K extends keyof PhilomenaAvailableEventsMap>(
    type: K,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    listener: (this: Document | HTMLElement, ev: PhilomenaAvailableEventsMap[K]) => any,
    options?: boolean | AddEventListenerOptions | undefined,
  ): void;
}

export function fire<El extends Element, D>(el: El, event: string, detail: D) {
  el.dispatchEvent(new CustomEvent<D>(event, { detail, bubbles: true, cancelable: true }));
}

export function on<K extends keyof PhilomenaAvailableEventsMap>(
  node: PhilomenaEventElement,
  event: K,
  selector: string,
  func: (e: PhilomenaAvailableEventsMap[K], target: Element) => boolean,
) {
  delegate(node, event, { [selector]: func });
}

export function leftClick<E extends MouseEvent, Target extends EventTarget>(func: (e: E, t: Target) => void) {
  return (event: E, target: Target) => {
    if (event.button === 0) return func(event, target);
  };
}

export function oncePersistedPageShown(func: (e: PageTransitionEvent) => void) {
  const controller = new AbortController();

  window.addEventListener(
    'pageshow',
    (e: PageTransitionEvent) => {
      if (!e.persisted) {
        return;
      }

      controller.abort();
      func(e);
    },
    { signal: controller.signal },
  );
}

export function delegate<K extends keyof PhilomenaAvailableEventsMap, Target extends Element>(
  node: PhilomenaEventElement,
  event: K,
  selectors: Record<string, (e: PhilomenaAvailableEventsMap[K], target: Target) => void | boolean>,
) {
  node.addEventListener(event, e => {
    for (const selector in selectors) {
      const evtTarget = e.target as EventTarget | Target | null;
      if (evtTarget && 'closest' in evtTarget && typeof evtTarget.closest === 'function') {
        const target = evtTarget.closest(selector) as Target;
        if (target && selectors[selector](e, target) === false) break;
      }
    }
  });
}

declare const KeyCodeBrand: unique symbol;

/**
 * Newtype for a keyboard key to force the developers use the `keys` map of
 * well-known keyboard keys and extend it if needed. This forces the developer
 * to think carefully about handling the new keyboard key that isn't yet handled
 * by the `normalizedKeyboardKey` function.
 */
export type KeyboardKey = string & { [KeyCodeBrand]: never };

// Even though `event.code` is deprecated, it is still the most reliable way to
// detect the key pressed.
const keysMapping = {
  8: 'Backspace',

  // Covers the numpad enter too
  13: 'Enter',

  // Covers numpad arrows too
  37: 'ArrowLeft',
  38: 'ArrowUp',
  39: 'ArrowRight',
  40: 'ArrowDown',

  188: 'Comma',
} as const;

type WellKnownKey = keyof typeof keysMapping;

/**
 * A map of known keys to be used in code to avoid typos.
 */
export const keys = Object.fromEntries(Object.values(keysMapping).map(key => [key, key])) as Record<
  WellKnownKey,
  KeyboardKey
>;

/**
 * There are many inconsistencies in the way different browsers handle keyboard
 * events. This function is a heroic attempt to normalize them.
 *
 * There are the following nuances discovered so far:
 *
 * For example:
 * - Chrome & Firefox on Android devices return empty `code` when "Enter" is
 *   pressed via the virtual keyboard.
 * - There seems to be no way to reliably detect the `,` key on virtual
 *   keyboards on phones.
 * - The `event.code` uses `NumpadEnter` for the numpad enter key on regular
 *   keyboards
 */
export function normalizedKeyboardKey(event: KeyboardEvent): KeyboardKey {
  const code = keysMapping[event.keyCode];

  if (code) {
    return code;
  }

  return event.code as KeyboardKey;
}
