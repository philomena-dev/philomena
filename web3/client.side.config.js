// Module
const web3Cfg = function () {

    return {

        // Load Web3 Javascript
        enabled: true,

        // Use the Polygon blockchain on the web3 provider. If you remove this setting, you will use the default option (Ethereum).
        network: 'matic',

        // Networks List
        networks: {

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

        },

        // Force Network Change
        forceChange: false

    };

};

// Export Module
export { web3Cfg };