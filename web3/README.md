## Web3 API
### Under development

<hr/>

# Javascript

## Events
```
accountsChanged - accounts
networkChanged - networkId
requestAccounts - request accounts action executed (accountsChanged)
checkConnection - check connection executed
```

## Detect Wallet Connected
You can try to check this values before execute a web3 action:

```
tinyCrypto.providerConnected (Boolean)
tinyCrypto.protocol (String)

tinyCrypto.connected (Boolean) (Wallet Connected)

tinyCrypto.provider (Crypto Provider Object)
```

## Send Transaction Examples
Send $0.01 Tethers to the wallet 0x28b5704784e7693eeeeb40fe64db4e75676fa0cd (Polygon Mainnet)

This token uses 6 decimals, so also put the number of decimals in the token in the method.

https://polygonscan.com/token/0xc2132d05d31c914a87c6611c10748aeb04b58e8f
```js
await tinyCrypto.call.sendTransaction(0.01, '0x28b5704784e7693eeeeb40fe64db4e75676fa0cd', { value: '0xc2132d05d31c914a87c6611c10748aeb04b58e8f', decimals: 6 })
```

Send 0.01 MATICs to the wallet 0x28b5704784e7693eeeeb40fe64db4e75676fa0cd (Polygon Mainnet)

Don't forget that if you hold another blockchain, it won't be MATICS that will be sent. If you for example select the Ethereum blockchain, this same function will send ETH instead of MATIC.
```js
await tinyCrypto.call.sendTransaction(0.01, '0x28b5704784e7693eeeeb40fe64db4e75676fa0cd')
```

## Web3 API
https://web3js.readthedocs.io/en/v1.8.2/index.html

All features of the documentation web3.js are assigned to the value "tinyCrypto.provider".

Example: (https://web3js.readthedocs.io/en/v1.8.2/web3-utils.html#isaddress)
```js
tinyCrypto.provider.utils.isAddress('0x98d4dc931122118b0fabbadd5bff443cef4e2041');
web3.utils.isAddress('0x98d4dc931122118b0fabbadd5bff443cef4e2041');
```
