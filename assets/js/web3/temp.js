  // Account Change
  window.tinyCrypto.call.accountsChanged = async function(accounts) {

    // Address
    window.tinyCrypto.signer = window.tinyCrypto.provider.getSigner();
    await window.tinyCrypto.call.signerUpdated('accountsChanged');

    window.tinyCrypto.address = await window.tinyCrypto.call.signerGetAddress();

    if (window.tinyCrypto.address) {

      window.tinyCrypto.address = window.tinyCrypto.address.toLowerCase();

      if (localStorage) {
        localStorage.setItem('web3_address', window.tinyCrypto.address);
      }

      for (const item in window.tinyCrypto.callbacks.accountsChanged) {
        await window.tinyCrypto.callbacks.accountsChanged[item](accounts);
      }

    }

    return;

  };

  // Warn Signer Updated
  window.tinyCrypto.call.signerUpdated = async function(where) {

    // Send Request
    for (const item in window.tinyCrypto.callbacks.signerUpdated) {
      await window.tinyCrypto.callbacks.signerUpdated[item](window.tinyCrypto.signer, where);
    }

    return;

  };