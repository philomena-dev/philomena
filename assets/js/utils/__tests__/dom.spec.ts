import { $, $$, hideEl, showEl, toggleEl, clearEl, removeEl } from '../dom';
import { getRandomIntBetween } from '../../../test/randomness';

describe('DOM Utilities', () => {
  const mockSelectors = ['#id', '.class', 'div', '#a .complex--selector:not(:hover)'];
  const hiddenClass = 'hidden';
  const createHiddenElement: Document['createElement'] = (...params: Parameters<Document['createElement']>) => {
    const el = document.createElement(...params);
    el.classList.add(hiddenClass);
    return el;
  };

  describe('$', () => {
    afterEach(() => {
      jest.restoreAllMocks();
    });

    it('should call the native querySelector method on document by default', () => {
      const spy = jest.spyOn(document, 'querySelector');

      mockSelectors.forEach((selector, nthCall) => {
        $(selector);
        expect(spy).toHaveBeenNthCalledWith(nthCall + 1, selector);
      });
    });

    it('should call the native querySelector method on the passed element', () => {
      const mockElement = document.createElement('br');
      const spy = jest.spyOn(mockElement, 'querySelector');

      mockSelectors.forEach((selector, nthCall) => {
        // FIXME This will not be necessary once the file is properly typed
        $(selector, mockElement as unknown as Document);
        expect(spy).toHaveBeenNthCalledWith(nthCall + 1, selector);
      });
    });
  });

  describe('$$', () => {
    afterEach(() => {
      jest.restoreAllMocks();
    });

    it('should call the native querySelectorAll method on document by default', () => {
      const spy = jest.spyOn(document, 'querySelectorAll');

      mockSelectors.forEach((selector, nthCall) => {
        $$(selector);
        expect(spy).toHaveBeenNthCalledWith(nthCall + 1, selector);
      });
    });

    it('should call the native querySelectorAll method on the passed element', () => {
      const mockElement = document.createElement('br');
      const spy = jest.spyOn(mockElement, 'querySelectorAll');

      mockSelectors.forEach((selector, nthCall) => {
        // FIXME This will not be necessary once the file is properly typed
        $$(selector, mockElement as unknown as Document);
        expect(spy).toHaveBeenNthCalledWith(nthCall + 1, selector);
      });
    });
  });

  describe('showEl', () => {
    it(`should remove the ${hiddenClass} class from the provided element`, () => {
      const mockElement = createHiddenElement('div');
      showEl(mockElement);
      expect(mockElement).not.toHaveClass(hiddenClass);
    });

    it(`should remove the ${hiddenClass} class from all provided elements`, () => {
      const mockElements = [
        createHiddenElement('div'),
        createHiddenElement('a'),
        createHiddenElement('strong'),
      ];
      showEl(mockElements);
      expect(mockElements[0]).not.toHaveClass(hiddenClass);
      expect(mockElements[1]).not.toHaveClass(hiddenClass);
      expect(mockElements[2]).not.toHaveClass(hiddenClass);
    });

    it(`should remove the ${hiddenClass} class from elements provided in multiple arrays`, () => {
      const mockElements1 = [
        createHiddenElement('div'),
        createHiddenElement('a'),
      ];
      const mockElements2 = [
        createHiddenElement('strong'),
        createHiddenElement('em'),
      ];
      showEl(mockElements1, mockElements2);
      expect(mockElements1[0]).not.toHaveClass(hiddenClass);
      expect(mockElements1[1]).not.toHaveClass(hiddenClass);
      expect(mockElements2[0]).not.toHaveClass(hiddenClass);
      expect(mockElements2[1]).not.toHaveClass(hiddenClass);
    });
  });

  describe('hideEl', () => {
    it(`should add the ${hiddenClass} class to the provided element`, () => {
      const mockElement = document.createElement('div');
      hideEl(mockElement);
      expect(mockElement).toHaveClass(hiddenClass);
    });

    it(`should add the ${hiddenClass} class to all provided elements`, () => {
      const mockElements = [
        document.createElement('div'),
        document.createElement('a'),
        document.createElement('strong'),
      ];
      hideEl(mockElements);
      expect(mockElements[0]).toHaveClass(hiddenClass);
      expect(mockElements[1]).toHaveClass(hiddenClass);
      expect(mockElements[2]).toHaveClass(hiddenClass);
    });

    it(`should add the ${hiddenClass} class to elements provided in multiple arrays`, () => {
      const mockElements1 = [
        document.createElement('div'),
        document.createElement('a'),
      ];
      const mockElements2 = [
        document.createElement('strong'),
        document.createElement('em'),
      ];
      hideEl(mockElements1, mockElements2);
      expect(mockElements1[0]).toHaveClass(hiddenClass);
      expect(mockElements1[1]).toHaveClass(hiddenClass);
      expect(mockElements2[0]).toHaveClass(hiddenClass);
      expect(mockElements2[1]).toHaveClass(hiddenClass);
    });
  });

  describe('toggleEl', () => {
    it(`should toggle the ${hiddenClass} class on the provided element`, () => {
      const mockVisibleElement = document.createElement('div');
      toggleEl(mockVisibleElement);
      expect(mockVisibleElement).toHaveClass(hiddenClass);

      const mockHiddenElement = createHiddenElement('div');
      toggleEl(mockHiddenElement);
      expect(mockHiddenElement).not.toHaveClass(hiddenClass);
    });

    it(`should toggle the ${hiddenClass} class on all provided elements`, () => {
      const mockElements = [
        document.createElement('div'),
        createHiddenElement('a'),
        document.createElement('strong'),
        createHiddenElement('em'),
      ];
      toggleEl(mockElements);
      expect(mockElements[0]).toHaveClass(hiddenClass);
      expect(mockElements[1]).not.toHaveClass(hiddenClass);
      expect(mockElements[2]).toHaveClass(hiddenClass);
      expect(mockElements[3]).not.toHaveClass(hiddenClass);
    });

    it(`should toggle the ${hiddenClass} class on elements provided in multiple arrays`, () => {
      const mockElements1 = [
        createHiddenElement('div'),
        document.createElement('a'),
      ];
      const mockElements2 = [
        createHiddenElement('strong'),
        document.createElement('em'),
      ];
      toggleEl(mockElements1, mockElements2);
      expect(mockElements1[0]).not.toHaveClass(hiddenClass);
      expect(mockElements1[1]).toHaveClass(hiddenClass);
      expect(mockElements2[0]).not.toHaveClass(hiddenClass);
      expect(mockElements2[1]).toHaveClass(hiddenClass);
    });
  });

  describe('clearEl', () => {
    it('should not throw an exception for empty element', () => {
      const emptyElement = document.createElement('br');
      expect(emptyElement.children).toHaveLength(0);
      expect(() => clearEl(emptyElement)).not.toThrow();
      expect(emptyElement.children).toHaveLength(0);
    });

    it('should remove a single child node', () => {
      const baseElement = document.createElement('p');
      baseElement.appendChild(document.createElement('br'));
      expect(baseElement.children).toHaveLength(1);
      clearEl(baseElement);
      expect(baseElement.children).toHaveLength(0);
    });

    it('should remove a multiple child nodes', () => {
      const baseElement = document.createElement('p');
      const elementsToAdd = getRandomIntBetween(5, 10);
      for (let i = 0; i < elementsToAdd; ++i) {
        baseElement.appendChild(document.createElement('br'));
      }
      expect(baseElement.children).toHaveLength(elementsToAdd);
      clearEl(baseElement);
      expect(baseElement.children).toHaveLength(0);
    });

    it('should remove child nodes of elements provided in multiple arrays', () => {
      const baseElement1 = document.createElement('p');
      const elementsToAdd1 = getRandomIntBetween(5, 10);
      for (let i = 0; i < elementsToAdd1; ++i) {
        baseElement1.appendChild(document.createElement('br'));
      }
      expect(baseElement1.children).toHaveLength(elementsToAdd1);

      const baseElement2 = document.createElement('p');
      const elementsToAdd2 = getRandomIntBetween(5, 10);
      for (let i = 0; i < elementsToAdd2; ++i) {
        baseElement2.appendChild(document.createElement('br'));
      }
      expect(baseElement2.children).toHaveLength(elementsToAdd2);

      clearEl([baseElement1], [baseElement2]);
      expect(baseElement1.children).toHaveLength(0);
      expect(baseElement2.children).toHaveLength(0);
    });
  });

  describe('removeEl', () => {
    afterEach(() => {
      jest.restoreAllMocks();
    });

    it('should throw error if element has no parent', () => {
      const detachedElement = document.createElement('div');
      expect(() => removeEl(detachedElement)).toThrow(/propert(y|ies).*null/);
    });

    it('should call the native removeElement method on parent', () => {
      const parentNode = document.createElement('div');
      const childNode = document.createElement('p');
      parentNode.appendChild(childNode);

      const spy = jest.spyOn(parentNode, 'removeChild');

      removeEl(childNode);
      expect(spy).toHaveBeenCalledTimes(1);
      expect(spy).toHaveBeenNthCalledWith(1, childNode);
    });
  });
});
