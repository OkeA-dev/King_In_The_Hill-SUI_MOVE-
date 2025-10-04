#[test_only]
module king_in_the_hill::king_game_tests {
    use sui::test_scenario as ts;
    use king_in_the_hill::king_game;

    // Helper function to initialize the game in tests
    fun init_game(scenario: &mut ts::Scenario) {
        // Take the sender first, then get the tx context to avoid overlapping mutable borrows
        let initial_sender = ts::sender(scenario);
        let ctx = ts::ctx(scenario);
        // Use the test-only function to create and share KingHill
        let hill = king_game::create_test_king_hill(initial_sender, ctx);
        king_game::share_for_testing(hill);
        // End the transaction so the shared object is committed to the scenario inventory
        ts::next_tx(scenario, initial_sender);
    }

    // Test initialization
    #[test]
    fun test_initialization() {
        let mut scenario_val = ts::begin(@0x123);
        let scenario = &mut scenario_val;
        
        // Initialize the game
        init_game(scenario);
        
        // Verify the KingHill object was created and shared
        let mut hill = ts::take_shared<king_game::KingHill>(scenario);
        assert!(king_game::current_king(&hill) == @0x123, 1);
        assert!(king_game::crowned_at(&hill) == 0, 2);
        
        ts::return_shared(hill);
        ts::end(scenario_val);
    }

    // Test successful capture by a new player
    #[test]
    fun test_successful_capture() {
        let mut scenario_val = ts::begin(@0x123);
        let scenario = &mut scenario_val;
        
        // Initialize game
        init_game(scenario);
        let mut hill = ts::take_shared<king_game::KingHill>(scenario);
        // synthetic timestamp for the capture
        let ts_now = 1u64;
        
        // Switch to player 2 context
        ts::next_tx(scenario, @0x456);
        
        // Player 2 captures the hill
        king_game::capture_hill(&mut hill, ts_now, ts::ctx(scenario));
        
        // Verify new king and timestamp
        assert!(king_game::current_king(&hill) == @0x456, 1);
        assert!(king_game::crowned_at(&hill) > 0, 2);
        
        ts::return_shared(hill);
        ts::end(scenario_val);
    }

    // Test that current king cannot capture their own hill
    #[test]
    #[expected_failure(abort_code = 0, location = king_game)]
    fun test_self_capture_fails() {
        let mut scenario_val = ts::begin(@0x123);
        let scenario = &mut scenario_val;

        init_game(scenario);
        let mut hill = ts::take_shared<king_game::KingHill>(scenario);
        let ts_now = 2u64;

        // Current king tries to capture again - should fail with EAlreadyKing
        king_game::capture_hill(&mut hill, ts_now, ts::ctx(scenario));

        ts::return_shared(hill);
        ts::end(scenario_val);
    }

    // Test multiple captures between different players
    #[test]
    fun test_multiple_captures() {
        let mut scenario_val = ts::begin(@0x111);
        let scenario = &mut scenario_val;

        init_game(scenario);
        let mut hill = ts::take_shared<king_game::KingHill>(scenario);

        // Player 2 captures from initial king
        ts::next_tx(scenario, @0x222);
        let ts1 = 10u64;
        king_game::capture_hill(&mut hill, ts1, ts::ctx(scenario));
        assert!(king_game::current_king(&hill) == @0x222, 1);
        let first_capture_time = king_game::crowned_at(&hill);

        // Player 3 captures from player 2
        ts::next_tx(scenario, @0x333);
        let ts2 = first_capture_time + 5;
        king_game::capture_hill(&mut hill, ts2, ts::ctx(scenario));
        assert!(king_game::current_king(&hill) == @0x333, 2);
        let second_capture_time = king_game::crowned_at(&hill);

        // Verify time increased
        assert!(second_capture_time >= first_capture_time, 3);

        // Player 2 captures again (now allowed since they're not current king)
        ts::next_tx(scenario, @0x222);
        let ts3 = second_capture_time + 1;
        king_game::capture_hill(&mut hill, ts3, ts::ctx(scenario));
        assert!(king_game::current_king(&hill) == @0x222, 4);

        ts::return_shared(hill);
        ts::end(scenario_val);
    }

    // Test game flow with three players
    #[test]
    fun test_three_player_rotation() {
        let mut scenario_val = ts::begin(@0xAAA);
        let scenario = &mut scenario_val;

        init_game(scenario);
        let mut hill = ts::take_shared<king_game::KingHill>(scenario);

        // Player B captures
        ts::next_tx(scenario, @0xBBB);
        let t1 = 100u64;
        king_game::capture_hill(&mut hill, t1, ts::ctx(scenario));
        assert!(king_game::current_king(&hill) == @0xBBB, 1);

        // Player C captures
        ts::next_tx(scenario, @0xCCC);
        let t2 = t1 + 10;
        king_game::capture_hill(&mut hill, t2, ts::ctx(scenario));
        assert!(king_game::current_king(&hill) == @0xCCC, 2);

        // Player A captures (original admin)
        ts::next_tx(scenario, @0xAAA);
        let t3 = t2 + 5;
        king_game::capture_hill(&mut hill, t3, ts::ctx(scenario));
        assert!(king_game::current_king(&hill) == @0xAAA, 3);

        ts::return_shared(hill);
        ts::end(scenario_val);
    }

    // Test crown time progression
    #[test]
    fun test_time_progression() {
        let mut scenario_val = ts::begin(@0x123);
        let scenario = &mut scenario_val;

        init_game(scenario);
        let mut hill = ts::take_shared<king_game::KingHill>(scenario);

        let initial_time = king_game::crowned_at(&hill);
        assert!(initial_time == 0, 1);

        // First capture
        ts::next_tx(scenario, @0x456);
        let t1 = 20u64;
        king_game::capture_hill(&mut hill, t1, ts::ctx(scenario));
        let first_time = king_game::crowned_at(&hill);
        assert!(first_time > 0, 2);

        // Second capture - time should be later
        ts::next_tx(scenario, @0x789);
        let t2 = first_time + 10;
        king_game::capture_hill(&mut hill, t2, ts::ctx(scenario));
        let second_time = king_game::crowned_at(&hill);
        assert!(second_time >= first_time, 3);

        ts::return_shared(hill);
        ts::end(scenario_val);
    }
}
