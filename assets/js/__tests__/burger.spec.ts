import { fireEvent } from '@testing-library/dom';
import { setupBurgerMenu } from '../burger';

describe('setupBurgerMenu', () => {
  let toggle: HTMLButtonElement;
  let panel: HTMLElement;
  let overlay: HTMLElement;

  beforeEach(() => {
    document.body.innerHTML = `
      <button class="js-burger-toggle" aria-controls="burger" aria-expanded="false">Menu</button>
      <nav class="burger" id="burger">
        <button class="burger-close js-burger-close">Close</button>
        <a class="burger-item" href="/images">Images</a>
        <form><input type="hidden" name="_csrf_token"><select><option>Default</option></select></form>
        <a class="burger-item" href="/sessions">Logout</a>
      </nav>
      <div class="burger-overlay js-burger-close"></div>
    `;
    toggle = document.querySelector('.js-burger-toggle')!;
    panel = document.querySelector('.burger')!;
    overlay = document.querySelector('.burger-overlay')!;
    setupBurgerMenu();
  });

  afterEach(() => {
    fireEvent.keyDown(document, { key: 'Escape' });
  });

  const isOpen = () =>
    panel.classList.contains('open') &&
    overlay.classList.contains('open') &&
    toggle.getAttribute('aria-expanded') === 'true' &&
    document.documentElement.classList.contains('no-overflow');

  it('opens the panel from the toggle and moves the focus into it', () => {
    fireEvent.click(toggle);

    expect(isOpen()).toBe(true);
    expect(document.activeElement).toBe(panel.querySelector('.burger-close'));
  });

  it.each(['.burger-close', '.burger-overlay'])('closes from %s and gives the focus back to the toggle', closer => {
    fireEvent.click(toggle);
    fireEvent.click(document.querySelector(closer)!);

    expect(panel).not.toHaveClass('open');
    expect(overlay).not.toHaveClass('open');
    expect(toggle).toHaveAttribute('aria-expanded', 'false');
    expect(document.documentElement).not.toHaveClass('no-overflow');
    expect(document.activeElement).toBe(toggle);
  });

  it('closes on Escape, leaving the focus where it is when it has left the panel', () => {
    const outside = document.createElement('input');
    document.body.append(outside);

    fireEvent.click(toggle);
    outside.focus();
    fireEvent.keyDown(document, { key: 'Escape' });

    expect(panel).not.toHaveClass('open');
    expect(document.activeElement).toBe(outside);
  });

  it('keeps Tab and Shift+Tab going round the controls of the open panel', () => {
    const [close, images, logout] = panel.querySelectorAll<HTMLElement>('button, a');
    fireEvent.click(toggle);

    logout.focus();
    expect(fireEvent.keyDown(document, { key: 'Tab' })).toBe(false);
    expect(document.activeElement).toBe(close);

    expect(fireEvent.keyDown(document, { key: 'Tab', shiftKey: true })).toBe(false);
    expect(document.activeElement).toBe(logout);

    images.focus();
    expect(fireEvent.keyDown(document, { key: 'Tab' })).toBe(true);
    expect(document.activeElement).toBe(images);

    toggle.focus();
    expect(fireEvent.keyDown(document, { key: 'Tab' })).toBe(false);
    expect(document.activeElement).toBe(close);
  });

  it('leaves keys alone while the panel is closed', () => {
    toggle.focus();

    expect(fireEvent.keyDown(document, { key: 'Tab' })).toBe(true);
    expect(document.activeElement).toBe(toggle);
  });

  it('does nothing on a page without a burger menu', () => {
    document.body.innerHTML = '';

    expect(() => setupBurgerMenu()).not.toThrow();
  });
});
