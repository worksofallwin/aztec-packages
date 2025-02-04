mod storage;

// Test contract to confirm that notes can be created and then later
// read (eventually even nullified) in the same TX. This contract
// also contains some "bad" test cases to ensure that notes cannot
// be read/nullified before their creation etc.
contract PendingCommitments {
    // Libs
    use dep::token_utils::{
        balance_utils,
        value_note::{
            value_note::ValueNote,
            value_note::ValueNoteInterface,
            filter::get_2_notes,
        }
    };
    use dep::custom_notes::{
        constants::MAX_NOTE_FIELDS_SIZE,
        utils::compute_note_hash_and_nullifier,
    };

    use crate::storage::Storage;

    use dep::aztec::constants_gen::ARGS_LENGTH;
    use dep::aztec::abi;
    use dep::aztec::abi::PrivateContextInputs;
    use dep::aztec::context::Context;
    use dep::aztec::note::note_getter::NoteGetterOptions;
    use dep::aztec::note::note_getter_options::Sort;
    use dep::aztec::types::point::Point;
    use dep::aztec::state_vars::map::Map;
    use dep::aztec::state_vars::set::Set;
    use dep::aztec::log::emit_encrypted_log;
    use dep::aztec::log::emit_unencrypted_log;
    use dep::aztec::private_call_stack_item::PrivateCallStackItem;

    // TODO(dbanks12): consolidate code into internal helper functions
    // (once Noir's support for this is more robust)

    fn constructor(
        //*********************************/
        // Should eventually be hidden:
        inputs: PrivateContextInputs
        //*********************************/
    ) -> distinct pub abi::PrivateCircuitPublicInputs {
        let storage = Storage::init();
        //let context = Context::new(inputs, abi::hash_args([]));
        let context = Context::new(inputs, 0);
        context.finish()
    }

    // Confirm can access pending commitments by creating / inserting a note and then
    // getting / reading that note all in the same contract function
    fn test_insert_then_read_flat(
        //*********************************/
        // Should eventually be hidden:
        inputs: PrivateContextInputs,
        //*********************************/
        amount: Field,
        owner: Point,
    ) -> distinct pub abi::PrivateCircuitPublicInputs {
        let storage = Storage::init();
        let mut context = Context::new(inputs, abi::hash_args([amount, owner.x, owner.y]));

        let owner_balance = storage.balances.at(owner.x);
        let note = ValueNote::new(amount, owner);

        // Insert note and emit encrypted note preimage via oracle call
        context = owner_balance.insert(context, note);

        // Hack: we add the return value from `notifyCreatedNote` oracle call
        // to the sort option to `getNotes` oracle call to force a dependency
        // and therefore ordering between these two oracles
        // TODO(https://github.com/noir-lang/noir/pull/1729): remove when stepwise execution of acir is complete
        // replace with `let options = NoteGetterOptions::with_filter(get_2_notes, 0);`
        let nada = Sort::nada();
        let sorting: [Sort; 6] = [Sort::new(0, context.oracle_connector as u8), nada, nada, nada, nada, nada];
        let options = NoteGetterOptions::new(get_2_notes, 0, sorting , 0);

        let (context_tmp, got_notes) = owner_balance.get_notes(context, options);
        context = context_tmp;

        assert(note.value == got_notes[0].value);
        assert(!got_notes[1].is_real);

        context.return_values = context.return_values.push(got_notes[0].value);

        context.finish()
    }

    // Confirm cannot access commitments created later in same function
    fn test_bad_read_then_insert_flat(
        //*********************************/
        // Should eventually be hidden:
        inputs: PrivateContextInputs,
        //*********************************/
        amount: Field,
        owner: Point,
    ) -> distinct pub abi::PrivateCircuitPublicInputs {
        let storage = Storage::init();
        let mut context = Context::new(inputs, abi::hash_args([amount, owner.x, owner.y]));

        let owner_balance = storage.balances.at(owner.x);

        // Hack: we add the return value from `notifyCreatedNote` oracle call
        // to the sort option to `getNotes` oracle call to force a dependency
        // and therefore ordering between these two oracles
        // TODO(https://github.com/noir-lang/noir/pull/1729): remove when stepwise execution of acir is complete
        // replace with `let options = NoteGetterOptions::with_filter(get_2_notes, 0);`
        let nada = Sort::nada();
        let sorting: [Sort; 6] = [Sort::new(0, context.oracle_connector as u8), nada, nada, nada, nada, nada];
        let options = NoteGetterOptions::new(get_2_notes, 0, sorting , 0);

        // get note (note created at bottom of function shouldn't exist yet)
        let (context_tmp, got_notes) = owner_balance.get_notes(context, options);
        context = context_tmp;

        assert(!got_notes[0].is_real);
        assert(got_notes[0].value == 0);
        assert(!got_notes[1].is_real);

        context.return_values = context.return_values.push(got_notes[0].value);

        // Insert note and emit encrypted note preimage via oracle call
        let note = ValueNote::new(amount, owner);
        context = owner_balance.insert(context, note);

        context.finish()
    }

    // Nested/inner function to create and insert a note
    fn create_note(
        //*********************************/
        // Should eventually be hidden:
        inputs: PrivateContextInputs,
        //*********************************/
        amount: Field,
        owner: Point,
    ) -> distinct pub abi::PrivateCircuitPublicInputs {
        let storage = Storage::init();
        let mut context = Context::new(inputs, abi::hash_args([amount, owner.x, owner.y]));

        let owner_balance = storage.balances.at(owner.x);
        let note = ValueNote::new(amount, owner);

        // Insert note and emit encrypted note preimage via oracle call
        context = owner_balance.insert(context, note);

        context.finish()
    }

    // Nested/inner function to get a note and confirm it matches the expected value
    fn get_and_check_note(
        //*********************************/
        // Should eventually be hidden:
        inputs: PrivateContextInputs,
        //*********************************/
        expected_value: Field,
        owner: Point,
    ) -> distinct pub abi::PrivateCircuitPublicInputs {
        let storage = Storage::init();
        let mut context = Context::new(inputs, abi::hash_args([expected_value, owner.x, owner.y]));

        let owner_balance = storage.balances.at(owner.x);

        // Hack: we add the return value from `notifyCreatedNote` oracle call
        // to the sort option to `getNotes` oracle call to force a dependency
        // and therefore ordering between these two oracles
        // TODO(https://github.com/noir-lang/noir/pull/1729): remove when stepwise execution of acir is complete
        // replace with `let options = NoteGetterOptions::with_filter(get_2_notes, 0);`
        let nada = Sort::nada();
        let sorting: [Sort; 6] = [Sort::new(0, context.oracle_connector as u8), nada, nada, nada, nada, nada];
        let options = NoteGetterOptions::new(get_2_notes, 0, sorting , 0);

        let (context_tmp, got_notes) = owner_balance.get_notes(context, options);
        context = context_tmp;

        assert(expected_value == got_notes[0].value);
        assert(!got_notes[1].is_real);

        context.return_values = context.return_values.push(got_notes[0].value);

        context.finish()
    }

    // Test pending commitments with note insertion done in a nested call
    // and "read" / get of that pending note/commitment in another nested call
    fn test_insert_then_read_both_in_nested_calls(
        //*********************************/
        // Should eventually be hidden:
        inputs: PrivateContextInputs,
        //*********************************/
        amount: Field,
        owner: Point,
        createFnSelector: Field,
        getAndCheckFnSelector: Field,
    ) -> distinct pub abi::PrivateCircuitPublicInputs {
        let mut context = Context::new(inputs, abi::hash_args([amount, owner.x, owner.y, createFnSelector, getAndCheckFnSelector]));

        // args for nested calls
        let mut args = [0; ARGS_LENGTH];
        args[0] = amount;
        args[1] = owner.x;
        args[2] = owner.y;

        // nested call to create/insert note
        let (_callStackItem1, mut context_tmp0) = PrivateCallStackItem::call(inputs.call_context.storage_contract_address, createFnSelector, args, context);
        context = context_tmp0;
        // nested call to read that note / pending commitment
        let (_callStackItem2, mut context_tmp1) = PrivateCallStackItem::call(inputs.call_context.storage_contract_address, getAndCheckFnSelector, args, context);
        context = context_tmp1;

        context.finish()
    }

    // Confirm cannot get/read a pending commitment in a nested call
    // that is created/inserted later in execution but in the parent.
    // NOTE: This test is especially important in an end-to-end context because the parent call
    // (and therefore the insertion) will be processed in an earlier kernel iteration, but the
    // nested call (later kernel iteration) should not be able to read the commitment despite
    // it being present at that stage in the kernel.
    // If we can somehow force the simulator to allow execution to succeed can ensure that this test fails in the kernel
    //fn test_bad_read_in_nested_call_then_insert(
    //    //*********************************/
    //    // Should eventually be hidden:
    //    inputs: PrivateContextInputs,
    //    //*********************************/
    //    amount: Field,
    //    owner: Point,
    //    getAndCheckFnSelector: Field,
    //) -> distinct pub abi::PrivateCircuitPublicInputs {
    //}

    /// ABI stev type "unconstrained"
    fn stev(contract_address: Field, storage_slot: Field, preimage: [Field; MAX_NOTE_FIELDS_SIZE]) -> pub [Field; 2] {
        compute_note_hash_and_nullifier(contract_address, storage_slot, ValueNoteInterface, preimage)
    }
}