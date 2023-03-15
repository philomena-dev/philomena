// Module
import { $ } from '../utils/dom';
const profileWeb3 = function() {
  const profileHeadBase = $('#web3_profile_data');
  if (profileHeadBase) {

    const contentDiv = document.createElement('div');
    contentDiv.innerHTML = 'yay';

    profileHeadBase.insertBefore(contentDiv, $('#web3_profile_data #address'));

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
            content: 'Copy URL',
            events: {
              click: () => {

              }
            }
          },
          {
            content: 'Get User Amount',
            events: {
              click: () => {

              }
            }
          },
        ]
      });

      myMenu.init();

    }

  }
};

export { profileWeb3 };
