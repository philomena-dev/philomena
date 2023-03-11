// Module
import { $ } from '../utils/dom';
const configWeb3 = function() {

  // Detect Connect Wallet Buttom
  const connectWallet = $('#connect-web3-wallet');
  if (connectWallet) {
    connectWallet.addEventListener('click', () => {
      window.tinyCrypto.call.sign('', '');
    });
  }

};

export { configWeb3 };
