// More Modules
import { $ } from '../utils/dom';
import * as web3 from 'web3';

// Module
const startWeb3 = function() {

  // Check if Web3 has been injected by the browser (Mist/MetaMask).
  window.web3 = web3;
  if (typeof ethereum !== 'undefined') {
    window.tinyCrypto = { provider: new Web3(window.ethereum) };
  }

  // Detect Connect Wallet Buttom
  const connectWallet = $('#connect-web3-wallet');
  if (connectWallet) {
    connectWallet.addEventListener('click', () => {

      console.log('Test Wallet Buttom');

    });
  }

};

// Export Module
export { startWeb3 };
