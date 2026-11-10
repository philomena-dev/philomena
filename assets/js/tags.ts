/**
 * Tags Dropdown
 */

import { $$, showEl, makeEl, hideIf, $, setClassIf } from './utils/dom';
import { assertNotNull, assertNotUndefined } from './utils/assert';

interface TagState {
  icon: HTMLElement;
  tags: number[];
  enableElem: HTMLElement;
  disableElem: HTMLElement;
  authorized: boolean;
}

function createTagDropdown(dropdown: HTMLElement) {
  const id = parseInt(assertNotUndefined(dropdown.dataset.tagId), 10);
  const tag = assertNotNull($<HTMLElement>('.tag', dropdown));
  const name = assertNotNull($<HTMLElement>('.tag-name', tag));

  const { userIsSignedIn, userCanEditFilter } = window.booru;
  const [unwatch, watch, unspoiler, spoiler, unhide, hide, signIn, filter] = $$<HTMLElement>(
    '.dropdown-item',
    dropdown,
  );

  const icon = (title: string, className: string) =>
    makeEl('span', { className: 'tag-icon', title }, [makeEl('i', { className })]);

  const watched: TagState = {
    authorized: userIsSignedIn,
    enableElem: watch,
    disableElem: unwatch,
    icon: icon('Watched', 'fa fa-bookmark'),
    tags: window.booru.watchedTagList,
  };
  const spoilered: TagState = {
    authorized: userCanEditFilter,
    enableElem: spoiler,
    disableElem: unspoiler,
    icon: icon('Spoilered', 'fa fa-eye-low-vision'),
    tags: window.booru.spoileredTagList,
  };
  const hidden: TagState = {
    authorized: userCanEditFilter,
    enableElem: hide,
    disableElem: unhide,
    icon: icon('Hidden', 'fa fa-ban'),
    tags: window.booru.hiddenTagList,
  };

  const states = [watched, spoilered, hidden];
  const has = (state: TagState) => state.tags.includes(id);
  const add = (state: TagState) => state.tags.push(id);
  const remove = (state: TagState) => state.tags.splice(state.tags.indexOf(id), 1);

  const actions: Record<string, () => void> = {
    unwatch: () => remove(watched),
    watch: () => add(watched),
    unspoiler: () => remove(spoilered),
    spoiler: () => add(spoilered),
    unhide: () => remove(hidden),
    hide: () => add(hidden),
  };

  // The icons of the states the tag is in sit before its name, in the order of the states
  const refresh = () => {
    for (const state of states) {
      state.icon.remove();

      if (state.authorized) {
        hideIf(has(state), state.enableElem);
        hideIf(!has(state), state.disableElem);
      }
    }

    name.before(...states.filter(has).map(state => state.icon));
    setClassIf(has(spoilered) || has(hidden), tag, 'muted');
  };

  if (!userIsSignedIn) showEl(signIn);
  if (userIsSignedIn && !userCanEditFilter) showEl(filter);

  dropdown.addEventListener('fetchcomplete', event => {
    actions[assertNotUndefined(event.target.dataset.tagAction)]();
    refresh();
  });

  refresh();
}

export function initTagDropdown() {
  for (const dropdown of $$<HTMLElement>('.dropdown[data-tag-id]')) {
    createTagDropdown(dropdown);
  }
}
