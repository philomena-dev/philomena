// Module
const web3Cfg = function() {

    return {

        // Load Web3 Javascript
        enabled: true,

        // Use the Polygon blockchain on the web3 provider. If you remove this setting, you will use the default option (Ethereum).
        network: 'matic',

        // Force Network Change
        forceChange: false
    
    };

};

// Export Module
export { web3Cfg };
