import { makeEl } from './dom';

/**
 * Submits the form as a click on a submit button does: it is validated and its `submit` handlers run, which
 * `form.submit()` skips. Safari before 16 lacks `form.requestSubmit()`, so a hidden submit button is clicked there.
 */
export function requestSubmit(form: HTMLFormElement) {
  if (typeof form.requestSubmit === 'function') {
    form.requestSubmit();
    return;
  }

  const button = makeEl('button', { type: 'submit', hidden: true });
  form.append(button);
  button.click();
  button.remove();
}
