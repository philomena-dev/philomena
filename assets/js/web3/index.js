// More Modules
import { $ } from '../utils/dom';
import { web3Cfg } from '../../../web3/client.side.config';

// https://web3js.readthedocs.io/en/v1.8.2/index.html
import * as web3 from 'web3';

// Module
const startWeb3 = function() {

  // Prepare Web3 Object
  window.web3 = web3;
  window.tinyCrypto = { connected: false, providerConnected: false, isMetaMask: false, config: web3Cfg() };
  if (window.tinyCrypto.config.enabled) {

    // Get Main Blockchains
    window.tinyCrypto.networks = {

      matic: {
        chainId: '0x89',
        chainIdInt: 137,
        rpcUrls: ['https://polygon-rpc.com/'],
        chainName: 'Polygon Mainnet',
        nativeCurrency: {
          name: 'MATIC',
          symbol: 'MATIC',
          decimals: 18
        },
        blockExplorerUrls: ['https://polygonscan.com/']
      },

      bsc: {
        chainId: '56',
        chainIdInt: 56,
        rpcUrls: ['https://bsc-dataseed.binance.org/'],
        chainName: 'Smart Chain',
        nativeCurrency: {
          name: 'BNB',
          symbol: 'BNB',
          decimals: 18
        },
        blockExplorerUrls: ['https://bscscan.com/']
      }

    };

    // Selected Network
    if (typeof window.tinyCrypto.config.network === 'string' && window.tinyCrypto.config.network.length > 0) { window.tinyCrypto.network = window.tinyCrypto.config.network; }

    // Check if Web3 has been injected by the browser (Mist/MetaMask).
    if (typeof ethereum !== 'undefined') {
      window.tinyCrypto.provider = new Web3(window.ethereum);
      window.tinyCrypto.providerConnected = true;
      if (window.ethereum.isMetaMask) { window.tinyCrypto.isMetaMask = true; }
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
