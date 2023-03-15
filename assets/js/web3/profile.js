// Module
import { $ } from '../utils/dom';
const profileWeb3 = function() {
  const profileHeadBase = $('#web3_profile_data');
  if (profileHeadBase) {
    const address = $('#web3_profile_data #address').innerText.trim();
    for (const network in window.tinyCrypto.config.networks) {

      const contentDiv = document.createElement('div');
      contentDiv.innerHTML = `<a href="${window.tinyCrypto.config.networks[network].chainName.blockExplorerUrls[0]}address/${address}" target="_blank">${window.tinyCrypto.config.networks[network].chainName}</a>`;

      profileHeadBase.appendChild(contentDiv);

    }
  }
};

export { profileWeb3 };
