#!/usr/bin/python3
from os import system
import sys
from random import random, randint

if __name__ == "__main__":
    width = 123
    height = 213

    dir = "rand-test/"

    if len(sys.argv) > 1 and sys.argv[1] == "64":
        program = "./line-64"
    else:
        program = "./line"

    log = open(dir + "log.txt", "w")

    for i in range(100):
        xs = random() * (width-1)
        ys = random() * (height-1)

        xe = random() * (width-1)
        ye = random() * (height-1)

        color = randint(0, 255)

        cmd = (f"{program} test.bmp {dir}test-{i}.bmp"
               f" {xs} {ys} {xe} {ye} {color}")

        print(f"Executing\t{cmd}")
        system(cmd)
        log.write(cmd + "\n")

    log.close()
