/**
 * The features the CSS keeps although a browser of the floor lacks them, as browser-compat-data paths (a path also
 * covers the values and other subfeatures under it), each with the reason why its absence leaves the look intact.
 * The CSS gate accepts them and the floor-selectors plugin keeps the selectors among them. Add an entry only for an
 * enhancement: nothing whose absence changes the layout or leaves a component unstyled.
 */
export const enhancements: Record<string, string> = {
  'css.properties.accent-color': 'native checkboxes and radios keep the browser color',
  'css.properties.field-sizing': 'a field keeps the size its rows and size attributes give it',
  'css.properties.scrollbar-color': 'Chromium and Safari take the ::-webkit-scrollbar rules under @supports not',
  'css.properties.scrollbar-width': 'Chromium and Safari take the ::-webkit-scrollbar rules under @supports not',
  'css.properties.backdrop-filter': 'the page behind an open popup is not blurred',
  'css.properties.text-size-adjust': 'only mobile browsers enlarge text, and iOS reads the -webkit- form',
  'css.properties.resize': 'a textarea keeps the resize handle of the browser',
  'css.properties.cursor': 'touch screens show no pointer',
  'css.selectors.backdrop': 'Safari 14 has no <dialog> to draw a backdrop for',
  'css.properties.user-select.all': 'a click selects a word of a copyable text rather than all of it',
  'css.properties.font-synthesis': 'the icon font has every weight and style it is used in, nothing to synthesize',
  // The framework's anchored popups, under @supports (position-anchor: …)
  'css.properties.top.anchor': 'popups are centered, as in every browser without anchor positioning',
  'css.properties.left.anchor': 'popups are centered, as in every browser without anchor positioning',
};
