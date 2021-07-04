//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract Decentragram {
    string public name = "Decentragram";

    // Store images
    uint256 public imageCount = 0;
    mapping(uint256 => Image) public images;

    struct Image {
        uint256 id;
        string hash;
        string description;
        uint256 tipAmount;
        address payable author;
    }
    event ImageCreated(Image _image);

    // Create images
    function uploadImage(string memory _imgHash, string memory _description)
        public
    {
        Image memory image = Image(
            imageCount,
            _imgHash,
            _description,
            0,
            payable(msg.sender)
        );
        images[imageCount] = image;

        emit ImageCreated(image);

        imageCount++;
    }
    // Tip images
}
