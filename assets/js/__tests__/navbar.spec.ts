import { fireEvent } from '@testing-library/dom';
import { setupNavbarMenus } from '../navbar';

describe('setupNavbarMenus', () => {
  let dropdown: HTMLElement;
  let item: HTMLElement;

  beforeAll(() => setupNavbarMenus());

  beforeEach(() => {
    document.body.innerHTML = `
      <nav class="navbar">
        <div class="navbar-dropdown">
          <a class="navbar-item caret" href="/forums">Forums</a>
          <div class="navbar-menu"><a class="navbar-menu-item" href="/forums/dis">Discussion</a></div>
        </div>
        <a class="navbar-item" href="/galleries">Galleries</a>
      </nav>
    `;
    dropdown = document.querySelector('.navbar-dropdown')!;
    item = document.querySelector('.navbar-dropdown > .navbar-item')!;
  });

  const tap = (target: Element | Document, pointerType = 'touch') => {
    fireEvent.pointerDown(target, { pointerType });
    return fireEvent.click(target);
  };

  it('opens a menu on the first tap on its item instead of following the link', () => {
    expect(tap(item)).toBe(false);
    expect(dropdown).toHaveClass('open');
  });

  it('follows the link of an item whose menu is open', () => {
    tap(item);

    expect(tap(item)).toBe(true);
    expect(dropdown).toHaveClass('open');
  });

  it('leaves menus to hover for a mouse', () => {
    expect(tap(item, 'mouse')).toBe(true);
    expect(dropdown).not.toHaveClass('open');
  });

  it.each([
    ['another item', () => document.querySelector('a[href="/galleries"]')!],
    ['the page', () => document],
  ])('closes an open menu on a tap on %s', (_, elsewhere) => {
    tap(item);
    tap(elsewhere());

    expect(dropdown).not.toHaveClass('open');
  });

  it('closes an open menu on Escape', () => {
    tap(item);
    fireEvent.keyDown(document, { key: 'Tab' });
    expect(dropdown).toHaveClass('open');

    fireEvent.keyDown(document, { key: 'Escape' });
    expect(dropdown).not.toHaveClass('open');
  });
});
