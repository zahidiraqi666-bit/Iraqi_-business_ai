#!/usr/bin/env python3
"""Break-even calculator for small businesses.

Example:
    python3 tools/breakeven.py --fixed 5000 --price 25 --variable 10
"""

import argparse
import math
import sys


def main() -> int:
    parser = argparse.ArgumentParser(description="Break-even calculator")
    parser.add_argument("--fixed", type=float, required=True, help="monthly fixed costs")
    parser.add_argument("--price", type=float, required=True, help="selling price per unit")
    parser.add_argument("--variable", type=float, required=True, help="variable cost per unit")
    args = parser.parse_args()

    if min(args.fixed, args.price, args.variable) < 0:
        print("Error: values must not be negative.", file=sys.stderr)
        return 1

    margin = args.price - args.variable
    if margin <= 0:
        print("Error: price must be higher than variable cost per unit.", file=sys.stderr)
        return 1

    units = math.ceil(args.fixed / margin)
    revenue = units * args.price

    print(f"Contribution margin per unit : {margin:.2f}")
    print(f"Break-even units per month   : {units}")
    print(f"Break-even revenue per month : {revenue:.2f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
