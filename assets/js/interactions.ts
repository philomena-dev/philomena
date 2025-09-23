/**
 * Interactions.
 */

import { fetchJson } from './utils/requests';
import { $, $$ } from './utils/dom';

const endpoints = {
  vote(imageId: string) {
    return `/images/${imageId}/vote`;
  },
  fave(imageId: string) {
    return `/images/${imageId}/fave`;
  },
  hide(imageId: string) {
    return `/images/${imageId}/hide`;
  },
} as const;

type EndpointType = keyof typeof endpoints;

type InteractionValue = 'up' | 'down' | '' | null;

export interface InteractionRecord {
  image_id: string | number;
  interaction_type: 'voted' | 'faved' | 'hidden';
  value?: InteractionValue;
}

interface ScorePayload {
  score: string | number;
  faves: string | number;
  upvotes: string | number;
  downvotes: string | number;
}

interface CacheRecord {
  imageId: string;
  interactionType: 'voted' | 'faved' | 'hidden';
  value: '' | 'up' | 'down';
}

const spoilerDownvoteMsg = 'Neigh! - Remove spoilered tags from your filters to downvote from thumbnails';

/**
 * Quick helper function to less verbosely iterate a QSA
 */
function onImage(id: string, selector: string, cb: (node: HTMLElement) => unknown) {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  ([] as any[]).forEach.call($$(`${selector}[data-image-id="${id}"]`), cb);
}

/* Since JS modifications to webpages, except form inputs, are not stored
 * in the browser navigation history, we store a cache of the changes in a
 * form to allow interactions to persist on navigation. */

function getCache() {
  const cacheEl = $<HTMLInputElement>('.js-interaction-cache')!;
  return Object.values(JSON.parse(cacheEl.value)) as CacheRecord[];
}

function modifyCache(callback: (cache: Record<string, CacheRecord>) => Record<string, CacheRecord>) {
  const cacheEl = $<HTMLInputElement>('.js-interaction-cache')!;
  cacheEl.value = JSON.stringify(callback(JSON.parse(cacheEl.value)));
}

function cacheStatus(imageId: string, interactionType: CacheRecord['interactionType'], value: CacheRecord['value']) {
  modifyCache(cache => {
    cache[`${imageId}${interactionType}`] = { imageId, interactionType, value };
    return cache;
  });
}

function uncacheStatus(imageId: string, interactionType: CacheRecord['interactionType']) {
  modifyCache(cache => {
    // eslint-disable-next-line @typescript-eslint/no-dynamic-delete
    delete cache[`${imageId}${interactionType}`];
    return cache;
  });
}

function setScore(imageId: string, data: ScorePayload) {
  onImage(imageId, '.score', el => {
    el.textContent = String(data.score);
  });
  onImage(imageId, '.favorites', el => {
    el.textContent = String(data.faves);
  });
  onImage(imageId, '.upvotes', el => {
    el.textContent = String(data.upvotes);
  });
  onImage(imageId, '.downvotes', el => {
    el.textContent = String(data.downvotes);
  });
}

/* These change the visual appearance of interaction links.
 * Their classes also effect their behavior due to event delegation. */

function showUpvoted(imageId: string) {
  cacheStatus(imageId, 'voted', 'up');
  onImage(imageId, '.interaction--upvote', el => el.classList.add('active'));
}

function showDownvoted(imageId: string) {
  cacheStatus(imageId, 'voted', 'down');
  onImage(imageId, '.interaction--downvote', el => el.classList.add('active'));
}

function showFaved(imageId: string) {
  cacheStatus(imageId, 'faved', '');
  onImage(imageId, '.interaction--fave', el => el.classList.add('active'));
}

function showHidden(imageId: string) {
  cacheStatus(imageId, 'hidden', '');
  onImage(imageId, '.interaction--hide', el => el.classList.add('active'));
}

function resetVoted(imageId: string) {
  uncacheStatus(imageId, 'voted');
  onImage(imageId, '.interaction--upvote', el => el.classList.remove('active'));
  onImage(imageId, '.interaction--downvote', el => el.classList.remove('active'));
}

function resetFaved(imageId: string) {
  uncacheStatus(imageId, 'faved');
  onImage(imageId, '.interaction--fave', el => el.classList.remove('active'));
}

function resetHidden(imageId: string) {
  uncacheStatus(imageId, 'hidden');
  onImage(imageId, '.interaction--hide', el => el.classList.remove('active'));
}

function interact(type: EndpointType, imageId: string, method: 'POST' | 'DELETE', data: Record<string, unknown> = {}) {
  const callFetch = fetchJson as unknown as (
    verb: string,
    endpoint: string,
    body?: Record<string, unknown>,
  ) => Promise<Response>;
  return callFetch(method, endpoints[type](imageId), data)
    .then(res => res.json())
    .then((res: ScorePayload) => setScore(imageId, res));
}

