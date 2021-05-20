#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define N_ARG 8

extern void line(void *img, unsigned int xs, unsigned int ys, unsigned int xe, unsigned int ye, unsigned int color);

#define atofp16_16(str) atof(str) * (1 << 16);

int main(int argc, char *argv[])
{
    if (argc != N_ARG)
    {
        printf("Expected %d arguments, not %d\n", N_ARG - 1, argc - 1);
        return -1;
    }

    const char *inFilename = argv[1];
    FILE *inFile = fopen(inFilename, "rb");
    if (!inFile)
    {
        printf("Couldn't open file \"%s\" for reading\n", inFilename);
        return -1;
    }
    fseek(inFile, 0, SEEK_END);
    size_t size = ftell(inFile);
    rewind(inFile);

    void *buff = malloc(size);
    fread(buff, size, 1, inFile);

    fclose(inFile);

    int xs = atofp16_16(argv[3]);
    int ys = atofp16_16(argv[4]);
    int xe = atofp16_16(argv[5]);
    int ye = atofp16_16(argv[6]);

    unsigned int color = atoi(argv[7]);

    line(buff, xs, ys, xe, ye, color);

    const char *outFilename = argv[2];
    FILE *outFile = fopen(outFilename, "w");
    if (!outFile)
    {
        printf("Couldn't open file \"%s\" for writing\n", outFilename);
        return -1;
    }
    fwrite(buff, size, 1, outFile);
    fclose(outFile);

    return 0;
}