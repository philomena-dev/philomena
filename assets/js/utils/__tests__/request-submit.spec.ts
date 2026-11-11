import { assertNotNull } from '../assert';
import { $ } from '../dom';
import { requestSubmit } from '../request-submit';

describe('requestSubmit', () => {
  let form: HTMLFormElement;
  let input: HTMLInputElement;
  let submits: number;

  beforeEach(() => {
    document.body.innerHTML = '<form><input name="q" required></form>';
    form = assertNotNull($<HTMLFormElement>('form'));
    input = assertNotNull($<HTMLInputElement>('input', form));
    submits = 0;
    form.addEventListener('submit', event => {
      event.preventDefault();
      submits++;
    });
  });

  describe.each([
    ['with form.requestSubmit', () => {}],
    ['without form.requestSubmit', () => Object.defineProperty(form, 'requestSubmit', { value: undefined })],
  ])('%s', (_name, setUp) => {
    beforeEach(setUp);

    it('runs the submit handlers of a valid form', () => {
      input.value = 'safe';
      requestSubmit(form);

      expect(submits).toBe(1);
      expect($('button', form)).toBeNull();
    });

    it('does not submit an invalid form', () => {
      requestSubmit(form);

      expect(submits).toBe(0);
    });
  });
});
