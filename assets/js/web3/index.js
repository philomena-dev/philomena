// More Modules
import { $ } from '../utils/dom';
import { web3Cfg } from '../../../web3/client.side.config';

// https://web3js.readthedocs.io/en/v1.8.2/index.html
import * as web3 from 'web3';

// Module
const startWeb3 = function() {

  // Prepare Web3 Object
  window.web3 = web3;
  window.tinyCrypto = {

    connected: false,
    providerConnected: false,
    protocol: null,

    config: web3Cfg(),
    call: {},

    callbacks: {
      accountsChanged: [],
      signerUpdated: []
    }

  };

  // Calls
  window.tinyCrypto.call.signerGetAddress = function() {
    console.log('signerGetAddress');
  };

  window.tinyCrypto.call.networkChanged = function(networkId) {
    console.log('networkChanged', networkId);
  };

  window.tinyCrypto.call.checkConnection = function() {
    console.log('checkConnection');
  };

  window.tinyCrypto.call.readyProvider = function() {
    console.log('readyProvider');
  };

  // Web3 Enabled on the website
  if (window.tinyCrypto.config.enabled) {

    // Check if Web3 has been injected by the browser (Mist/MetaMask).
    if (typeof ethereum !== 'undefined') {

      // Insert Provider
      // eslint-disable-next-line no-undef
      window.tinyCrypto.provider = new Web3(window.ethereum);
      window.tinyCrypto.providerConnected = true;

      // Is Metamask
      if (window.ethereum.isMetaMask) {

        // Insert Protocol
        window.tinyCrypto.protocol = 'metamask';

        // Change Account Detector
        window.ethereum.on('accountsChanged', accounts => {
          window.tinyCrypto.call.accountsChanged(accounts);
        });

        // Network Change
        window.ethereum.on('networkChanged', networkId => {
          window.tinyCrypto.call.networkChanged(networkId);
        });

        // Ready Provider and check the connection
        window.tinyCrypto.call.checkConnection();
        window.tinyCrypto.call.readyProvider();

      }

    }

    // Detect Connect Wallet Buttom
    const connectWallet = $('#connect-web3-wallet');
    if (connectWallet) {
      connectWallet.addEventListener('click', () => {

        console.log('Test Wallet Buttom');

      });
    }

  }

};

// Export Module
export { startWeb3 };
