// Module
const web3Cfg = function () {

    return {

      // USD Tokens
      usd: {

        dai: {
          ethereum: '0x6b175474e89094c44da98b954eedeac495271d0f',
          polygon: '0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063',
          bsc: '0x1af3f329e8be154074d8769d1ffa4ee058b1dbc3'
        },

        usdt: {
          ethereum: '0xdac17f958d2ee523a2206206994597c13d831ec7',
          polygon: '0xc2132d05d31c914a87c6611c10748aeb04b58e8f'
        },

        usdc: {
          ethereum: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
          polygon: '0x2791bca1f2de4661ed88a30c99a7a9449aa84174',
          bsc: '0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d'
        }

      },

      // Networks List
      networks: {

          // Ethereum
          ethereum: {

              chainId: '1',
              chainIdInt: 1,
              rpcUrls: ['https://cloudflare-eth.com/'],
              chainName: 'Ethereum Mainnet',
              nativeCurrency: {
                  name: 'ETH',
                  symbol: 'ETH',
                  decimals: 18
              },
              blockExplorerUrls: ['https://etherscan.com/'],
              blockExplorerApis:  ['https://api.etherscan.io/'],

              // https://docs.uniswap.org/contracts/v2/reference/smart-contracts/factory
              factory: ['0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f'],

          },

          // Polygon (MATIC)
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
              blockExplorerUrls: ['https://polygonscan.com/'],
              blockExplorerApis:  ['https://api.polygonscan.com/'],

              // https://docs.quickswap.exchange/reference/smart-contracts/v3/01-factory
              factory: ['0x411b0fAcC3489691f28ad58c47006AF5E3Ab3A28'],

          },

          // Binsnace Smart Chain (BEP20)
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
              blockExplorerUrls: ['https://bscscan.com/'],
              blockExplorerApis:  ['https://api.bscscan.com/'],

              // https://docs.pancakeswap.finance/code/smart-contracts/pancakeswap-exchange/v2/factory-v2
              factory: ['0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73'],

          },

          // Gnosis Chain (USD)
          gnosis: {

              chainId: '100',
              chainIdInt: 100,
              rpcUrls: ['https://rpc.gnosischain.com/'],
              chainName: 'Gnosis',
              nativeCurrency: {
                  name: 'xDai',
                  symbol: 'xDAI',
                  decimals: 18
              },
              blockExplorerUrls: ['https://gnosisscan.io/'],
              blockExplorerApis:  ['https://api.gnosisscan.io/'],

              factory: [],

          },

      }

    };

};

// Export Module
export { web3Cfg };
