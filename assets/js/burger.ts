/**
 * Hamburger menu.
 */

import { assertNotNull, assertType } from './utils/assert';

function switchClasses(element: HTMLElement, oldClass: string, newClass: string) {
  element.classList.remove(oldClass);
  element.classList.add(newClass);
}

function open(burger: HTMLElement, content: HTMLElement, body: HTMLElement, root: HTMLElement) {
  switchClasses(content, 'close', 'open');
  switchClasses(burger, 'close', 'open');

  root.classList.add('no-overflow-x');
  body.classList.add('no-overflow');
}

function close(burger: HTMLElement, content: HTMLElement, body: HTMLElement, root: HTMLElement) {
  switchClasses(content, 'open', 'close');
  switchClasses(burger, 'open', 'close');

  // The CSS animation closing the menu finishes in 300ms
  setTimeout(() => {
    root.classList.remove('no-overflow-x');
    body.classList.remove('no-overflow');
  }, 300);
}

function copyArtistLinksTo(burger: HTMLElement) {
  const copy = (links: HTMLCollection) => {
    burger.appendChild(document.createElement('hr'));

    [...links].forEach(link => {
      const burgerLink = assertType(link.cloneNode(true), HTMLElement);

      burgerLink.className = '';
      burger.appendChild(burgerLink);
    });
  };

  const linksContainers = document.querySelectorAll('.js-burger-links');

  [...linksContainers].forEach(container => copy(container.children));
}

function setupBurgerMenu() {
  const burger = assertNotNull(document.getElementById('burger'));
  const toggle = assertNotNull(document.getElementById('js-burger-toggle'));
  const content = assertNotNull(document.getElementById('container'));
  const body = document.body;
  const root = document.documentElement;

  copyArtistLinksTo(burger);

  toggle.addEventListener('click', event => {
    event.stopPropagation();
    event.preventDefault();

    if (content.classList.contains('open')) {
      close(burger, content, body, root);
    }
    else {
      open(burger, content, body, root);
    }
  });
  content.addEventListener('click', () => {
    if (content.classList.contains('open')) {
      close(burger, content, body, root);
    }
  });
}

export { setupBurgerMenu };
