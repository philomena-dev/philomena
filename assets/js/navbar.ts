/**
 * Navbar menus on touch screens, which have no hover. The first tap on the item of a closed menu opens the menu
 * instead of following the item's link; a tap anywhere else and Escape close it.
 */

import { $$ } from './utils/dom';

function closeMenus(except?: Element | null) {
  for (const dropdown of $$('.navbar-dropdown.open')) {
    if (dropdown !== except) dropdown.classList.remove('open');
  }
}

export function setupNavbarMenus() {
  let touch = false;

  document.addEventListener('pointerdown', event => {
    touch = event.pointerType === 'touch';
  });

  document.addEventListener('click', event => {
    const item = event.target instanceof Element ? event.target.closest('.navbar-dropdown > .navbar-item') : null;
    const dropdown = item?.parentElement;

    closeMenus(dropdown);

    if (touch && dropdown && !dropdown.classList.contains('open')) {
      event.preventDefault();
      dropdown.classList.add('open');
    }
  });

  document.addEventListener('keydown', event => {
    if (event.key === 'Escape') closeMenus();
  });
}
