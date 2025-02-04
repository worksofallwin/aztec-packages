import { CircuitsWasm, FunctionData, PrivateHistoricTreeRoots } from '@aztec/circuits.js';
import { Grumpkin } from '@aztec/circuits.js/barretenberg';

import { AztecAddress } from '@aztec/foundation/aztec-address';
import { EthAddress } from '@aztec/foundation/eth-address';
import { Fr } from '@aztec/foundation/fields';
import { ZkTokenContractAbi } from '@aztec/noir-contracts/examples';
import { ExecutionRequest } from '@aztec/types';
import { mock } from 'jest-mock-extended';
import { NoirPoint, toPublicKey } from '../utils.js';
import { DBOracle } from './db_oracle.js';
import { AcirSimulator } from './simulator.js';
import { encodeArguments } from '@aztec/foundation/abi';

describe('Unconstrained Execution test suite', () => {
  let bbWasm: CircuitsWasm;
  let oracle: ReturnType<typeof mock<DBOracle>>;
  let acirSimulator: AcirSimulator;

  beforeAll(async () => {
    bbWasm = await CircuitsWasm.get();
  });

  beforeEach(() => {
    oracle = mock<DBOracle>();
    acirSimulator = new AcirSimulator(oracle);
  });

  describe('zk token contract', () => {
    let currentNonce = 0n;
    let ownerPk: Buffer;
    let owner: NoirPoint;

    const buildNote = (amount: bigint, owner: NoirPoint) => {
      return [new Fr(amount), new Fr(owner.x), new Fr(owner.y), Fr.random(), new Fr(currentNonce++), new Fr(1n)];
    };

    beforeAll(() => {
      ownerPk = Buffer.from('5e30a2f886b4b6a11aea03bf4910fbd5b24e61aa27ea4d05c393b3ab592a8d33', 'hex');

      const grumpkin = new Grumpkin(bbWasm);
      owner = toPublicKey(ownerPk, grumpkin);
    });

    it('should run the getBalance function', async () => {
      const contractAddress = AztecAddress.random();
      const abi = ZkTokenContractAbi.functions.find(f => f.name === 'getBalance')!;

      const preimages = [...Array(5).fill(buildNote(1n, owner)), ...Array(2).fill(buildNote(2n, owner))];
      // TODO for this we need that noir siloes the commitment the same way as the kernel does, to do merkle membership

      const historicRoots = PrivateHistoricTreeRoots.empty();

      oracle.getNotes.mockImplementation(
        (_contract, _storageSlot, _sortBy, _sortOrder, limit: number, offset: number) => {
          const notes = preimages.slice(offset, offset + limit);
          return Promise.resolve({
            count: preimages.length,
            notes: notes.map((preimage, index) => ({
              preimage,
              index: BigInt(index),
            })),
          });
        },
      );

      const execRequest: ExecutionRequest = {
        from: AztecAddress.random(),
        to: contractAddress,
        functionData: new FunctionData(Buffer.alloc(4), true, true),
        args: encodeArguments(abi, [owner]),
      };

      const result = await acirSimulator.runUnconstrained(
        execRequest,
        abi,
        AztecAddress.random(),
        EthAddress.ZERO,
        historicRoots,
      );

      expect(result).toEqual([9n]);
    }, 30_000);
  });
});
