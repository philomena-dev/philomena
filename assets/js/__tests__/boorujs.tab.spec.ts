import { describe, it, beforeEach, expect, vi } from 'vitest';
import { fireEvent, waitFor } from '@testing-library/dom';

// Mock requests before importing the module under test
vi.mock('../utils/requests', () => {
  return {
    fetchHtml: vi.fn(),
    handleError: vi.fn((r: unknown) => r),
  };
});

import { registerEvents } from '../boorujs';
import { fetchHtml } from '../utils/requests';

describe('boorujs tab loading', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    document.body.innerHTML = '';
  });

  it('loads remote tab content once and marks as loaded', async () => {
    (fetchHtml as unknown as ReturnType<typeof vi.fn>).mockResolvedValue(new Response('Loaded OK'));

    registerEvents();

    document.body.innerHTML = `
      <div class="block">
        <div class="block__nav">
          <a class="block__tab selected" data-click-tab="tab1">Tab 1</a>
          <a class="block__tab" data-click-tab="tab2" data-load-tab="/remote/tab2">Tab 2</a>
        </div>
        <div class="block__tab" data-tab="tab1">Content 1</div>
        <div class="block__tab" data-tab="tab2"></div>
      </div>
    `;

  const tab2Link = document.querySelector('[data-click-tab="tab2"]')! as HTMLElement;
  const tab2Content = document.querySelector('[data-tab="tab2"]')! as HTMLElement;

    fireEvent.click(tab2Link);

    await waitFor(() => {
      expect(tab2Content.innerHTML).toBe('Loaded OK');
      expect(tab2Content.dataset.loaded).toBe('true');
    });

    // Clicking again should not re-fetch because dataset.loaded is set
    fireEvent.click(tab2Link);
    expect(fetchHtml).toHaveBeenCalledTimes(1);
  });

  it('shows error text when tab load fails', async () => {
  (fetchHtml as unknown as ReturnType<typeof vi.fn>).mockRejectedValue(new Error('network'));

  registerEvents();

    document.body.innerHTML = `
      <div class="block">
        <div class="block__nav">
          <a class="block__tab" data-click-tab="tab2" data-load-tab="/remote/tab2">Tab 2</a>
        </div>
        <div class="block__tab" data-tab="tab2"></div>
      </div>
    `;

    const tab2Link = document.querySelector('[data-click-tab="tab2"]')! as HTMLElement;
    const tab2Content = document.querySelector('[data-tab="tab2"]')! as HTMLElement;

    fireEvent.click(tab2Link);

    await waitFor(() => {
      expect(tab2Content.textContent).toBe('Error!');
    });
  });
});
