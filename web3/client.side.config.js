// Module
const web3Cfg = function () {

    return {

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
                blockExplorerUrls: ['https://etherscan.com/']
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
                blockExplorerUrls: ['https://polygonscan.com/']
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
                blockExplorerUrls: ['https://bscscan.com/']
            },

        }

    };

};

// Export Module
export { web3Cfg };