function displayInteractionSet(interactions: (InteractionRecord | CacheRecord)[]) {
  interactions.forEach(i => {
    if ('image_id' in i) {
      const imageId = String(i.image_id);
      switch (i.interaction_type) {
        case 'faved':
          showFaved(imageId);
          break;
        case 'hidden':
          showHidden(imageId);
          break;
        default:
          if (i.value === 'up') showUpvoted(imageId);
          if (i.value === 'down') showDownvoted(imageId);
      }
    } else {
      const imageId = String(i.imageId);
      switch (i.interactionType) {
        case 'faved':
          showFaved(imageId);
          break;
        case 'hidden':
          showHidden(imageId);
          break;
        default:
          if (i.value === 'up') showUpvoted(imageId);
          if (i.value === 'down') showDownvoted(imageId);
      }
    }
  });
}

function loadInteractions() {
  /* Set up the actual interactions */
  displayInteractionSet(window.booru.interactions as unknown as InteractionRecord[]);
  displayInteractionSet(getCache());

  /* Next part is only for image index pages
   * TODO: find a better way to do this */
  if (!$('#imagelist-container')) return;

  /* Users will blind downvote without this */
  window.booru.imagesWithDownvotingDisabled.forEach(i => {
    onImage(i, '.interaction--downvote', a => {
      // TODO Use a 'js-' class to target these instead
      const icon = $('i', a) || $('.oc-icon-small', a) || (a as unknown as HTMLElement);

      icon.setAttribute('title', spoilerDownvoteMsg);
      a.classList.add('disabled');
    });
  });
}

const targets: Record<string, (imageId: string) => unknown> = {
  /* Active-state targets first */
  '.interaction--upvote.active'(imageId: string) {
    interact('vote', imageId, 'DELETE').then(() => resetVoted(imageId));
  },
  '.interaction--downvote.active'(imageId: string) {
    if (downvoteRestricted(imageId)) {
      return;
    }

    interact('vote', imageId, 'DELETE').then(() => resetVoted(imageId));
  },
  '.interaction--fave.active'(imageId: string) {
    interact('fave', imageId, 'DELETE').then(() => resetFaved(imageId));
  },
  '.interaction--hide.active'(imageId: string) {
    interact('hide', imageId, 'DELETE').then(() => resetHidden(imageId));
  },

  /* Inactive targets */
  '.interaction--upvote:not(.active)'(imageId: string) {
    interact('vote', imageId, 'POST', { up: true }).then(() => {
      resetVoted(imageId);
      showUpvoted(imageId);
    });
  },
  '.interaction--downvote:not(.active)'(imageId: string) {
    if (downvoteRestricted(imageId)) {
      return;
    }

    interact('vote', imageId, 'POST', { up: false }).then(() => {
      resetVoted(imageId);
      showDownvoted(imageId);
    });
  },
  '.interaction--fave:not(.active)'(imageId: string) {
    interact('fave', imageId, 'POST').then(() => {
      resetVoted(imageId);
      showFaved(imageId);
      showUpvoted(imageId);
    });
  },
  '.interaction--hide:not(.active)'(imageId: string) {
    interact('hide', imageId, 'POST').then(() => {
      showHidden(imageId);
    });
  },
};

/**
 * Allow downvoting of the images only if the user is on the image page
 * or the image is not spoilered.
 */
function downvoteRestricted(imageId: string) {
  // The `imagelist-container` indicates that we are on the page with the list of images
  return Boolean($('#imagelist-container')) && window.booru.imagesWithDownvotingDisabled.includes(imageId);
}

function bindInteractions() {
  document.addEventListener('click', event => {
    if ((event as MouseEvent).button === 0) {
      // Is it a left-click?
      for (const target in targets) {
        /* Event delegation doesn't quite grab what we want here. */
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const link = (event.target as any) && (event.target as Element).closest?.(target);

        if (link) {
          event.preventDefault();
          targets[target]((link as HTMLElement).dataset.imageId as string);
        }
      }
    }
  });
}

function loggedOutInteractions() {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  ([] as any[]).forEach.call($$('.interaction--fave,.interaction--upvote,.interaction--downvote'), (a: HTMLElement) =>
    a.setAttribute('href', '/sessions/new'),
  );
}

function setupInteractions() {
  if (window.booru.userIsSignedIn) {
    bindInteractions();
    loadInteractions();
  } else {
    loggedOutInteractions();
  }
}

export { setupInteractions, displayInteractionSet };
