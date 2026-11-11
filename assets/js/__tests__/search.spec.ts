import { $ } from '../utils/dom';
import { assertNotNull } from '../utils/assert';
import { setupSearch } from '../search';
import { setupTagListener } from '../tagsinput';

const formData = `<form class="js-search-form">
  <input type="text" class="js-search-field">
  <button data-search-prepend="-" type="button">NOT</button>
  <button data-search-add="id.lte:10" data-search-select-last="2" data-search-show-help="numeric" type="button">Numeric ID</button>
  <button data-search-add="my:faves" data-search-show-help=" " type="button">My favorites</button>
  <div class="hidden" data-search-help="boolean">
    <span class="js-search-help-subject"></span> is a Boolean value field
  </div>
  <div class="hidden" data-search-help="numeric">
    <span class="js-search-help-subject"></span> is a numerical range field
  </div>
</form>`;

describe('Search form help', () => {
  beforeAll(() => {
    setupSearch();
    setupTagListener();
  });

  let input: HTMLInputElement;
  let prependButton: HTMLButtonElement;
  let idButton: HTMLButtonElement;
  let favesButton: HTMLButtonElement;
  let helpNumeric: HTMLDivElement;
  let subjectSpan: HTMLElement;

  beforeEach(() => {
    document.body.innerHTML = formData;

    input = assertNotNull($<HTMLInputElement>('input'));
    prependButton = assertNotNull($<HTMLButtonElement>('[data-search-prepend]'));
    idButton = assertNotNull($<HTMLButtonElement>('[data-search-add="id.lte:10"]'));
    favesButton = assertNotNull($<HTMLButtonElement>('[data-search-add="my:faves"]'));
    helpNumeric = assertNotNull($<HTMLDivElement>('[data-search-help="numeric"]'));
    subjectSpan = assertNotNull($<HTMLSpanElement>('span', helpNumeric));
  });

  it('should add text to input field', () => {
    idButton.click();
    expect(input.value).toBe('id.lte:10');

    favesButton.click();
    expect(input.value).toBe('id.lte:10, my:faves');
  });

  it('should focus and select text in input field when requested', () => {
    idButton.click();
    expect(input).toHaveFocus();
    expect(input.selectionStart).toBe(7);
    expect(input.selectionEnd).toBe(9);
  });

  it('should highlight subject name when requested', () => {
    expect(helpNumeric).toHaveClass('hidden');
    idButton.click();
    expect(helpNumeric).not.toHaveClass('hidden');
    expect(subjectSpan).toHaveTextContent('Numeric ID');
  });

  it('should not focus and select text in input field when unavailable', () => {
    favesButton.click();
    expect(input).not.toHaveFocus();
    expect(input.selectionStart).toBe(8);
    expect(input.selectionEnd).toBe(8);
  });

  it('should not highlight subject name when unavailable', () => {
    favesButton.click();
    expect(helpNumeric).toHaveClass('hidden');
  });

  it('should prepend to empty input', () => {
    prependButton.click();
    expect(input.value).toBe('-');
  });

  it('should prepend to single input', () => {
    input.value = 'a';
    prependButton.click();
    expect(input.value).toBe('-a');
  });

  it('should prepend to comma-separated input', () => {
    input.value = 'a,b';
    prependButton.click();
    expect(input.value).toBe('a,-b');
  });

  it('should prepend to comma and space-separated input', () => {
    input.value = 'a, b';
    prependButton.click();
    expect(input.value).toBe('a, -b');
  });
});
