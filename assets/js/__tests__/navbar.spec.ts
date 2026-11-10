import { fireEvent } from '@testing-library/dom';
import { setupNavbarMenus } from '../navbar';

describe('setupNavbarMenus', () => {
  let dropdown: HTMLElement;
  let item: HTMLElement;
  let menu: HTMLElement;

  beforeAll(() => setupNavbarMenus());

  beforeEach(() => {
    document.body.innerHTML = `
      <style>
        .navbar-menu { display: none; }
        .navbar-dropdown.open > .navbar-menu { display: flex; }
      </style>
      <nav class="navbar">
        <div class="navbar-dropdown">
          <a aria-expanded="false" aria-haspopup="true" class="navbar-item caret" href="/forums">Forums</a>
          <div class="navbar-menu"><a class="navbar-menu-item" href="/forums/dis">Discussion</a></div>
        </div>
        <a class="navbar-item" href="/galleries">Galleries</a>
      </nav>
    `;
    dropdown = document.querySelector('.navbar-dropdown')!;
    item = document.querySelector('.navbar-dropdown > .navbar-item')!;
    menu = document.querySelector('.navbar-menu')!;
  });

  const tap = (target: Element | Document, pointerType = 'touch') => {
    fireEvent.pointerDown(target, { pointerType });
    return fireEvent.click(target);
  };

  const isOpen = () => dropdown.classList.contains('open') && item.getAttribute('aria-expanded') === 'true';

  it('opens a menu on the first tap on its item instead of following the link', () => {
    expect(tap(item)).toBe(false);
    expect(isOpen()).toBe(true);
  });

  it('follows the link of an item whose menu is open', () => {
    tap(item);

    expect(tap(item)).toBe(true);
    expect(isOpen()).toBe(true);
  });

  it('follows the link on the second tap when the first only applied hover, as on iOS', () => {
    fireEvent.pointerDown(item, { pointerType: 'touch' });
    menu.style.display = 'flex';

    expect(tap(item)).toBe(true);
  });

  it('leaves menus to hover for a mouse and to focus for a keyboard', () => {
    expect(tap(item, 'mouse')).toBe(true);
    expect(fireEvent.click(item)).toBe(true);
    expect(dropdown).not.toHaveClass('open');
  });

  it.each([
    ['another item', () => document.querySelector('a[href="/galleries"]')!],
    ['the page', () => document],
  ])('closes an open menu on a tap on %s', (_, elsewhere) => {
    tap(item);
    tap(elsewhere());

    expect(dropdown).not.toHaveClass('open');
    expect(item).toHaveAttribute('aria-expanded', 'false');
  });

  it('closes an open menu on Escape', () => {
    tap(item);
    fireEvent.keyDown(document, { key: 'Tab' });
    expect(isOpen()).toBe(true);

    fireEvent.keyDown(document, { key: 'Escape' });
    expect(dropdown).not.toHaveClass('open');
  });
});
