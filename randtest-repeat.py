#!/usr/bin/python3
from os import system

if __name__ == "__main__":
    width = 123
    height = 213

    dir = "rand-test/"

    with open(dir + "log.txt", "r") as log:
        for line in log:
            print(f"Executing\t{line}", end="")
            system(line)
