module king_in_the_hill::king_game {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;

    const EAlreadyKing: u64 = 0;

    public struct KingHill has key, store {
        id: UID,
        current_king: address,
        crowned_at: u64,
    }

    fun init(ctx: &mut TxContext) {
        let hill = KingHill {
            id: object::new(ctx),
            current_king: tx_context::sender(ctx),
            crowned_at: 0,
        };
        transfer::share_object(hill);
    }

    #[test_only]
    public fun create_test_king_hill(initial_king: address, ctx: &mut TxContext): KingHill {
        KingHill {
            id: object::new(ctx),
            current_king: initial_king,
            crowned_at: 0,
        }
    }

    #[test_only]
    public fun share_for_testing(hill: KingHill) {
        transfer::share_object(hill);
    }

    public fun capture_hill(
        hill: &mut KingHill,
        timestamp_ms: u64,
        ctx: &mut TxContext,
    ) {
        let caller_addr = tx_context::sender(ctx);
        assert!(hill.current_king != caller_addr, EAlreadyKing);
        hill.current_king = caller_addr;
        hill.crowned_at = timestamp_ms;
    }

    public fun current_king(hill: &KingHill): address {
        hill.current_king
    }

    public fun crowned_at(hill: &KingHill): u64 {
        hill.crowned_at
    }

    public fun id(hill: &KingHill): address {
        object::id_to_address(&object::uid_to_inner(&hill.id))
    }
}
