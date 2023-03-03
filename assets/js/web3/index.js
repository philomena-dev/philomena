// More Modules
import { $ } from '../utils/dom';
import { EventEmitter } from 'events';
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

  };

  // Web3 Enabled on the website
  if (window.tinyCrypto.config.enabled) {

    // Check if Web3 has been injected by the browser (Mist/MetaMask).
    if (typeof ethereum !== 'undefined') {

      // Emitter
      class MyEmitter extends EventEmitter {}
      const myEmitter = new MyEmitter();

      window.tinyCrypto.on = function(where, callback) {
        return myEmitter.on(where, callback);
      };

      window.tinyCrypto.once = function(where, callback) {
        return myEmitter.once(where, callback);
      };

      // Calls

      // Account Change
      window.tinyCrypto.call.accountsChanged = function(accounts) {
        return new Promise((resolve, reject) => {

          // Address
          window.tinyCrypto.signer = window.tinyCrypto.provider.getSigner();
          window.tinyCrypto.call.signerUpdated('accountsChanged');

          window.tinyCrypto.call.signerGetAddress().then(address => {

            window.tinyCrypto.address = address;
            if (window.tinyCrypto.address) {

              window.tinyCrypto.address = window.tinyCrypto.address.toLowerCase();

              if (localStorage) {
                localStorage.setItem('web3_address', window.tinyCrypto.address);
              }

              window.tinyCrypto.accounts = accounts;
              myEmitter.emit('accountsChanged', accounts);
              resolve(accounts);

            }

          }).catch(reject);

        });
      };

      // Warn Signer Updated
      window.tinyCrypto.call.signerUpdated = function(where) {
        myEmitter.emit('signerUpdated', { where });
      };

      // Coming Soon
      window.tinyCrypto.call.signerGetAddress = function() {
        return new Promise(resolve => {
          console.log('signerGetAddress');
          resolve();
        });
      };

      // Network Changed
      window.tinyCrypto.call.networkChanged = function(networkId) {

        window.tinyCrypto.networkId = networkId;

        if (localStorage) {
          localStorage.setItem('web3_network_id', networkId);
        }

        myEmitter.emit('networkChanged', networkId);

      };

      // Coming Soon
      window.tinyCrypto.call.checkConnection = function() {
        console.log('checkConnection');
      };

      // Coming Soon
      window.tinyCrypto.call.readyProvider = function() {
        console.log('readyProvider');
      };

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
