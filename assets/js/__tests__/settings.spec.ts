import { fireEvent } from '@testing-library/dom';
import { fixEventListeners } from '../../test/fix-event-listeners';
import { $ } from '../utils/dom';
import store from '../utils/store';
import { setupSettings } from '../settings';

fixEventListeners(document);

const themePaths = { 'dark-blue': '/css/blue.css', 'light-blue': '/css/blue.css', 'light-purple': '/css/purple.css' };

function renderSettings({ signedIn = true } = {}) {
  const theme = `
    <select id="user_settings_theme_name"><option value="dark">Dark</option><option value="light">Light</option></select>
    <select id="user_settings_theme_color"><option value="blue">Blue</option><option value="purple">Purple</option></select>
    <div class="hidden" id="js-theme-paths" data-theme-paths='${JSON.stringify(themePaths)}'></div>
  `;

  document.head.innerHTML = '<link href="/css/blue.css" id="js-theme-stylesheet" rel="stylesheet">';
  document.body.innerHTML = `
    <form id="js-setting-table">
      <div data-tab="local">
        <input type="checkbox" id="user_hidpi">
        <input type="text" id="user_webm_volume" value="">
        <input type="checkbox" id="user_enable_search_ac" checked>
        <div class="autocomplete-settings">
          <input type="checkbox" id="user_autocomplete_search_history_hidden">
          <div class="autocomplete-search-history-settings"></div>
        </div>
      </div>
      ${signedIn ? theme : ''}
      <div class="field"><span class="field-help-button"><i></i> Help</span><div class="field-help-content hidden"></div></div>
      <span class="field-help-button lonely"></span>
    </form>
  `;
}

function select(id: string, value: string) {
  fireEvent.change(Object.assign($<HTMLSelectElement>(id)!, { value }));
}

describe('setupSettings', () => {
  afterEach(() => {
    localStorage.clear();
    delete document.documentElement.dataset.theme;
  });

  it('does nothing outside the settings page', () => {
    document.body.innerHTML = '<div data-tab="local"><input type="checkbox" id="user_hidpi"></div>';
    setupSettings();

    fireEvent.click($<HTMLInputElement>('#user_hidpi')!);
    expect(store.get('hidpi')).toBeNull();
  });

  it('previews a theme with its color stylesheet and its mode on the root element', () => {
    renderSettings();
    setupSettings();

    select('#user_settings_theme_name', 'light');
    expect(document.documentElement.dataset.theme).toBe('light');
    expect($<HTMLLinkElement>('#js-theme-stylesheet')!.getAttribute('href')).toBe('/css/blue.css');

    select('#user_settings_theme_color', 'purple');
    expect($<HTMLLinkElement>('#js-theme-stylesheet')!.getAttribute('href')).toBe('/css/purple.css');
  });

  it('stores the local settings as they change', () => {
    renderSettings({ signedIn: false });
    setupSettings();

    fireEvent.click($<HTMLInputElement>('#user_hidpi')!);
    fireEvent.change(Object.assign($<HTMLInputElement>('#user_webm_volume')!, { value: '40' }));

    expect(store.get('hidpi')).toBe(true);
    expect(store.get('webm_volume')).toBe('40');
  });

  it('hides the autocomplete settings that do not apply', () => {
    renderSettings({ signedIn: false });
    setupSettings();

    const enable = $<HTMLInputElement>('#user_enable_search_ac')!;
    const hideHistory = $<HTMLInputElement>('#user_autocomplete_search_history_hidden')!;

    fireEvent.click(enable);
    expect($('.autocomplete-settings')).toHaveClass('hidden');
    fireEvent.click(enable);
    expect($('.autocomplete-settings')).not.toHaveClass('hidden');

    fireEvent.click(hideHistory);
    expect($('.autocomplete-search-history-settings')).toHaveClass('hidden');
  });

  it('toggles the help text of a field', () => {
    renderSettings({ signedIn: false });
    setupSettings();

    const help = $('.field-help-content')!;

    fireEvent.click($('.field-help-button i')!);
    expect(help).not.toHaveClass('hidden');
    fireEvent.click($('.field-help-button')!);
    expect(help).toHaveClass('hidden');

    fireEvent.click($('.lonely')!);
    fireEvent.click($('.field')!);
    fireEvent.click(document);
    expect(help).toHaveClass('hidden');
  });
});
