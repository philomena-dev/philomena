// https://www.cssscript.com/cool-custom-context-menu/
/* eslint-disable no-else-return */
/* eslint-disable brace-style */
class ContextMenu {
  constructor({ target = null, menuItems = [] }) {
    this.target = target;
    this.menuItems = menuItems;
    this.targetNode = this.getTargetNode();
    this.menuItemsNode = this.getMenuItemsNode();
    this.isOpened = false;
  }

  getTargetNode() {
    const nodes = document.querySelectorAll(this.target);

    if (nodes && nodes.length !== 0) {
      return nodes;
    } else {
      console.error(`getTargetNode :: '${this.target}' target not found`);
      return [];
    }
  }

  getMenuItemsNode() {
    const nodes = [];

    if (!this.menuItems) {
      console.error('getMenuItemsNode :: Please enter menu items');
      return [];
    }

    this.menuItems.forEach((data, index) => {
      const item = this.createItemMarkup(data);
      item.firstChild.setAttribute(
        'style',
        `animation-delay: ${index * 0.08}s`
      );
      nodes.push(item);
    });

    return nodes;
  }

  createItemMarkup(data) {
    const button = document.createElement('BUTTON');
    const item = document.createElement('LI');

    button.innerHTML = data.content;
    button.classList.add('contextMenu-button');
    item.classList.add('contextMenu-item');

    if (data.divider) item.setAttribute('data-divider', data.divider);
    item.appendChild(button);

    if (data.events && data.events.length !== 0) {
      Object.entries(data.events).forEach(event => {
        const [key, value] = event;
        button.addEventListener(key, value);
      });
    }

    return item;
  }

  renderMenu() {
    const menuContainer = document.createElement('UL');

    menuContainer.classList.add('contextMenu');
    this.menuItemsNode.forEach(item => menuContainer.appendChild(item));

    return menuContainer;
  }

  closeMenu(menu) {
    if (this.isOpened) {
      this.isOpened = false;
      menu.remove();
    }
  }

  init() {
    const contextMenu = this.renderMenu();
    document.addEventListener('click', () => this.closeMenu(contextMenu));
    window.addEventListener('blur', () => this.closeMenu(contextMenu));
    document.addEventListener('contextmenu', e => {
      this.targetNode.forEach(target => {
        if (!e.target.contains(target)) {
          contextMenu.remove();
        }
      });
    });

    this.targetNode.forEach(target => {
      target.addEventListener('contextmenu', e => {
        e.preventDefault();
        this.isOpened = true;

        const { clientX, clientY } = e;
        document.body.appendChild(contextMenu);

        const positionY =
          clientY + contextMenu.scrollHeight >= window.innerHeight
            ? window.innerHeight - contextMenu.scrollHeight - 20
            : clientY;
        const positionX =
          clientX + contextMenu.scrollWidth >= window.innerWidth
            ? window.innerWidth - contextMenu.scrollWidth - 20
            : clientX;

        contextMenu.setAttribute(
          'style',
          `--width: ${contextMenu.scrollWidth}px;
          --height: ${contextMenu.scrollHeight}px;
          --top: ${positionY}px;
          --left: ${positionX}px;`
        );
      });
    });
  }
}

const contextMenu = function() {
  window.ContextMenu = ContextMenu;
};

export { contextMenu };
