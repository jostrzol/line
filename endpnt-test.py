#!/usr/bin/python3
from os import system

if __name__ == "__main__":
    dir = "endpnt-test/"

    xs_base = 20
    ys = 50
    xe_base = 25
    ye = 50
    color = 255

    for i in range(101):
        xs = xs_base + i/100
        xe = xe_base - i/100

        cmd = (f"./line test.bmp {dir}test-{i}.bmp"
               f" {xs} {ys} {xe} {ye} {color}")

        print(f"Executing\t{cmd}")
        system(cmd)
