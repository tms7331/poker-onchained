from flask import Flask
import asyncio
import threading
from play import (
    play_hand,
    PokerTable,
    Web3,
)
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)

# Global variables to store game state
game_state = {
    "is_running": False,
    "table_obj": None,
}


async def run_game(table):
    game_state["table_obj"] = table
    await play_hand(table)


def start_game():
    global game_state
    game_state["is_running"] = True

    w3 = Web3(Web3.HTTPProvider("https://base-sepolia-rpc.publicnode.com"))
    # Create poker table instances for both players
    table = PokerTable(w3)
    asyncio.run(run_game(table))


@app.route("/hand-history")
def get_hand_history():
    hand_history = game_state["table_obj"].get_hand_history()
    print("RETURNING", hand_history)
    return hand_history


@app.route("/hand-history-fake")
def get_hand_history_fake():
    hand_history = """
HAND_START
Game: No-Limit Texas Hold'em
Blinds: $1/$2
Table: Table #7
Date: 2025-05-23 10:13:45 UTC
Dealer: Seat 3
Jimmy: Seat 5

SEATS
Seat 1: Alice ($200)
Seat 2: Bob ($200)
Seat 3: Carol ($200) [DEALER]
Seat 4: Dave ($200)
Seat 5: Jimmy ($200)
Seat 6: Frank ($200)

HOLE_CARDS
Jimmy is dealt [2s 5s]

PRE_FLOP
Alice (SB) posts $1
Bob (BB) posts $2
Carol folds
Dave raises to $6
Jimmy calls $6
Frank folds
Alice folds
Bob calls $4

FLOP [Ks 9h 2d]
Bob checks
Dave bets $10
Jimmy calls $10
Bob folds

TURN [Ks 9h 2d] [7c]
Dave bets $25
Jimmy raises to $70
"""
    return hand_history


if __name__ == "__main__":
    # Start the game in a separate thread
    game_thread = threading.Thread(target=start_game)
    game_thread.daemon = True
    game_thread.start()

    # Start the Flask server
    app.run(host="0.0.0.0", port=5001)
