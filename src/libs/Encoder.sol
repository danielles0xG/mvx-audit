// // SPDX-License-Identifier: MIT O
// pragma solidity ^0.8.5;

// import {Collection, Stages} from "./MvxStruct.sol";

// contract Encoder {
//     function encodeStage() external view returns (bytes memory _data) {
//         Stages memory stage = Stages({
//             ogMintPrice: 30000000000000000,
//             whitelistMintPrice: 30000000000000000,
//             mintPrice: 30000000000000000,
//             mintMaxPerUser: 10,
//             ogMintMaxPerUser: 10,
//             whitelistMintMaxPerUser: 10,
//             mintStart: uint40(block.timestamp),
//             mintEnd: uint40(block.timestamp + 5 * 60 * 60 * 24),
//             ogMintStart: uint40(block.timestamp),
//             ogMintEnd: uint40(block.timestamp + 5 * 60 * 60 * 24),
//             whitelistMintStart: uint40(block.timestamp),
//             whitelistMintEnd: uint40(block.timestamp + 5 * 60 * 60 * 24)
//         });
//         _data = abi.encode(
//             stage.ogMintPrice,
//             stage.whitelistMintPrice,
//             stage.mintPrice,
//             stage.mintMaxPerUser,
//             stage.ogMintMaxPerUser,
//             stage.whitelistMintMaxPerUser,
//             stage.mintStart,
//             stage.mintEnd,
//             stage.ogMintStart,
//             stage.ogMintEnd,
//             stage.whitelistMintStart,
//             stage.whitelistMintEnd
//         );
//     }

//     function encodeCollection() external view returns (bytes memory _data) {
//         Collection memory nftData = Collection({
//             name: "MVX ART",
//             symbol: "MVX",
//             baseURI: "ipfs://QmXPHaxtTKxa58ise75a4vRAhLzZK3cANKV3zWb6KMoGUU/",
//             baseExt: ".json",
//             maxSupply: 300,
//             royaltyFee: 1000,
//             royaltyReceiver: 0x2ff9cb5A21981e8196b09AD651470b41Ba28b9C6,
//             isMaxSupplyUpdatable: true
//         });

//         _data = abi.encode(
//             nftData.name,
//             nftData.symbol,
//             nftData.baseURI,
//             nftData.baseExt,
//             nftData.maxSupply,
//             nftData.royaltyReceiver,
//             nftData.royaltyFee
//         );
//     }
// }
