// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Pack it up!

struct Stages {
    // 2 storage slots total = 64 bytes
    bool isMaxSupplyUpdatable; // 1 byte
    uint72 ogMintPrice; // max 4722 ether - 9 bytes
    uint72 whitelistMintPrice; // max 4722 ether - 9 bytes
    uint72 mintPrice; // max 4722 ether - 9 bytes
    uint16 mintMaxPerUser; // up tp 65535    - 2 bytes
    uint16 ogMintMaxPerUser; // up tp 65535    - 2 bytes
    // first slot 32 bytes
    uint40 mintStart; // up to 1099511627775          - 5 bytes
    uint40 mintEnd; // up to 1099511627775            - 5 bytes
    uint40 ogMintStart; // up to 1099511627775        - 5 bytes
    uint40 ogMintEnd; // up to 1099511627775          - 5 bytes
    uint40 whitelistMintStart; // up to 1099511627775 - 5 bytes
    uint40 whitelistMintEnd; // up to 1099511627775   - 5 bytes
    uint16 whitelistMintMaxPerUser; // up tp 65535    - 2 bytes
        // second slot 32 bytes
}

struct Collection {
    // 6 storage slots total = 192 bytes
    string name; // 32 bytes
    string symbol; // 32 bytes
    string baseURI; // 32 bytes
    string baseExt; // 32 bytes
    address royaltyReceiver; // 20 bytes
    // one slot :
    uint128 maxSupply; // up to 340282366920938463463374607431768211455
    uint128 royaltyFee; // 340282366920938500000 ether max
}

// address artist => Artist
struct Artist {
    // 2 storage slots total
    address referral; // referral address
    address collection; // memeber of collection the referral is
}

// address collection => Partner
struct Partner {
    // 3 storage slots total = 96 bytes
    address collection; // partnering to give discounts from memebers of this collection = 20 bytes
    address admin; // partner collection admin = 20 bytes
    uint16 adminOwnPercent; // % variable per partnership - up to 65535 number - basis point < 10_000 = 2 bytes
    uint16 referralOwnPercent; // % variable per partnership - up to 65535 number - basis point < 10_000 = 2 bytes
    uint16 discount; // variable per partnership - up to 65535 number - basis point < 10_000 = 2 bytes
    uint72 balance; // track partner balance (admin) // max 4722 ether - 9 bytes
    uint40 expiration; // 5 bytes
        // 3rd slot 27 bytes
}

// address => Member
struct Member {
    // 2 storage slots = 64 bytes
    address collection; // 20 bytes
    uint72 deployFee; // max 4722 ether - 9 bytes
    uint16 platformFee; // up to 65535 number so % bp < 10_000 = 2 bytes
    uint16 discount; // up to 65535 number so % bp < 10_000 = 2 bytes
    uint40 expiration; // 5 bytes
}
