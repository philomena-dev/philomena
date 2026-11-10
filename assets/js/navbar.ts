/**
 * Navbar menus on touch screens, which have no hover. A tap on the item of a menu that is not showing opens the
 * menu instead of following the item's link; a tap anywhere else and Escape close it. Whether the menu shows is read
 * when the finger lands: by the click, :hover or :focus-within may already show it, and on iOS the first tap on the
 * item only applies :hover and clicks nothing.
 */

import { $, $$ } from './utils/dom';

const itemAt = (target: EventTarget | null) =>
  target instanceof Element ? target.closest('.navbar-dropdown > .navbar-item') : null;

function setOpen(item: Element, open: boolean) {
  item.parentElement!.classList.toggle('open', open);
  item.setAttribute('aria-expanded', String(open));
}

function closeMenus(except?: Element | null) {
  for (const item of $$('.navbar-dropdown.open > .navbar-item')) {
    if (item !== except) setOpen(item, false);
  }
}

export function setupNavbarMenus() {
  let tapOpens = false;

  document.addEventListener('pointerdown', event => {
    const item = itemAt(event.target);
    const menu = item && $('.navbar-menu', item.parentElement!);

    tapOpens = event.pointerType === 'touch' && menu !== null && getComputedStyle(menu).display === 'none';
  });

  document.addEventListener('click', event => {
    const item = itemAt(event.target);

    closeMenus(item);

    if (item && tapOpens) {
      event.preventDefault();
      setOpen(item, true);
    }

    tapOpens = false;
  });

  document.addEventListener('keydown', event => {
    if (event.key === 'Escape') closeMenus();
  });
}
