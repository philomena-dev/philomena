/**
 * StaffHider
 *
 * Hide staff elements if enabled in the settings.
 */

import { $$ } from './utils/dom';

export function hideStaffTools() {
  if (window.booru.hideStaffTools === 'true') {
    $$<HTMLElement>('.js-staff-action').forEach(el => {
      el.classList.add('hidden');
    });
  }
}
