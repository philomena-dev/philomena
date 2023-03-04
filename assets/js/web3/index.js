// More Modules
import { EventEmitter } from 'events';
import { web3Cfg } from '../../../web3/client.side.config';
import { configWeb3 } from './registrations';
import * as web3 from 'web3';

// Module
const startWeb3 = function() {

  // Prepare Web3 Object
  window.web3 = web3;
  window.tinyCrypto = {

    connected: false,
    providerConnected: false,
    protocol: null,

    constants: {
      HexZero: '0x0000000000000000000000000000000000000000000000000000000000000000'
    },

    config: web3Cfg(),
    call: {},
    get: {},
    contracts: {},

  };

  // Web3 Enabled on the website
  if (window.tinyCrypto.config.enabled) {

    // Check if Web3 has been injected by the browser (Mist/MetaMask).
    if (typeof ethereum !== 'undefined' && window.ethereum.isMetaMask) {

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
          window.tinyCrypto.get.signerAddress().then(address => {

            window.tinyCrypto.address = address;
            if (window.tinyCrypto.address) {

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

      // Get Signer Address
      window.tinyCrypto.get.signerAddress = function(index = 0) {
        return new Promise((resolve, reject) => {
          window.tinyCrypto.call.requestAccounts().then(accounts => {

            if (Array.isArray(accounts) && accounts.length > 0 && typeof accounts[index] === 'string') {
              resolve(accounts[index]);
            }

            else {
              resolve(null);
            }

          }).catch(reject);
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

      // Request Account
      window.tinyCrypto.call.requestAccounts = function() {
        return new Promise((resolve, reject) => {
          window.tinyCrypto.provider.eth.requestAccounts().then(accounts => {

            // Address
            if (Array.isArray(accounts) && accounts.length > 0) {
              for (const item in accounts) {
                accounts[item] = accounts[item].toLowerCase();
              }
            }

            window.tinyCrypto.accounts = accounts;
            window.tinyCrypto.connected = true;

            myEmitter.emit('requestAccounts', accounts);
            resolve(accounts);

          }).catch(err => {
            window.tinyCrypto.connected = false;
            reject(err);
          });
        });
      };

      // Check Connection
      window.tinyCrypto.call.checkConnection = function() {
        return new Promise((resolve, reject) => {
          if (window.tinyCrypto.providerConnected) {
            window.tinyCrypto.provider.eth.getAccounts().then(accounts => {

              // Address
              if (Array.isArray(accounts) && accounts.length > 0) {
                for (const item in accounts) {
                  accounts[item] = accounts[item].toLowerCase();
                }
              }

              window.tinyCrypto.accounts = accounts;

              // Check Address
              if (window.tinyCrypto.existAccounts()) {

                window.tinyCrypto.get.signerAddress().then(address => {

                  window.tinyCrypto.address = address;

                  myEmitter.emit('checkConnection', { address, accounts });
                  resolve(address);

                }).catch(reject);

              }

              else {
                resolve(false);
              }

            });
          }
          else {
            resolve(null);
          }

        });
      };

      // Wait Address
      window.tinyCrypto.call.waitAddress = function() {
        return new Promise((resolve, reject) => {

          try {

            if (window.tinyCrypto.address) {
              resolve(window.tinyCrypto.address);
            }

            else {
              setTimeout(() => {
                window.tinyCrypto.call.waitAddress().then(data => { resolve(data); }).catch(reject);
              }, 500);
            }

          }

          catch (err) { reject(err); }

        });
      };

      // Execute Contract
      window.tinyCrypto.call.executeContract = function(contract, abi, data, gasLimit = 100000) {
        return new Promise((resolve, reject) => {
          if (window.tinyCrypto.connected) {

            // Loading
            window.tinyCrypto.call.signerAddress().then(address => {
              window.tinyCrypto.address = address;
              window.tinyCrypto.provider.eth.getTransactionCount(address).then(nonce => {
                window.tinyCrypto.provider.eth.getGasPrice().then(currentGasPrice => {

                  // construct the transaction data
                  const tx = {

                    nonce,
                    gasLimit: window.tinyCrypto.provider.utils.toHex(gasLimit),

                    // eslint-disable-next-line radix
                    gasPrice: window.tinyCrypto.provider.utils.toHex(parseInt(currentGasPrice)),

                    to: contract,
                    value: window.tinyCrypto.constants.HexZero,
                    data: window.tinyCrypto.provider.eth.abi.encodeFunctionCall(abi, data),

                  };

                  // Complete
                  window.tinyCrypto.provider.eth.sendTransaction(tx).then(resolve).catch(reject);

                }).catch(reject);
              }).catch(reject);
            }).catch(reject);

          }

          else { resolve(null); }

        });
      };

      // Read Contract
      window.tinyCrypto.call.readContract = function(contract, functionName, data, abi) {
        return new Promise((resolve, reject) => {

          if (!window.tinyCrypto.contracts[contract] && abi) {
            window.tinyCrypto.contracts[contract] = new window.tinyCrypto.provider.eth.Contract(abi, contract);
          }

          if (window.tinyCrypto.contracts[contract]) {
            window.tinyCrypto.contracts[contract].methods[functionName].apply(window.tinyCrypto.contracts[contract], data).call().then(resolve).catch(reject);
          }

          else {
            resolve(null);
          }

        });
      };

      // Send Payment
      window.tinyCrypto.call.sendTransaction = function(amount, address, contract = null, gasLimit = 100000) {
        return new Promise((resolve, reject) => {

          if (window.tinyCrypto.connected) {

            // Result
            window.tinyCrypto.get.signerAddress().then(mainWallet => {

              // Address
              const tinyAddress = address.toLowerCase();

              // Token Mode
              if (contract) {

                // Contract Value
                let tinyContract = contract;

                // Connect to the contract
                if (typeof tinyContract === 'string') { tinyContract = { value: contract, decimals: 18 }; }
                if (typeof tinyContract.value !== 'string') { tinyContract.value = ''; }
                if (typeof tinyContract.decimals !== 'number') { tinyContract.decimals = 18; }

                /** Create token transfer value as (10 ** token_decimal) * user_supplied_value
                * @dev BigNumber instead of BN to handle decimal user_supplied_value
                */
                const base = new window.tinyCrypto.provider.utils.BN(10);
                const valueToTransfer = base.pow(tinyContract.decimals).times(String(amount));

                // Transaction
                window.tinyCrypto.call.executeContract(tinyContract.value, {
                  type: 'function',
                  name: 'transfer',
                  stateMutability: 'nonpayable',
                  payable: false,
                  constant: false,
                  outputs: [{ type: 'uint8' }],
                  inputs: [{
                    name: '_to',
                    type: 'address'
                  }, {
                    name: '_value',
                    type: 'uint256'
                  }]
                }, [
                  tinyAddress,
                  valueToTransfer.toString()
                ], gasLimit).then(resolve).catch(reject);

              }

              // Normal Mode
              else {

                window.tinyCrypto.provider.eth.getTransactionCount(mainWallet).then(nonce => {
                  window.tinyCrypto.provider.eth.getGasPrice().then(currentGasPrice => {

                    // TX
                    const tx = {

                      nonce,

                      from: mainWallet,
                      to: tinyAddress,
                      value: window.tinyCrypto.provider.utils.toWei(String(amount)),

                      gasLimit: window.tinyCrypto.provider.utils.toHex(gasLimit),

                      // eslint-disable-next-line radix
                      gasPrice: window.tinyCrypto.provider.utils.toHex(parseInt(currentGasPrice)),

                    };

                    window.tinyCrypto.provider.eth.sendTransaction(tx).then(resolve).catch(reject);

                  }).catch(reject);
                }).catch(reject);

              }

            }).catch(reject);

          }

          else {
            resolve(null);
          }

        });
      };

      // Data
      window.tinyCrypto.get.blockchain = function() { return window.clone(window.tinyCrypto.config.networks[window.tinyCrypto.config.network]); };
      window.tinyCrypto.get.provider = function() { return window.tinyCrypto.provider; };
      window.tinyCrypto.get.address = function() { return window.tinyCrypto.address; };

      // Exist Accounts
      window.tinyCrypto.existAccounts = function() { return Array.isArray(window.tinyCrypto.accounts) && window.tinyCrypto.accounts.length > 0; };

      // Insert Provider
      // eslint-disable-next-line no-undef
      window.tinyCrypto.provider = new Web3(window.ethereum);
      window.tinyCrypto.providerConnected = true;

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
      window.tinyCrypto.call.checkConnection().then(() => {
        myEmitter.emit('readyProvider');
      });

    }

    // Start More Modules
    configWeb3();

  }

};

// Export Module
export { startWeb3 };
