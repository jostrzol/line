#!/usr/bin/python3
from os import system
from random import random, randint

if __name__ == "__main__":
    width = 123
    height = 213

    dir = "rand-test/"

    log = open(dir + "log.txt", "w")

    for i in range(100):
        xs = random() * (width-1)
        ys = random() * (height-1)

        xe = random() * (width-1)
        ye = random() * (height-1)

        color = randint(0, 255)

        cmd = (f"./line test.bmp {dir}test-{i}.bmp"
               f" {xs} {ys} {xe} {ye} {color}")

        system(cmd)
        log.write(cmd + "\n")

    log.close()
