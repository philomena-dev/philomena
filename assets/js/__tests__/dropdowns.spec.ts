import { fireEvent } from '@testing-library/dom';
import { setupDropdowns } from '../dropdowns';

describe.each([
  [
    'a navbar menu',
    `<nav class="navbar">
      <div class="navbar-dropdown">
        <a aria-expanded="false" aria-haspopup="true" class="navbar-item caret" href="/forums">Forums</a>
        <div class="navbar-menu"><a class="navbar-menu-item" href="/forums/dis">Discussion</a></div>
      </div>
      <a class="navbar-item" href="/galleries">Galleries</a>
    </nav>`,
  ],
  [
    'a dropdown',
    `<div class="dropdown">
      <a aria-expanded="false" aria-haspopup="true" href="/forums">Forums</a>
      <div class="dropdown-menu"><button class="dropdown-item" type="button">Discussion</button></div>
    </div>
    <a href="/galleries">Galleries</a>`,
  ],
])('setupDropdowns on %s', (_kind, markup) => {
  let dropdown: HTMLElement;
  let trigger: HTMLElement;
  let menu: HTMLElement;

  beforeAll(() => setupDropdowns());

  beforeEach(() => {
    document.body.innerHTML = `
      <style>
        .navbar-menu, .dropdown-menu { display: none; }
        .open > .navbar-menu, .open > .dropdown-menu { display: flex; }
      </style>
      ${markup}
    `;
    trigger = document.querySelector('[aria-haspopup]')!;
    dropdown = trigger.parentElement!;
    menu = trigger.nextElementSibling as HTMLElement;
  });

  const tap = (target: Element | Document, pointerType = 'touch') => {
    fireEvent.pointerDown(target, { pointerType });
    return fireEvent.click(target);
  };

  const isOpen = () => dropdown.classList.contains('open') && trigger.getAttribute('aria-expanded') === 'true';

  it('opens the menu on the first tap on its trigger instead of following the link', () => {
    expect(tap(trigger)).toBe(false);
    expect(isOpen()).toBe(true);
  });

  it('follows the link of a trigger whose menu is open', () => {
    tap(trigger);

    expect(tap(trigger)).toBe(true);
    expect(isOpen()).toBe(true);
  });

  it('follows the link on the second tap when the first only applied hover, as on iOS', () => {
    fireEvent.pointerDown(trigger, { pointerType: 'touch' });
    menu.style.display = 'flex';

    expect(tap(trigger)).toBe(true);
  });

  it('leaves menus to hover for a mouse and to focus for a keyboard', () => {
    expect(tap(trigger, 'mouse')).toBe(true);
    expect(fireEvent.click(trigger)).toBe(true);
    expect(dropdown).not.toHaveClass('open');
  });

  it('keeps the menu open while its items are tapped', () => {
    tap(trigger);
    tap(menu.firstElementChild!);

    expect(isOpen()).toBe(true);
  });

  it.each([
    ['another link', () => document.querySelector('a[href="/galleries"]')!],
    ['the page', () => document],
  ])('closes an open menu on a tap on %s', (_, elsewhere) => {
    tap(trigger);
    tap(elsewhere());

    expect(dropdown).not.toHaveClass('open');
    expect(trigger).toHaveAttribute('aria-expanded', 'false');
  });

  it('closes an open menu on Escape', () => {
    tap(trigger);
    fireEvent.keyDown(document, { key: 'Tab' });
    expect(isOpen()).toBe(true);

    fireEvent.keyDown(document, { key: 'Escape' });
    expect(dropdown).not.toHaveClass('open');
  });
});

describe('setupDropdowns fitting a dropdown menu to the screen', () => {
  let trigger: HTMLElement;
  let menu: HTMLElement;

  beforeAll(() => setupDropdowns());

  beforeEach(() => {
    document.body.innerHTML = `
      <style>.dropdown-menu { display: none; } .open > .dropdown-menu { display: flex; }</style>
      <div class="dropdown">
        <span aria-haspopup="true" class="tag"><a class="tag-name" href="/tags/safe">safe</a></span>
        <div class="dropdown-menu"><a class="dropdown-item" href="/filters">Filter</a></div>
      </div>
    `;
    trigger = document.querySelector('[aria-haspopup]')!;
    menu = document.querySelector('.dropdown-menu')!;
    vi.spyOn(document.documentElement, 'clientWidth', 'get').mockReturnValue(360);
  });

  afterEach(() => vi.restoreAllMocks());

  // The right edge of the menu when it opens toward the end, and when it opens toward the start
  const placeMenu = (right: number, endRight: number) =>
    vi
      .spyOn(menu, 'getBoundingClientRect')
      .mockImplementation(() => ({ right: menu.classList.contains('end') ? endRight : right }) as DOMRect);

  it('opens a menu that would run past the screen toward the start when tapped', () => {
    placeMenu(400, 300);
    fireEvent.pointerDown(trigger, { pointerType: 'touch' });
    fireEvent.click(trigger);

    expect(menu).toHaveClass('end');
  });

  it('turns a menu back once it fits, as when the hovered tag moved', () => {
    placeMenu(400, 300);
    fireEvent.pointerOver(trigger);
    expect(menu).toHaveClass('end');

    placeMenu(200, 100);
    fireEvent.focusIn(menu.firstElementChild!);
    expect(menu).not.toHaveClass('end');
  });

  it('leaves a menu that the markup aligns with the end', () => {
    menu.classList.add('end');
    placeMenu(200, 100);
    fireEvent.pointerOver(trigger);

    expect(menu).toHaveClass('end');
  });
});
