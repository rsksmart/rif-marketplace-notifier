# RIF Marketplace Notifications

```
npm i @rsksmart/rif-marketplace-notifications
```

**Warning: Contracts in this repo are in alpha state. They have not been audited and are not ready for deployment to main net!
  There might (and most probably will) be changes in the future to its API and working. Also, no guarantees can be made about its stability, efficiency, and security at this stage.**

## NotificationsManager contract

## TypeScript typings

There are TypeScript typing definitions of the contracts published together with the original contracts in folder `/types`.
Supported contract's libraries are:

* `web3` version 1.* - `web3-v1-contracts`
* `web3` version 2.* - `web3-v2-contracts`
* `truffle` - `truffle-contracts`
* `ethers` - `ethers-contracts`

So for example if you want to use Truffle typings then you should import the contract from `@rsksmart/rif-marketplace-notifications/types/truffle/...`.
