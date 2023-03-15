// Module
import { $ } from '../utils/dom';
const profileWeb3 = function() {
  const profileHeadBase = $('#web3_profile_data');
  if (profileHeadBase) {

    // QRcode
    const address = $('#web3_profile_data #address').innerText.trim();
    $('#web3_profile_data #wallet_qr_code > a').addEventListener('click', e => {

      if (!window.tinyCrypto.warn.addressCanvas) {
        window.tinyCrypto.warn.addressCanvas = true;

        const tinyCenter = document.createElement('center');
        const ethAddressQRCode = document.createElement('canvas');
        ethAddressQRCode.id = 'web3_wallet_qr_code';
        tinyCenter.appendChild(ethAddressQRCode);

        profileHeadBase.insertBefore(tinyCenter, $('#web3_profile_data #wallet_qr_code'));
        window.qrcode.toCanvas(ethAddressQRCode, address, err => {
          if (err) { console.error(err); }
        });

      }

      e.preventDefault();

    });

    // Get User Amount
    // eslint-disable-next-line no-loop-func
    const getUserAmount = function(contentDiv, cryptoCfg, network) {
      if (!window.tinyCrypto.warn[`${network}_profile_click`]) {
        window.tinyCrypto.warn[`${network}_profile_click`] = true;
        fetch(`${cryptoCfg.blockExplorerApis[0]}api?module=account&action=balance&address=${address}&tag=latest`).then(response => response.json()).then(data => {

          const newWarning = document.createElement('div');

          if (String(data.status) === '1') {
            // eslint-disable-next-line no-undef
            newWarning.innerHTML = `<small>${Number(Web3.utils.fromWei(String(data.result))).toFixed(9)} ${cryptoCfg.nativeCurrency.symbol}</small>`;
          }

          else {
            newWarning.innerHTML = data.message;
          }

          contentDiv.insertBefore(newWarning, $(`#web3_profile_information_${network} #powered_by`));

        }).catch(console.error);
      }
    };

    // Read Networks
    for (const network in window.tinyCrypto.config.networks) {

      // Crypto Config
      const cryptoCfg = window.tinyCrypto.config.networks[network];

      // Create Div
      const contentDiv = document.createElement('div');
      contentDiv.id = `web3_profile_information_${network}`;
      contentDiv.innerHTML = `<br/><a id="pf-crypto-menu" href="#">${cryptoCfg.chainName}</a><br/><small id="powered_by">Powered by <a href="${cryptoCfg.blockExplorerUrls[0]}address/${address}" target="_blank">${cryptoCfg.blockExplorerUrls[0]}</small><br/>`;
      profileHeadBase.appendChild(contentDiv);

      $(`#web3_profile_information_${network} #pf-crypto-menu`).addEventListener('click', e => {
        getUserAmount(contentDiv, cryptoCfg, network);
        e.preventDefault();
      });

      // eslint-disable-next-line no-undef
      const myMenu = new ContextMenu({
        target: `#web3_profile_information_${network} #pf-crypto-menu`,
        menuItems: [
          {
            content: 'Copy URL',
            events: {
              click: () => {
                navigator.clipboard.writeText(`${cryptoCfg.blockExplorerUrls[0]}address/${address}`).catch(console.error);
              }
            }
          },
          {
            content: 'Get User Amount',
            events: {
              click: () => { getUserAmount(contentDiv, cryptoCfg, network); }
            }
          },
        ]
      });

      myMenu.init();

    }

  }
};

export { profileWeb3 };
