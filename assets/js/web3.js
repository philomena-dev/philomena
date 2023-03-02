const startWeb3 = function() {

  // Check if Web3 has been injected by the browser (Mist/MetaMask).
  if (typeof web3 !== 'undefined') {
    console.log('Web3 installed.');
  } else {
    console.log('No Web3 installed.');
  }

  if (typeof ethereum !== 'undefined') {
    console.log('Ethereum installed.');
  } else {
    console.log('No Ethereum installed.');
  }

};

export { startWeb3 };
