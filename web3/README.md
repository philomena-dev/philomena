# Web3 API
### Under development

<hr/>

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

## Web3 API
https://web3js.readthedocs.io/en/v1.8.2/index.html

All features of the documentation web3.js are assigned to the value "tinyCrypto.provider".

Example: (https://web3js.readthedocs.io/en/v1.8.2/web3-utils.html#isaddress)
```js
tinyCrypto.provider.utils.isAddress('0x98d4dc931122118b0fabbadd5bff443cef4e2041');
web3.utils.isAddress('0x98d4dc931122118b0fabbadd5bff443cef4e2041');
```