use dep::aztec::state_vars::{
    map::Map,
    set::Set
};
use dep::token_utils::value_note::{
    value_note::ValueNote,
    value_note::ValueNoteInterface,
    value_note::VALUE_NOTE_LEN,
};

struct Storage {
    balances: Map<Set<ValueNote, VALUE_NOTE_LEN>>,
}

impl Storage {
    fn init() -> Self {
        Storage {
            balances: Map::new(1, |s| Set::new(s, ValueNoteInterface)),
        }
    }
}