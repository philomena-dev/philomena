/**
 * The burger menu. The navbar's burger button opens the panel over its veil; the veil, the close button and Escape
 * close it again, and so does a screen wide enough to hide the button. While it is open the page behind it does not
 * scroll and Tab keeps the focus inside it.
 */

import { $, $$ } from './utils/dom';

const focusable = 'a[href], button, select, input:not([type="hidden"])';

export function setupBurgerMenu() {
  const toggle = $<HTMLButtonElement>('.js-burger-toggle');
  const panel = $<HTMLElement>('.burger');

  if (!toggle || !panel) return;

  const overlay = $<HTMLElement>('.burger-overlay');

  const setOpen = (open: boolean) => {
    for (const part of [panel, overlay]) part?.classList.toggle('open', open);

    toggle.setAttribute('aria-expanded', String(open));
    document.documentElement.classList.toggle('no-overflow', open);

    if (open) {
      $<HTMLElement>(focusable, panel)?.focus();
    } else if (panel.contains(document.activeElement)) {
      toggle.focus();
    }
  };

  // Tab and Shift+Tab go round the panel's rendered controls instead of leaving it
  const keepFocus = (event: KeyboardEvent) => {
    const controls = $$<HTMLElement>(focusable, panel).filter(control => control.getClientRects().length > 0);
    const [first, last] = [controls[0], controls[controls.length - 1]];

    if (document.activeElement === (event.shiftKey ? first : last) || !panel.contains(document.activeElement)) {
      event.preventDefault();
      (event.shiftKey ? last : first).focus();
    }
  };

  toggle.addEventListener('click', () => setOpen(true));

  new ResizeObserver(() => {
    if (toggle.getClientRects().length === 0) setOpen(false);
  }).observe(toggle);

  for (const closer of $$('.js-burger-close')) {
    closer.addEventListener('click', () => setOpen(false));
  }

  document.addEventListener('keydown', event => {
    if (!panel.classList.contains('open')) return;

    if (event.key === 'Escape') setOpen(false);
    if (event.key === 'Tab') keepFocus(event);
  });
}
