/**
 * Dropdown menus on touch screens, which have no hover: the menus of a navbar and the dropdowns in the page, whose
 * trigger is the child that carries `aria-haspopup`. A tap on the trigger of a menu that is not showing opens the menu
 * instead of following the trigger's link; a tap outside the dropdown and Escape close it, so that a menu stays open
 * while its items are used. Whether the menu shows is read when the finger lands: by the click, :hover or :focus-within
 * may already show it, and on iOS the first tap on the trigger only applies :hover and clicks nothing. A dropdown menu
 * that would run past the end of the screen, such as the menu of a tag at the end of a row, opens toward the start.
 */

import { $$ } from './utils/dom';

const triggerSelector = '.navbar-dropdown > [aria-haspopup], .dropdown > [aria-haspopup]';
const openTriggerSelector = '.navbar-dropdown.open > [aria-haspopup], .dropdown.open > [aria-haspopup]';

const triggerAt = (target: EventTarget | null) => (target instanceof Element ? target.closest(triggerSelector) : null);

const menuOf = (trigger: Element) =>
  trigger.parentElement!.querySelector(':scope > .navbar-menu, :scope > .dropdown-menu');

// Menus marked .end in the markup stay so; data-fit-end marks the ones this script turned
function fitMenu(menu: Element | null) {
  if (!menu || (menu.classList.contains('end') && !menu.hasAttribute('data-fit-end'))) return;

  menu.classList.remove('end');
  const overflows = menu.getBoundingClientRect().right > document.documentElement.clientWidth;
  menu.classList.toggle('end', overflows);
  menu.toggleAttribute('data-fit-end', overflows);
}

const dropdownMenuAt = (target: EventTarget | null) =>
  target instanceof Element ? (target.closest('.dropdown')?.querySelector(':scope > .dropdown-menu') ?? null) : null;

function setOpen(trigger: Element, open: boolean) {
  trigger.parentElement!.classList.toggle('open', open);
  trigger.setAttribute('aria-expanded', String(open));
}

function closeMenus(target?: EventTarget | null) {
  for (const trigger of $$(openTriggerSelector)) {
    if (!(target instanceof Node && trigger.parentElement!.contains(target))) setOpen(trigger, false);
  }
}

export function setupDropdowns() {
  let tapOpens = false;

  document.addEventListener('pointerdown', event => {
    const trigger = triggerAt(event.target);

    tapOpens =
      event.pointerType === 'touch' && trigger !== null && getComputedStyle(menuOf(trigger)!).display === 'none';
  });

  document.addEventListener('click', event => {
    const trigger = triggerAt(event.target);

    closeMenus(event.target);

    if (trigger && tapOpens) {
      event.preventDefault();
      setOpen(trigger, true);
      fitMenu(dropdownMenuAt(trigger));
    }

    tapOpens = false;
  });

  for (const type of ['pointerover', 'focusin']) {
    document.addEventListener(type, event => fitMenu(dropdownMenuAt(event.target)));
  }

  document.addEventListener('keydown', event => {
    if (event.key === 'Escape') closeMenus();
  });
}
