from web3 import Web3
from enum import Enum
from typing import List, Dict, Any, Tuple
import random
import time
from dotenv import load_dotenv
import os

load_dotenv()

# Contract address
POKER_CONTRACT_ADDRESS = "0x43cC9b4D73c53983Ee53448289032233320aDabB"
PRIVATE_KEY1 = os.getenv("PRIVATE_KEY1")
PRIVATE_KEY2 = os.getenv("PRIVATE_KEY2")


# Contract ABI - only including the functions we need to interact with
POKER_CONTRACT_ABI = [
    {
        "inputs": [
            {"internalType": "uint8", "name": "seatI", "type": "uint8"},
            {"internalType": "address", "name": "actionAddr", "type": "address"},
            {"internalType": "uint256", "name": "depositAmount", "type": "uint256"},
            {"internalType": "bool", "name": "autoPost", "type": "bool"},
        ],
        "name": "joinTable",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function",
    },
    {
        "inputs": [{"internalType": "uint8", "name": "seatI", "type": "uint8"}],
        "name": "leaveTable",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function",
    },
    {
        "inputs": [
            {"internalType": "uint8", "name": "seatI", "type": "uint8"},
            {"internalType": "uint256", "name": "rebuyAmount", "type": "uint256"},
        ],
        "name": "rebuy",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function",
    },
    {
        "inputs": [
            {"internalType": "uint8", "name": "seatI", "type": "uint8"},
            {"internalType": "bool", "name": "sittingIn", "type": "bool"},
        ],
        "name": "sitIn",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function",
    },
    {
        "inputs": [
            {"internalType": "uint8", "name": "actionType", "type": "uint8"},
            {"internalType": "uint8", "name": "seatI", "type": "uint8"},
            {"internalType": "uint256", "name": "amount", "type": "uint256"},
        ],
        "name": "takeAction",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function",
    },
    {
        "inputs": [
            {"internalType": "bool", "name": "muck", "type": "bool"},
            {"internalType": "bool", "name": "isFlush", "type": "bool"},
            {"internalType": "bool[7]", "name": "useCards", "type": "bool[7]"},
        ],
        "name": "showCards",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function",
    },
    {
        "inputs": [],
        "name": "tableId",
        "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [],
        "name": "handId",
        "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [],
        "name": "smallBlind",
        "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [],
        "name": "bigBlind",
        "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [],
        "name": "minBuyin",
        "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [],
        "name": "maxBuyin",
        "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [],
        "name": "numSeats",
        "outputs": [{"internalType": "uint8", "name": "", "type": "uint8"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "name": "plrActionAddr",
        "outputs": [{"internalType": "address", "name": "", "type": "address"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "name": "plrOwnerAddr",
        "outputs": [{"internalType": "address", "name": "", "type": "address"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "name": "plrStack",
        "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "name": "plrInHand",
        "outputs": [{"internalType": "bool", "name": "", "type": "bool"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "name": "plrSittingIn",
        "outputs": [{"internalType": "bool", "name": "", "type": "bool"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "name": "plrAutoPost",
        "outputs": [{"internalType": "bool", "name": "", "type": "bool"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "name": "plrBetStreet",
        "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "name": "plrBetHand",
        "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "name": "plrPostedBlinds",
        "outputs": [{"internalType": "int256", "name": "", "type": "int256"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "name": "plrShowdownVal",
        "outputs": [{"internalType": "uint16", "name": "", "type": "uint16"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "name": "plrHolecardsA",
        "outputs": [{"internalType": "uint8", "name": "", "type": "uint8"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "name": "plrHolecardsB",
        "outputs": [{"internalType": "uint8", "name": "", "type": "uint8"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [],
        "name": "flop0",
        "outputs": [{"internalType": "uint8", "name": "", "type": "uint8"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [],
        "name": "flop1",
        "outputs": [{"internalType": "uint8", "name": "", "type": "uint8"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [],
        "name": "flop2",
        "outputs": [{"internalType": "uint8", "name": "", "type": "uint8"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [],
        "name": "turn",
        "outputs": [{"internalType": "uint8", "name": "", "type": "uint8"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [],
        "name": "river",
        "outputs": [{"internalType": "uint8", "name": "", "type": "uint8"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [],
        "name": "handStage",
        "outputs": [{"internalType": "uint8", "name": "", "type": "uint8"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [],
        "name": "button",
        "outputs": [{"internalType": "uint8", "name": "", "type": "uint8"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [],
        "name": "lastPostedBB",
        "outputs": [{"internalType": "uint8", "name": "", "type": "uint8"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [],
        "name": "whoseTurn",
        "outputs": [{"internalType": "uint8", "name": "", "type": "uint8"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [],
        "name": "lastRaiseAmount",
        "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [],
        "name": "reset",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function",
    },
]


# Action types enum
class ActionType(Enum):
    Null = 0
    SBPost = 1
    BBPost = 2
    Bet = 3
    Fold = 4
    Call = 5
    Check = 6
    # A little dicey because this is NOT a valid action type in the contract
    # But makes things cleaner when selecting valid actions
    ShowCards = 7


class HandStage(Enum):
    SBPostStage = 0
    BBPostStage = 1
    HolecardsDeal = 2
    PreflopBetting = 3
    FlopDeal = 4
    FlopBetting = 5
    TurnDeal = 6
    TurnBetting = 7
    RiverDeal = 8
    RiverBetting = 9
    Showdown = 10
    Settle = 11


def get_valid_bet_range(
    player_stack: int,
    player_bet_this_street: int,
    max_bet_this_street: int,
    last_raise_amount: int,
) -> Tuple[int, int]:
    """
    Calculate the valid range of bet amounts for a player.

    Args:
        player_stack: The player's current stack
        player_bet_this_street: How much the player has bet this street
        max_bet_this_street: The maximum bet amount on this street
        last_raise_amount: The last raise amount (minimum raise size)

    Returns:
        Tuple of (min_bet, max_bet) where:
        - min_bet is the minimum valid bet amount
        - max_bet is the maximum valid bet amount (player's stack + current bet)
    """
    # Minimum bet must be at least the current max bet
    max_bet = player_stack
    min_bet = min(max_bet, max_bet_this_street * 2)
    return (min_bet, max_bet)


def get_valid_actions(flop0, smallBlind, bigBlind, plrBetStreet):
    print("Getting valid actions", flop0, smallBlind, bigBlind, plrBetStreet)
    if flop0 == 0 and sum(plrBetStreet) == 0:
        possible_actions = [ActionType.SBPost]
    elif flop0 == 0 and sum(plrBetStreet) == smallBlind:
        possible_actions = [ActionType.BBPost]
    # Ridiculous but single edge case for checking preflop
    elif flop0 == 0 and sum(plrBetStreet) == bigBlind * 2:
        possible_actions = [
            ActionType.Bet,
            ActionType.Check,
        ]
    elif sum(plrBetStreet) == 0:
        possible_actions = [
            ActionType.Bet,
            ActionType.Check,
        ]
    elif sum(plrBetStreet) > 0:
        possible_actions = [
            ActionType.Bet,
            ActionType.Fold,
            ActionType.Call,
        ]
    return possible_actions


def get_action_weights(valid_actions):
    """
    Want to add weighting to the actions to avoid bet/raise heavy hands
    """
    weights = []
    for action in valid_actions:
        if action == ActionType.Bet:
            weights.append(0.2)
        elif action == ActionType.Fold:
            weights.append(0.2)
        elif action == ActionType.Call:
            weights.append(0.5)
        elif action == ActionType.Check:
            weights.append(0.5)
        else:
            weights.append(1)
    # And now normalize
    weights = [w / sum(weights) for w in weights]
    return weights


class PokerTable:
    def __init__(self, w3: Web3, account):
        self.w3 = w3
        self.account = account
        self.contract = w3.eth.contract(
            address=POKER_CONTRACT_ADDRESS, abi=POKER_CONTRACT_ABI
        )

    def _get_signed_tx(self, tx):
        """Helper method to sign and send a transaction"""
        signed_tx = self.w3.eth.account.sign_transaction(tx, self.account.key)
        tx_hash = self.w3.eth.send_raw_transaction(signed_tx.raw_transaction)
        receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash)
        if receipt.status == 0:
            raise Exception(f"Transaction failed: {receipt.transactionHash.hex()}")
        return receipt

    async def join_table(
        self, seat_index: int, action_address: str, deposit_amount: int, auto_post: bool
    ):
        tx = self.contract.functions.joinTable(
            seat_index,
            action_address,
            # self.w3.to_wei(deposit_amount, "ether"),
            deposit_amount,
            auto_post,
        ).build_transaction(
            {
                "from": self.account.address,
                "nonce": self.w3.eth.get_transaction_count(self.account.address),
                "gas": 2000000,
                "gasPrice": self.w3.eth.gas_price,
            }
        )
        return self._get_signed_tx(tx)

    async def leave_table(self, seat_index: int):
        tx = self.contract.functions.leaveTable(seat_index).build_transaction(
            {
                "from": self.account.address,
                "nonce": self.w3.eth.get_transaction_count(self.account.address),
                "gas": 2000000,
                "gasPrice": self.w3.eth.gas_price,
            }
        )
        return self._get_signed_tx(tx)

    async def rebuy(self, seat_index: int, rebuy_amount: int):
        tx = self.contract.functions.rebuy(seat_index, rebuy_amount).build_transaction(
            {
                "from": self.account.address,
                "nonce": self.w3.eth.get_transaction_count(self.account.address),
                "gas": 2000000,
                "gasPrice": self.w3.eth.gas_price,
            }
        )
        return self._get_signed_tx(tx)

    async def sit_in(self, seat_index: int, sitting_in: bool):
        tx = self.contract.functions.sitIn(seat_index, sitting_in).build_transaction(
            {
                "from": self.account.address,
                "nonce": self.w3.eth.get_transaction_count(self.account.address),
                "gas": 2000000,
                "gasPrice": self.w3.eth.gas_price,
            }
        )
        return self._get_signed_tx(tx)

    async def take_action(self, action_type: ActionType, seat_index: int, amount: int):
        tx = self.contract.functions.takeAction(
            action_type.value, seat_index, amount
        ).build_transaction(
            {
                "from": self.account.address,
                "nonce": self.w3.eth.get_transaction_count(self.account.address),
                "gas": 2000000,
                "gasPrice": self.w3.eth.gas_price,
            }
        )
        return self._get_signed_tx(tx)

    async def show_cards(self, muck: bool, is_flush: bool, use_cards: List[bool]):
        tx = self.contract.functions.showCards(
            muck, is_flush, use_cards
        ).build_transaction(
            {
                "from": self.account.address,
                "nonce": self.w3.eth.get_transaction_count(self.account.address),
                "gas": 2000000,
                "gasPrice": self.w3.eth.gas_price,
            }
        )
        return self._get_signed_tx(tx)

    async def get_table_info_for_action(self) -> Dict[str, Any]:
        plrBetStreet = []
        for i in range(2):
            bet = self.contract.functions.plrBetStreet(i).call()
            plrBetStreet.append(bet)
        return {
            "flop0": self.contract.functions.flop0().call(),
            "plrBetStreet": plrBetStreet,
            "whoseTurn": self.contract.functions.whoseTurn().call(),
            "handStage": self.contract.functions.handStage().call(),
        }

    async def get_table_info(self) -> Dict[str, Any]:
        return {
            "tableId": self.contract.functions.tableId().call(),
            "handId": self.contract.functions.handId().call(),
            "smallBlind": self.contract.functions.smallBlind().call(),
            "bigBlind": self.contract.functions.bigBlind().call(),
            "minBuyin": self.contract.functions.minBuyin().call(),
            "maxBuyin": self.contract.functions.maxBuyin().call(),
            "numSeats": self.contract.functions.numSeats().call(),
        }

    async def get_player_info(self, seat_index: int) -> Dict[str, Any]:
        return {
            "actionAddr": self.contract.functions.plrActionAddr(seat_index).call(),
            "ownerAddr": self.contract.functions.plrOwnerAddr(seat_index).call(),
            "stack": self.contract.functions.plrStack(seat_index).call(),
            "inHand": self.contract.functions.plrInHand(seat_index).call(),
            "sittingIn": self.contract.functions.plrSittingIn(seat_index).call(),
            "autoPost": self.contract.functions.plrAutoPost(seat_index).call(),
            "betStreet": self.contract.functions.plrBetStreet(seat_index).call(),
            "betHand": self.contract.functions.plrBetHand(seat_index).call(),
            "postedBlinds": self.contract.functions.plrPostedBlinds(seat_index).call(),
            "showdownVal": self.contract.functions.plrShowdownVal(seat_index).call(),
            "holecardsA": self.contract.functions.plrHolecardsA(seat_index).call(),
            "holecardsB": self.contract.functions.plrHolecardsB(seat_index).call(),
        }

    async def get_table_state(self) -> Dict[str, Any]:
        return {
            "flop0": self.contract.functions.flop0().call(),
            "flop1": self.contract.functions.flop1().call(),
            "flop2": self.contract.functions.flop2().call(),
            "turn": self.contract.functions.turn().call(),
            "river": self.contract.functions.river().call(),
            "handStage": self.contract.functions.handStage().call(),
            "button": self.contract.functions.button().call(),
            "lastPostedBB": self.contract.functions.lastPostedBB().call(),
            "whoseTurn": self.contract.functions.whoseTurn().call(),
        }

    async def get_detailed_table_info(self) -> Dict[str, Any]:
        basic_info = await self.get_table_info()
        player_infos = [
            await self.get_player_info(i) for i in range(basic_info["numSeats"])
        ]
        table_state = await self.get_table_state()

        action_addresses = [
            self.contract.functions.plrActionAddr(i).call()
            for i in range(basic_info["numSeats"])
        ]
        owner_addresses = [
            self.contract.functions.plrOwnerAddr(i).call()
            for i in range(basic_info["numSeats"])
        ]

        return {
            **basic_info,
            "players": [
                {
                    "seatIndex": i,
                    "actionAddress": action_addresses[i],
                    "ownerAddress": owner_addresses[i],
                    **info,
                }
                for i, info in enumerate(player_infos)
            ],
            "tableState": {
                **table_state,
                "handStage": table_state["handStage"],
                "button": table_state["button"],
                "lastPostedBB": table_state["lastPostedBB"],
                "whoseTurn": table_state["whoseTurn"],
            },
        }

    async def reset(self):
        tx = self.contract.functions.reset().build_transaction(
            {
                "from": self.account.address,
                "nonce": self.w3.eth.get_transaction_count(self.account.address),
                "gas": 2000000,
                "gasPrice": self.w3.eth.gas_price,
            }
        )
        return self._get_signed_tx(tx)


async def reset_table():
    # Connect to the network
    w3 = Web3(Web3.HTTPProvider("https://base-sepolia-rpc.publicnode.com"))

    # Create two accounts (players)
    player1_account = w3.eth.account.from_key(PRIVATE_KEY1)

    # Create poker table instances for both players
    table1 = PokerTable(w3, player1_account)

    try:
        # Reset the table state
        print("Resetting table state...")
        await table1.reset()
        print("Table reset complete")
    except Exception as error:
        print("Error during hand:", error)


async def play_hand():
    # Connect to the network
    w3 = Web3(Web3.HTTPProvider("https://base-sepolia-rpc.publicnode.com"))

    # Create two accounts (players)
    player1_account = w3.eth.account.from_key(PRIVATE_KEY1)
    player2_account = w3.eth.account.from_key(PRIVATE_KEY2)

    # Create poker table instances for both players
    table1 = PokerTable(w3, player1_account)
    table2 = PokerTable(w3, player2_account)

    # Reset the table state
    print("Resetting table state...")
    await table1.reset()
    print("Table reset complete")

    # Get initial table info
    table_info = await table1.get_table_info()
    print("Initial Table Info:", table_info)

    # Player 1 joins table at seat 0
    print("Player 1 joining table...")
    await table1.join_table(0, player1_account.address, 100, True)
    print("Player 1 joined successfully")

    # NOTE - we shouldn't need to confirm they joined because we're checking for tx failure
    # Confirm they actually joined!
    # owner0 = table1.contract.functions.plrOwnerAddr(0).call().lower()
    # time.sleep(10)
    # assert (
    #     owner0 == player1_account.address.lower()
    # ), f"Player 1 did not join table! {owner0} != {player1_account.address.lower()}"

    # Player 2 joins table at seat 1
    print("Player 2 joining table...")
    await table2.join_table(1, player2_account.address, 100, True)
    print("Player 2 joined successfully")

    # Confirm they actually joined!
    # owner1 = table2.contract.functions.plrOwnerAddr(1).call().lower()
    # assert (
    #     owner1 == player2_account.address.lower()
    # ), f"Player 2 did not join table! {owner1} != {player2_account.address.lower()}"

    #### Now actions - in a loop take turns acting

    while True:
        table_action_state = await table1.get_table_info_for_action()
        if table_action_state["handStage"] == HandStage.Showdown:
            if table_action_state["whoseTurn"] == 0:
                await table1.show_cards(
                    False, False, [True, True, True, True, True, False, False]
                )
            elif table_action_state["whoseTurn"] == 1:
                await table2.show_cards(
                    False, False, [True, True, True, True, True, False, False]
                )
            continue

        valid_actions = get_valid_actions(
            table_action_state["flop0"],
            table_info["smallBlind"],
            table_info["bigBlind"],
            table_action_state["plrBetStreet"],
        )
        print("GOT VALID ACTIONS", valid_actions)

        weights = get_action_weights(valid_actions)
        valid_actions = [random.choices(valid_actions, weights=weights)[0]]
        action = valid_actions[0]

        # Choose a random action!
        if table_action_state["whoseTurn"] == 0:
            table = table1
            seatI = 0
        else:
            table = table2
            seatI = 1

        if action == ActionType.SBPost:
            amount = table_info["smallBlind"]
        elif action == ActionType.BBPost:
            amount = table_info["bigBlind"]
        elif action == ActionType.Bet:
            # TODO - get a valid bet amount...
            bet_range = get_valid_bet_range(
                table.contract.functions.plrStack(seatI).call(),
                table.contract.functions.plrBetStreet(seatI).call(),
                table_info["bigBlind"],
                table.contract.functions.lastRaiseAmount().call(),
            )
            amount = random.randint(bet_range[0], bet_range[1])
        elif action == ActionType.Fold:
            amount = 0
        elif action == ActionType.Call:
            # Contract calculates call amount
            amount = 0
        elif action == ActionType.Check:
            amount = 0

        print("Taking action", action, seatI, amount)
        await table.take_action(action, seatI, amount)

        # Just to make sure?
        time.sleep(2)


if __name__ == "__main__":
    import asyncio

    asyncio.run(play_hand())
    # asyncio.run(reset_table())
