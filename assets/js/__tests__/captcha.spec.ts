import { fireEvent } from '@testing-library/dom';
import { bindCaptchaLinks } from '../captcha';

describe('bindCaptchaLinks', () => {
  beforeAll(() => bindCaptchaLinks());

  beforeEach(() => {
    document.body.innerHTML = `
      <div class="js-captcha-box">
        <div class="form-control-checkbox">
          <span class="form-checkbox-input-wrap">
            <input class="form-checkbox-input js-captcha" data-sitekey="site-key" type="checkbox">
          </span>
          <label class="form-checkbox-label">I am not a robot!</label>
        </div>
      </div>
    `;
  });

  it('replaces the checkbox row with the captcha widget and its script', () => {
    fireEvent.click(document.querySelector('.js-captcha')!);

    const box = document.querySelector('.js-captcha-box')!;
    const frame = box.querySelector<HTMLElement>('.h-captcha')!;

    expect(box.children).toHaveLength(2);
    expect(frame.dataset.sitekey).toBe('site-key');
    expect(box.querySelector('script')).toHaveAttribute('src', 'https://hcaptcha.com/1/api.js');
    expect(box.querySelector('.js-captcha')).toBeNull();
  });
});
