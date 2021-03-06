#!/usr/bin/python3
from os import system
import sys

if __name__ == "__main__":
    width = 123
    height = 213

    dir = "rand-test/"

    if len(sys.argv) > 1 and sys.argv[1] == "64":
        program = "./line-64"
    else:
        program = "./line"

    with open(dir + "log.txt", "r") as log:
        for line in log:
            print(f"Executing\t{line}", end="")
            system(line)
