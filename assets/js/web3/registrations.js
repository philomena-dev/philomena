// Module
import { $ } from '../utils/dom';
const configWeb3 = function() {

  // Detect Connect Wallet Buttom
  const connectWallet = $('#connect-web3-wallet');
  if (connectWallet) {
    connectWallet.addEventListener('click', () => {

      console.log('Test Wallet Buttom');

    });
  }

};

export { configWeb3 };
