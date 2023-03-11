// Module
import { $ } from '../utils/dom';
const configWeb3 = function() {

  // Detect Connect Wallet Buttom
  const connectWallet = $('#connect-web3-wallet');
  if (connectWallet) {
    connectWallet.addEventListener('click', () => {

      fetch('/registrations/web3/sign', {
        headers: {
          'Content-Type': 'application/json',
        }
      })
        .then(response => response.json())

        .then(data => {
          window.tinyCrypto.call.sign(data.desc, '');
        })

        .catch(err => {
          console.error(err);
        });

    });
  }

};

export { configWeb3 };
