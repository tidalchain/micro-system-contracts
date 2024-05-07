import { expect } from "chai";
import { ethers, network } from "hardhat";
import { Wallet, Provider } from "@zkamoeba/micro-web3";
import { sleep } from "@zkamoeba/micro-web3/build/src/utils";
import {
  WhiteList,
  WhiteList__factory,
  Deposit,
  Deposit__factory,
  Assignment,
  Assignment__factory,
} from "../typechain-types";
import { WHITE_LIST_CONTRACT_ADDRESS, DEPOSIT_CONTRACT_ADDRESS, ASSIGNMENT_ADDRESS } from "./shared/constants";

import * as fs from "fs";
import * as path from "path";

const testConfigPath = path.join(process.env.MICRO_HOME as string, `etc/test_config/constant`);
const ethTestConfig = JSON.parse(fs.readFileSync(`${testConfigPath}/eth.json`, { encoding: "utf-8" }));

const zeroAddress = "0x0000000000000000000000000000000000000000";
const richWallet = "0x6b1f4144a2f59a9b8491e4640813bacc78af9daa83013874097d772d280d929c";

const l1Provider = new Provider((network.config as any).fileNetwork);
const l2Provider = new Provider((network.config as any).url);

describe("Deposit tests", async function () {
  let owner: Wallet;
  let prover: Wallet;
  let whiteListContract: WhiteList;
  let depositContract: Deposit;
  let assignmentContract: Assignment;

  before(async () => {
    owner = Wallet.fromMnemonic(ethTestConfig.mnemonic, "m/44'/60'/0'/0/0");
    owner = new Wallet(owner.privateKey, l2Provider, l1Provider);
    prover = new Wallet(richWallet, l2Provider, l1Provider);
    //deposit fileCoin
    await prover.deposit({
      to: prover.address,
      token: zeroAddress,
      amount: ethers.utils.parseEther("1100"),
    });

    whiteListContract = WhiteList__factory.connect(WHITE_LIST_CONTRACT_ADDRESS, owner);
    depositContract = Deposit__factory.connect(DEPOSIT_CONTRACT_ADDRESS, prover);
    assignmentContract = Assignment__factory.connect(ASSIGNMENT_ADDRESS, prover);
  });

  it("add whiteList", async () => {
    let white = [prover.address];
    let isWhite = await whiteListContract.whiteList(prover.address);

    await whiteListContract.addWhiteList(white);

    await sleep(5 * 1000);
    isWhite = await whiteListContract.whiteList(prover.address);
    expect(isWhite);
  });

  it("deposit", async () => {
    let minDepositAmount = await depositContract.getMinDepositAmount(zeroAddress);
    let depositAmount = await depositContract.getDepositAmount(prover.address, zeroAddress);

    await depositContract.deposit(zeroAddress, minDepositAmount, {
      value: minDepositAmount,
    });

    await sleep(5 * 1000);
    depositAmount = await depositContract.getDepositAmount(prover.address, zeroAddress);

    expect(depositAmount == minDepositAmount);
  });

  it("proof apply", async () => {
    let list = await assignmentContract.getBatchNumberList(0, 1000);
    for (let i = 0; i < list.length; i++) {
      const batchNumber = list[i];
      console.log(batchNumber);

      await assignmentContract.proofApply(batchNumber);
      await sleep(5 * 1000);
    }
  });

  it("withdraw apply ", async () => {
    await depositContract.withdrawApply(zeroAddress);
    await sleep(5 * 1000);
    let tokenInfo = await depositContract.getProverTokenDepositInfo(prover.address, zeroAddress);
    expect(tokenInfo.status == 3);
  });

  it("withdraw", async () => {
    let waitingTime = await depositContract.getWaitingTime();

    await sleep(waitingTime.toNumber() * 1000);

    await depositContract.withdraw(zeroAddress);

    await sleep(5 * 1000);

    let depositAmount = await depositContract.getDepositAmount(prover.address, zeroAddress);
    let tokenInfo = await depositContract.getProverTokenDepositInfo(prover.address, zeroAddress);

    expect(tokenInfo.status == 0);
    expect(depositAmount.isZero());
  });
});
