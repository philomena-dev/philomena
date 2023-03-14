// Module
import { $ } from '../utils/dom';
const configWeb3 = function() {

  // Insert Web3 Alert into the top page
  const insertWeb3Warn = function(where, text, flashName = 'flash--warning') {
    if (!window.tinyCrypto.warn[where]) {
      window.tinyCrypto.warn[where] = true;
      const newWarning = document.createElement('div');
      newWarning.classList.add('flash');
      newWarning.classList.add(flashName);
      newWarning.innerHTML = text;
      $('#content').parentNode.insertBefore(newWarning, $('#content'));
    }
  };

  // Detect Connect Wallet Buttom
  const connectWallet = $('#connect-web3-wallet');
  if (connectWallet) {
    if (window.ethereum) {
      if (window.ethereum._isUnlocked) {
        connectWallet.addEventListener('click', () => {
          if (window.ethereum._isUnlocked) {

            fetch('/registrations/web3/sign', {
              headers: {
                'Content-Type': 'application/json',
              }
            })
              .then(response => response.json())

              .then(data => {
                window.tinyCrypto.call.sign(data.desc, '').then(signature => {
                  $('#web3_signature').setAttribute('value', signature);
                  $('#web3_wallet').setAttribute('value', window.tinyCrypto.address);
                  $('form[action="/registrations/web3"]').submit();
                });
              })

              .catch(err => {
                console.error(err);
                alert(err.message);
              });

          }

          else {
            alert('Please unlock your crypto wallet before using this.');
          }

        });
      }
      else {
        connectWallet.innerHTML = '<i class="fab fa-ethereum"></i> Please unlock your crypto wallet';
        connectWallet.setAttribute('disabled', true);
      }
    }
    else {
      connectWallet.innerHTML = '<i class="fab fa-ethereum"></i> You don\'t have a Web3 Wallet installed in your browser!';
      connectWallet.setAttribute('disabled', true);
    }
  }

  // Detect Meta to Update Icon
  const checkConnection = function() {
    const existMetaEthereum = $('meta[name="user-ethereum-address"]');
    if (existMetaEthereum) {

      if (window.ethereum) {

        if (window.ethereum._isUnlocked) {

          // Allow Actions
          window.tinyCrypto.allowActions = true;

          // Update Data
          if (!window.tinyCrypto.yourDerpiAddress) {
            window.tinyCrypto.yourDerpiAddress = existMetaEthereum.attributes.content.value.toLowerCase();
          }

          // Check Data and Insert Warn
          if (window.tinyCrypto.yourDerpiAddress !== window.tinyCrypto.address) {

            $('#web3_header').style.color = 'red';
            $('#web3_header').style.opacity = 0.7;
            $('#web3_header').title = 'Your Web3 wallet is not the same as your Derpibooru account.';
            insertWeb3Warn('notSameWallet', 'Your Web3 wallet is not the same as your Derpibooru account!');

            if (connectWallet) {
              connectWallet.innerHTML = '<i class="fab fa-ethereum"></i> Your wallet does not share the same value as your Derpibooru account. You can click here to try to reconnect a new address.';
            }

          }

        }

        else {
          insertWeb3Warn('notWeb3', 'Please unlock your crypto wallet to use the Web3 features.');
          window.tinyCrypto.allowActions = false;
          $('#web3_header').style.color = 'yellow';
          $('#web3_header').style.opacity = 0.7;
          $('#web3_header').title = 'Please unlock your crypto wallet.';
        }

      }

      else {
        insertWeb3Warn('notWalletSoftware', 'You don\'t have a Web3 Wallet installed in your browser!');
        window.tinyCrypto.allowActions = false;
        $('#web3_header').style.color = 'red';
        $('#web3_header').style.opacity = 0.7;
        $('#web3_header').title = 'No wallet was detected.';
      }

    }
    else {
      window.tinyCrypto.allowActions = false;
    }
  };

  window.tinyCrypto.on('readyProvider', checkConnection);
  window.tinyCrypto.on('checkConnection', checkConnection);
  window.tinyCrypto.on('accountsChanged', checkConnection);

};

export { configWeb3 };
