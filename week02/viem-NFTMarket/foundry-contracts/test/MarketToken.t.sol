import {Test} from "forge-std/Test.sol";
import {MarketToken} from "../src/MarketToken.sol";
import {console} from "forge-std/console.sol";

contract MarketTokenTest is Test {
    MarketToken public marketToken;
    address public alice = makeAddr("Alice");
    address public bob = makeAddr("Bob");

    function setUp() public {
        vm.prank(alice);
        marketToken = new MarketToken(1000);
    }

    function test_InitialSupply() public {
        assertEq(marketToken.totalSupply(), 1000);
    }
    
}