// Module
import { $ } from '../utils/dom';
const configWeb3 = function() {

  // Detect Connect Wallet Buttom
  const connectWallet = $('#connect-web3-wallet');
  if (connectWallet) {
    if (window.ethereum) {
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
      connectWallet.innerHTML = '<i class="fab fa-ethereum"></i> You don\'t have a Web3 Wallet installed in your browser!';
      connectWallet.setAttribute('disabled', true);
    }
  }

  // Detect Meta to Update Icon
  const checkConnection = function() {
    const existMetaEthereum = $('meta[name="user-ethereum-address"]');
    if (existMetaEthereum) {

      // Update Data
      if (!window.tinyCrypto.yourDerpiAddress) {
        window.tinyCrypto.yourDerpiAddress = existMetaEthereum.attributes.content.value.toLowerCase();
      }

      // Check Data and Insert Warn
      if (window.tinyCrypto.yourDerpiAddress !== window.tinyCrypto.address) {

        let insertWarn = true;
        if ($('#web3_header').style.opacity === 0.5) {
          insertWarn = false;
        }

        $('#web3_header').style.opacity = 0.5;
        $('#web3_header').title = 'Your Web3 wallet is not the same as your Derpibooru account.';

        if (insertWarn) {
          const newWarning = document.createElement('div');
          newWarning.classList.add('flash');
          newWarning.classList.add('flash--warning');
          newWarning.newWarning = 'Your Web3 wallet is not the same as your Derpibooru account!';
          $('#content').parentNode.insertBefore(newWarning, $('#content'));
        }

      }

    }
  };

  window.tinyCrypto.on('readyProvider', checkConnection);
  window.tinyCrypto.on('checkConnection', checkConnection);
  window.tinyCrypto.on('accountsChanged', checkConnection);

};

export { configWeb3 };
