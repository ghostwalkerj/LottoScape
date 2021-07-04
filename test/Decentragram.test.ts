/* eslint-disable @typescript-eslint/no-unused-expressions */

import { ethers } from "hardhat";
import chai, { assert } from "chai";
import chaiAsPromised from "chai-as-promised";
import { Decentragram, DecentragramFactory } from "../typechain";
import { BigNumber, Overrides, Signer } from "ethers";
chai.use(chaiAsPromised);
const { expect } = chai;
let decentragram: Decentragram;
let signers: Signer[];
describe("Decentragram", () => {

  beforeEach(async () => {
    signers = await ethers.getSigners();

    const decentragramFactor = (await ethers.getContractFactory(
      "Decentragram",
      signers[0]
    )) as DecentragramFactory;

    decentragram = await decentragramFactor.deploy();
    await decentragram.deployed();
    expect(decentragram.address).to.properAddress;
  });

  it('has a name', async () => {
    const name = await decentragram.name();
    expect(name).to.eq('Decentragram');
  });

  it('creates images', async () => {
    const hash = 'abc123';
    let imageCount: BigNumber;
    let result: any;
    const address = await signers[0].getAddress();
    result = await decentragram.uploadImage(hash, 'Image description', { from: address } as Overrides);
    imageCount = await decentragram.imageCount();
    assert.equal(imageCount.toNumber(), 1);
    console.log(result);
  });
});
