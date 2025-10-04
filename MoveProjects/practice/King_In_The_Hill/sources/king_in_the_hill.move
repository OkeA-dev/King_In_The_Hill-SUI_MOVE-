module king_in_the_hill::king_game {
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    // no direct clock dependency; tests will pass timestamps as u64
    
    // Error Codes
    const EAlreadyKing: u64 = 0;

    public struct KingHill has key, store {
        id: UID,
        current_king: address,
        crowned_at: u64,
    }

    // Module initializer - must be internal
    fun init(ctx: &mut TxContext) {
        let hill = KingHill {
            id: object::new(ctx),
            current_king: tx_context::sender(ctx),
            crowned_at: 0,
        };
        transfer::share_object(hill);
    }

    // Public function to create a test KingHill (for testing only)
    #[test_only]
    public fun create_test_king_hill(initial_king: address, ctx: &mut TxContext): KingHill {
        KingHill {
            id: object::new(ctx),
            current_king: initial_king,
            crowned_at: 0,
        }
    }

    // Public function to share KingHill for testing
    #[test_only]
    public fun share_for_testing(hill: KingHill) {
        transfer::share_object(hill);
    }

    // Main function to capture the hill
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

    // Public view functions for testing
    public fun current_king(hill: &KingHill): address {
        hill.current_king
    }

    public fun crowned_at(hill: &KingHill): u64 {
        hill.crowned_at
    }

    // Public function to get hill ID for testing
    public fun id(hill: &KingHill): address {
        object::id_to_address(&object::uid_to_inner(&hill.id))
    }
}