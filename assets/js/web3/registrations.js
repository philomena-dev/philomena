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

  // Detect Meta
  const existMetaEthereum = $('meta[name="user-ethereum-address"]');
  if (existMetaEthereum) {
    window.tinyCrypto.yourDerpiAddress = existMetaEthereum.attributes.content.value.toLowerCase();
  }

};

export { configWeb3 };
