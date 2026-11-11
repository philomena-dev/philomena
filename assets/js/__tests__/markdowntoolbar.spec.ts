import { fireEvent } from '@testing-library/dom';
import { setupToolbar } from '../markdowntoolbar';

const button = (id: string, tabIndex = -1) =>
  `<button class="editor-button" data-syntax-id="${id}" tabindex="${tabIndex}" type="button">${id}</button>`;

describe('setupToolbar', () => {
  let textarea: HTMLTextAreaElement;

  beforeEach(() => {
    document.body.innerHTML = `
      <div class="editor">
        <div class="editor-toolbar" role="toolbar">
          <div class="editor-toolbar-group">${button('bold', 0)}${button('code')}</div>
          <div class="editor-toolbar-group">${button('quote')}${button('link')}${button('image')}${button('escape')}</div>
        </div>
        <textarea class="editor-input js-toolbar-input"></textarea>
      </div>
    `;
    textarea = document.querySelector('textarea')!;
    setupToolbar();
  });

  const select = (value: string, start: number, end: number) => {
    textarea.value = value;
    textarea.setSelectionRange(start, end);
  };

  const click = (id: string) => fireEvent.click(document.querySelector(`[data-syntax-id="${id}"]`)!);

  it('wraps the selection of the editor it belongs to and focuses the textarea', () => {
    select('make this bold', 5, 9);
    click('bold');

    expect(textarea.value).toBe('make **this** bold');
    expect(textarea.selectionStart).toBe(13);
    expect(document.activeElement).toBe(textarea);
  });

  it('wraps a selection of several lines into a code block', () => {
    select('one\ntwo', 0, 7);
    click('code');

    expect(textarea.value).toBe('```\none\ntwo\n```');
  });

  it('quotes every selected line', () => {
    select('one\ntwo', 0, 7);
    click('quote');

    expect(textarea.value).toBe('> one\n> two');
  });

  it('turns the selection into a link or an image with the address asked for', () => {
    const prompt = vi.spyOn(window, 'prompt').mockReturnValue(`${window.location.origin}/images/1`);

    select('pony', 0, 4);
    click('link');
    expect(textarea.value).toBe('[pony](/images/1)');

    select('pony', 0, 4);
    click('image');
    expect(textarea.value).toBe(`![pony](${window.location.origin}/images/1)`);

    prompt.mockReturnValue(null);
    click('link');
    expect(textarea.value).toBe(`![pony](${window.location.origin}/images/1)`);

    prompt.mockRestore();
  });

  it('escapes the markup characters of the selection', () => {
    select('*a*', 0, 3);
    click('escape');

    expect(textarea.value).toBe('\\*a\\*');
  });

  it('ignores clicks in the toolbar outside its buttons', () => {
    select('text', 0, 4);
    fireEvent.click(document.querySelector('.editor-toolbar')!);

    expect(textarea.value).toBe('text');
  });

  it('applies a format on its shortcut and leaves other keys alone', () => {
    select('text', 0, 4);

    expect(fireEvent.keyDown(textarea, { key: 'b', code: 'KeyB', ctrlKey: true })).toBe(false);
    expect(textarea.value).toBe('**text**');

    expect(fireEvent.keyDown(textarea, { key: 'b', code: 'KeyB', ctrlKey: true, shiftKey: true })).toBe(true);
    expect(fireEvent.keyDown(textarea, { key: 'q', code: 'KeyQ', ctrlKey: true })).toBe(true);
    expect(textarea.value).toBe('**text**');
  });

  it('moves the focus and the single tab stop between the buttons with the arrow keys, Home and End', () => {
    const buttons = [...document.querySelectorAll<HTMLButtonElement>('.editor-button')];
    const focused = () => buttons.indexOf(document.activeElement as HTMLButtonElement);
    const press = (key: string) => fireEvent.keyDown(document.activeElement!, { key, code: key });

    buttons[0].focus();
    press('ArrowLeft');
    expect(focused()).toBe(5);
    press('ArrowRight');
    expect(focused()).toBe(0);
    press('ArrowRight');
    expect(focused()).toBe(1);
    press('End');
    expect(focused()).toBe(5);
    press('Home');
    expect(focused()).toBe(0);

    expect(buttons.map(b => b.tabIndex)).toEqual([0, -1, -1, -1, -1, -1]);
    expect(press('Tab')).toBe(true);
  });
});
