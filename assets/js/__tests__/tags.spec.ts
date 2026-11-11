import { $, $$ } from '../utils/dom';
import { assertNotNull } from '../utils/assert';
import { fireEvent } from '@testing-library/dom';
import { initTagDropdown } from '../tags';

const tagMarkup = `<div class="dropdown manual" data-tag-id="1">
  <span class="tag" aria-haspopup="true"><a class="tag-name" href="/tags/safe">safe</a><span class="tag-count">5</span></span>
  <div class="dropdown-menu">
    <a class="dropdown-item hidden" data-tag-action="unwatch">Unwatch</a>
    <a class="dropdown-item hidden" data-tag-action="watch">Watch</a>
    <a class="dropdown-item hidden" data-tag-action="unspoiler">Unspoiler</a>
    <a class="dropdown-item hidden" data-tag-action="spoiler">Spoiler</a>
    <a class="dropdown-item hidden" data-tag-action="unhide">Unhide</a>
    <a class="dropdown-item hidden" data-tag-action="hide">Hide</a>
    <a class="dropdown-item hidden">Sign in to Watch</a>
    <a class="dropdown-item hidden">Filter</a>
  </div>
</div>`;

const { userIsSignedIn, userCanEditFilter, watchedTagList, spoileredTagList, hiddenTagList } = window.booru;

function setup(booru: Partial<typeof window.booru>) {
  Object.assign(window.booru, { watchedTagList: [], spoileredTagList: [], hiddenTagList: [], ...booru });
  document.body.innerHTML = tagMarkup;
  initTagDropdown();
}

const tag = () => assertNotNull($<HTMLElement>('.tag'));
const icons = () => $$<HTMLElement>('.tag-icon', tag()).map(icon => icon.title);
const shownItems = () => $$<HTMLElement>('.dropdown-item:not(.hidden)').map(item => item.textContent);
const item = (action: string) => assertNotNull($<HTMLElement>(`[data-tag-action="${action}"]`));

describe('Tag dropdown', () => {
  afterEach(() => {
    Object.assign(window.booru, { userIsSignedIn, userCanEditFilter, watchedTagList, spoileredTagList, hiddenTagList });
  });

  it('offers only signing in to anonymous users', () => {
    setup({ userIsSignedIn: false, userCanEditFilter: false });

    expect(shownItems()).toEqual(['Sign in to Watch']);
    expect(icons()).toEqual([]);
  });

  it('lets the menu open on hover once its items are picked', () => {
    setup({ userIsSignedIn: true, userCanEditFilter: true });

    expect(assertNotNull($('.dropdown'))).not.toHaveClass('manual');
  });

  it('offers watching and a link to the filters to users who cannot edit their filter', () => {
    setup({ userIsSignedIn: true, userCanEditFilter: false });

    expect(shownItems()).toEqual(['Watch', 'Filter']);
  });

  it('marks the states of the tag with icons before its name and mutes it when spoilered or hidden', () => {
    setup({ userIsSignedIn: true, userCanEditFilter: true, watchedTagList: [1], hiddenTagList: [1] });

    expect(icons()).toEqual(['Watched', 'Hidden']);
    expect(assertNotNull($('.tag-name')).previousElementSibling?.getAttribute('title')).toBe('Hidden');
    expect(tag()).toHaveClass('muted');
    expect(shownItems()).toEqual(['Unwatch', 'Spoiler', 'Unhide']);
  });

  it('follows the state when an action completes', () => {
    setup({ userIsSignedIn: true, userCanEditFilter: true });
    expect(tag()).not.toHaveClass('muted');

    fireEvent(item('spoiler'), new CustomEvent('fetchcomplete', { bubbles: true }));
    fireEvent(item('watch'), new CustomEvent('fetchcomplete', { bubbles: true }));

    expect(icons()).toEqual(['Watched', 'Spoilered']);
    expect(tag()).toHaveClass('muted');
    expect(shownItems()).toEqual(['Unwatch', 'Unspoiler', 'Hide']);

    fireEvent(item('unspoiler'), new CustomEvent('fetchcomplete', { bubbles: true }));

    expect(icons()).toEqual(['Watched']);
    expect(tag()).not.toHaveClass('muted');
    expect(shownItems()).toEqual(['Unwatch', 'Spoiler', 'Hide']);

    fireEvent(item('hide'), new CustomEvent('fetchcomplete', { bubbles: true }));
    expect(icons()).toEqual(['Watched', 'Hidden']);

    fireEvent(item('unhide'), new CustomEvent('fetchcomplete', { bubbles: true }));
    fireEvent(item('unwatch'), new CustomEvent('fetchcomplete', { bubbles: true }));
    expect(icons()).toEqual([]);
    expect(shownItems()).toEqual(['Watch', 'Spoiler', 'Hide']);
  });
});
