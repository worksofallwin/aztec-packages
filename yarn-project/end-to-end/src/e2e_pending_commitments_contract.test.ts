import { AztecNodeService } from '@aztec/aztec-node';
import { AztecAddress, Contract, ContractDeployer, Fr, Wallet } from '@aztec/aztec.js';
import { PendingCommitmentsContractAbi } from '@aztec/noir-contracts/examples';
import { DebugLogger } from '@aztec/foundation/log';
import { AztecRPCServer } from '@aztec/aztec-rpc';

import { setup } from './utils.js';
import { CircuitError } from '@aztec/circuits.js';

describe('e2e_pending_commitments_contract', () => {
  let aztecNode: AztecNodeService;
  let aztecRpcServer: AztecRPCServer;
  let wallet: Wallet;
  let accounts: AztecAddress[];
  let logger: DebugLogger;

  let contract: Contract;

  beforeEach(async () => {
    ({ aztecNode, aztecRpcServer, accounts, wallet, logger } = await setup(2));
  }, 100_000);

  afterEach(async () => {
    await aztecNode?.stop();
    await aztecRpcServer?.stop();
  });

  const deployContract = async () => {
    logger(`Deploying L2 contract...`);
    const deployer = new ContractDeployer(PendingCommitmentsContractAbi, aztecRpcServer);
    const tx = deployer.deploy().send();
    const receipt = await tx.getReceipt();
    contract = new Contract(receipt.contractAddress!, PendingCommitmentsContractAbi, wallet);
    await tx.isMined(0, 0.1);
    await tx.getReceipt();
    logger('L2 contract deployed');
    return contract;
  };

  it('Noir function can "get" notes it just "inserted"', async () => {
    const mintAmount = 65n;

    const [owner] = accounts;
    const ownerPublicKey = (await aztecRpcServer.getAccountPublicKey(owner)).toBigInts();

    const deployedContract = await deployContract();

    const tx = deployedContract.methods.test_insert_then_read_flat(mintAmount, ownerPublicKey).send({ origin: owner });

    // TODO(https://github.com/AztecProtocol/aztec-packages/issues/906): remove code below and replace
    // with `tx.isMined()` (etc) once kernel supports forwarding and matching of transient reads.
    expect.assertions(2);
    try {
      await tx.isMined(0, 0.1);
    } catch (error) {
      expect(error).toBeInstanceOf(CircuitError);
      expect(error).toHaveProperty('message', expect.stringContaining('kernel could not match read_request'));
    }

    //await tx.isMined(0, 0.1);
    //const receipt = await tx.getReceipt();
    //expect(receipt.status).toBe(TxStatus.MINED);
  }, 60_000);

  it('Noir function can "get" notes inserted in a previous function call in same TX', async () => {
    const mintAmount = 65n;

    const [owner] = accounts;
    const ownerPublicKey = (await aztecRpcServer.getAccountPublicKey(owner)).toBigInts();

    const deployedContract = await deployContract();

    const tx = deployedContract.methods
      .test_insert_then_read_both_in_nested_calls(
        mintAmount,
        ownerPublicKey,
        Fr.fromBuffer(deployedContract.methods.create_note.selector),
        Fr.fromBuffer(deployedContract.methods.get_and_check_note.selector),
      )
      .send({ origin: owner });

    // TODO(https://github.com/AztecProtocol/aztec-packages/issues/906): remove code below and replace
    // with `tx.isMined()` (etc) once kernel supports forwarding and matching of transient reads.
    expect.assertions(2);
    try {
      await tx.isMined(0, 0.1);
    } catch (error) {
      expect(error).toBeInstanceOf(CircuitError);
      expect(error).toHaveProperty('message', expect.stringContaining('kernel could not match read_request'));
    }

    //await tx.isMined(0, 0.1);
    //const receipt = await tx.getReceipt();
    //expect(receipt.status).toBe(TxStatus.MINED);
  }, 60_000);

  // TODO(https://github.com/AztecProtocol/aztec-packages/issues/836): test nullify & squash of pending notes
  // TODO(https://github.com/AztecProtocol/aztec-packages/issues/892): test expected kernel failures if transient reads (or their hints) don't match
  // TODO(https://github.com/AztecProtocol/aztec-packages/issues/836): test expected kernel failures if nullifiers (or their hints) don't match
  // TODO(https://github.com/AztecProtocol/aztec-packages/issues/839): test creation, getting, nullifying of multiple notes
});
