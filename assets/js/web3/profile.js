/* eslint-disable no-undef */
/* eslint-disable no-loop-func */

// Module
import { $ } from '../utils/dom';
const profileWeb3 = function() {
  const profileHeadBase = $('#web3_profile_data');
  if (profileHeadBase) {

    const ethAddressQRCode = document.createElement('canvas');
    const address = $('#web3_profile_data #address').innerText.trim();
    profileHeadBase.insertBefore(ethAddressQRCode, $('#web3_profile_data #address'));
    window.qrcode.toCanvas(ethAddressQRCode, address, err => {
      if (err) { console.error(err); }
    });

    for (const network in window.tinyCrypto.config.networks) {

      // Create Div
      const contentDiv = document.createElement('div');
      contentDiv.innerHTML = `<br/><a id="pf-crypto-menu-${network}" href="#" target="_blank">${window.tinyCrypto.config.networks[network].chainName}</a><br/><small>Powered by <a href="${window.tinyCrypto.config.networks[network].blockExplorerUrls[0]}address/${address}" target="_blank">${window.tinyCrypto.config.networks[network].blockExplorerUrls[0]}</small><br/>`;
      profileHeadBase.appendChild(contentDiv);

      // Get User Amount
      const getUserAmount = function() {
        fetch(`${window.tinyCrypto.config.networks[network].blockExplorerApis[0]}api?module=account&action=balance&address=${address}&tag=latest`).then(response => response.json()).then(data => {
          console.log(data);
        }).catch(console.error);
      };

      $(`#pf-crypto-menu-${network}`).addEventListener('click', () => {
        getUserAmount();
        preventDefault();
      });

      // eslint-disable-next-line no-undef
      const myMenu = new ContextMenu({
        target: `#pf-crypto-menu-${network}`,
        menuItems: [
          {
            content: 'Copy URL',
            events: {
              click: () => {
                navigator.clipboard.writeText(`${window.tinyCrypto.config.networks[network].blockExplorerUrls[0]}address/${address}`).catch(console.error);
              }
            }
          },
          {
            content: 'Get User Amount',
            events: {
              click: () => { getUserAmount(); }
            }
          },
        ]
      });

      myMenu.init();

    }

  }
};

export { profileWeb3 };
