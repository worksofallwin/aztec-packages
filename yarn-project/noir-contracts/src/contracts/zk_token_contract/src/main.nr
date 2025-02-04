mod storage;

contract ZkToken {
    // Libs
    use dep::token_utils::{
        balance_utils,
        value_note::{
            value_note::ValueNoteInterface,
            utils::{send_note, spend_notes},
        },
    };
    use dep::custom_notes::{
        claim_note::{ClaimNote, ClaimNoteInterface},
        constants::MAX_NOTE_FIELDS_SIZE,
        utils::compute_note_hash_and_nullifier,
    };

    use dep::aztec::abi;
    use dep::aztec::abi::PrivateContextInputs;
    use dep::aztec::context::Context;
    use dep::aztec::note::note_getter::NoteGetterOptions;
    use dep::aztec::types::point::Point;
    use dep::aztec::state_vars::map::Map;
    use dep::aztec::state_vars::set::Set;
    use dep::aztec::log::emit_encrypted_log;
    use dep::aztec::log::emit_unencrypted_log;

    use crate::storage::Storage;


    // Constructs the contract and sets `initial_supply` which is fully owned by `owner`.
    fn constructor(
        //*********************************/
        // Should eventually be hidden:
        inputs: PrivateContextInputs,
        //*********************************/
        initial_supply: Field, 
        owner: Point,
    ) -> distinct pub abi::PrivateCircuitPublicInputs {
        let storage = Storage::init();
        let mut context = Context::new(inputs, abi::hash_args([initial_supply, owner.x, owner.y]));

        // Insert new note to a set of user notes and emit the newly created encrypted note preimage via oracle call.
        let owner_balance = storage.balances.at(owner.x);
        context = send_note(context, owner_balance, initial_supply, owner);
        context = emit_unencrypted_log(context, "Balance set in constructor");

        // Return private circuit public inputs. All private functions need to return this as it is part of the input of the private kernel.
        context.finish()
    }

    // Mints `amount` of tokens to `owner`.
    fn mint(
        //*********************************/
        // Should eventually be hidden:
        inputs: PrivateContextInputs,
        //*********************************/
        amount: Field, 
        owner: Point,
    ) -> distinct pub abi::PrivateCircuitPublicInputs {
        let storage = Storage::init();
        let mut context = Context::new(inputs, abi::hash_args([amount, owner.x, owner.y]));

        // Insert new note to a set of user notes and emit the newly created encrypted note preimage via oracle call.
        let owner_balance = storage.balances.at(owner.x);
        context = send_note(context, owner_balance, amount, owner);
        context = emit_unencrypted_log(context, "Coins minted");

        // Return private circuit public inputs. All private functions need to return this as it is part of the input of the private kernel..
        context.finish()
    }

    // Transfers `amount` of tokens from `sender` to a `recipient`.
    fn transfer(
        //*********************************/
        // Should eventually be hidden:
        inputs: PrivateContextInputs,
        //*********************************/
        amount: Field, 
        sender: Point, 
        recipient: Point,
    ) -> distinct pub abi::PrivateCircuitPublicInputs {
        let storage = Storage::init();
        let mut context = Context::new(inputs, abi::hash_args([amount, sender.x, sender.y, recipient.x, recipient.y]));

        // Pick from the set of sender's notes to spend amount.
        let sender_balance = storage.balances.at(sender.x);
        context = spend_notes(context, sender_balance, amount, sender);

        // Creates new note for the recipient.
        let recipient_balance = storage.balances.at(recipient.x);
        context = send_note(context, recipient_balance, amount, recipient);
        
        context = emit_unencrypted_log(context, "Coins transferred");

        // Return private circuit public inputs. All private functions need to return this as it is part of the input of the private kernel..
        context.finish()
    }

    fn createClaims(
        //*********************************/
        // Should eventually be hidden:
        inputs: PrivateContextInputs,
        //*********************************/
        amounts: [Field; 2], 
        secrets: [Field; 2], 
        sender: Point, 
    ) -> distinct pub abi::PrivateCircuitPublicInputs {
        let storage = Storage::init();
        let mut context = Context::new(inputs, abi::hash_args([amounts[0], amounts[1], secrets[0], secrets[1], sender.x, sender.y]));

        // Pick from the set of sender's notes to spend amount.
        let sender_balance = storage.balances.at(sender.x);
        let total = amounts[0] + amounts[1];
        context = spend_notes(context, sender_balance, total, sender);

        // Create claim notes.
        let claims = storage.claims;
        let note0 = ClaimNote::new(amounts[0], secrets[0]);
        let note1 = ClaimNote::new(amounts[1], secrets[1]);

        // Insert the new claim notes to the set.
        context = claims.insert(context, note0);
        context = claims.insert(context, note1);

        // Return private circuit public inputs. All private functions need to return this as it is part of the input of the private kernel..
        context.finish()
    }

    fn claim(
        //*********************************/
        // Should eventually be hidden:
        inputs: PrivateContextInputs,
        //*********************************/
        amount: Field,
        secret: Field,
        owner: Point,
    ) -> distinct pub abi::PrivateCircuitPublicInputs {
        let storage = Storage::init();
        let mut context = Context::new(inputs, abi::hash_args([amount, secret, owner.x, owner.y]));

        // Remove the claim note if it exists in the set.
        let note = ClaimNote::new(amount, secret);
        context = storage.claims.has(context, note);
        context = storage.claims.remove(context, note);

        // Send the value note.
        let balance = storage.balances.at(owner.x);
        context = send_note(context, balance, amount, owner);

        // Return private circuit public inputs. All private functions need to return this as it is part of the input of the private kernel..
        context.finish()
    }

    /// ABI getBalance type "unconstrained"
    // Helper function to get the balance of a user ("unconstrained" is a Noir alternative of Solidity's "view" function).
    fn getBalance(
        owner: Point,
    ) -> pub Field {
        let storage = Storage::init();

        // Get the set of notes owned by the user.
        let owner_balance = storage.balances.at(owner.x);

        // Return the sum of all notes in the set.
        balance_utils::get_balance(owner_balance.storage_slot)
    }

    /// ABI stev type "unconstrained"
    fn stev(contract_address: Field, storage_slot: Field, preimage: [Field; MAX_NOTE_FIELDS_SIZE]) -> pub [Field; 2] {
        if (storage_slot == 2) {
            compute_note_hash_and_nullifier(contract_address, storage_slot, ClaimNoteInterface, preimage)
        } else {
            compute_note_hash_and_nullifier(contract_address, storage_slot, ValueNoteInterface, preimage)
        }
    }
}
