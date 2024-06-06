/**
 * Settings.
 */

import { $, $$ } from './utils/dom';
import store from './utils/store';

export function setupSettings() {
  if (!$<HTMLElement>('#js-setting-table')) return;

  const localCheckboxes = $$<HTMLInputElement>('[data-tab="local"] input[type="checkbox"]');
  const themeSelect = $<HTMLSelectElement>('#user_theme');
  const styleSheet = $<HTMLLinkElement>('head link[rel="stylesheet"]');

  // Local settings
  localCheckboxes.forEach(checkbox => {
    checkbox.addEventListener('change', () => {
      store.set(checkbox.id.replace('user_', ''), checkbox.checked);
    });
  });

  // Theme preview
  themeSelect && themeSelect.addEventListener('change', () => {
    if (styleSheet) {
      styleSheet.href = themeSelect.options[themeSelect.selectedIndex].dataset.themePath || '#';
    }
  });
}
