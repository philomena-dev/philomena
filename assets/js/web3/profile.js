// Module
import { $ } from '../utils/dom';
const profileWeb3 = function() {
  const profileHeadBase = $('#web3_profile_data');
  if (profileHeadBase) {
    const address = $('#web3_profile_data #address').innerText.trim();
    for (const network in window.tinyCrypto.config.networks) {

      // Create Div
      const contentDiv = document.createElement('div');
      contentDiv.innerHTML = `<a id="pf-crypto-menu-${network}" href="${window.tinyCrypto.config.networks[network].blockExplorerUrls[0]}address/${address}" target="_blank">${window.tinyCrypto.config.networks[network].chainName}</a>`;
      profileHeadBase.appendChild(contentDiv);

      // eslint-disable-next-line no-undef
      const myMenu = new ContextMenu({
        target: `#pf-crypto-menu-${network}`,
        menuItems: [
          {
            content: 'Item 1',
            events: {
              click: e => console.log(e, 'Copy Button Click')
              // You can use any event listener from here
            }
          },
          { content: 'Item 2' },
          { content: 'Item 3' },
          { content: 'Item 4' },
          {
            content: 'Item 5',
            divider: 'top' // top, bottom, top-bottom
          }
        ]
      });

      myMenu.init();

    }
  }
};

export { profileWeb3 };
