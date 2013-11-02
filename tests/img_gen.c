#include <stdlib.h>
#include <stdio.h>

#define HI(num) (((num) & 0x0000FF00) >> 8)
#define LO(num) ((num) & 0x000000FF)


/*
 * PGM FUNCTIONS.
 */

typedef struct _PGMData {
    int row;
    int col;
    int max_gray;
    int *matrix;
} PGMData;

int *allocate_dynamic_matrix(int row, int col)
{
    int *ret_val;
    int i;
            
    ret_val = (int *) malloc(sizeof(int) * row * col);
    if (ret_val == NULL) {
        perror("memory allocation failure");
        exit(EXIT_FAILURE);
    }
    return ret_val;
}

void deallocate_dynamic_matrix(int *matrix)
{
    free(matrix);
}

void SkipComments(FILE *fp)
{
    int ch;
    char line[100];
 
    while ((ch = fgetc(fp)) != EOF && isspace(ch))
        ;
    if (ch == '#') {
        fgets(line, sizeof(line), fp);
        SkipComments(fp);
    } else
        fseek(fp, -1, SEEK_CUR);
}

PGMData* readPGM(const char *file_name, PGMData *data)
{
    FILE *pgmFile;
    char version[3];
    int i, j;
    int lo, hi;
 
    pgmFile = fopen(file_name, "rb");
    if (pgmFile == NULL) {
        perror("cannot open file to read");
        exit(EXIT_FAILURE);
    }
 
    fgets(version, sizeof(version), pgmFile);
    if (strcmp(version, "P5")) {
        fprintf(stderr, "Wrong file type!\n");
        exit(EXIT_FAILURE);
    }
 
    SkipComments(pgmFile);
    fscanf(pgmFile, "%d", &data->col);
    SkipComments(pgmFile);
    fscanf(pgmFile, "%d", &data->row);
    SkipComments(pgmFile);
    fscanf(pgmFile, "%d", &data->max_gray);
    fgetc(pgmFile);
 
    data->matrix = allocate_dynamic_matrix(data->row, data->col);
    if (data->max_gray > 255)
        for (i = 0; i < data->row; ++i)
            for (j = 0; j < data->col; ++j) {
                hi = fgetc(pgmFile);
                lo = fgetc(pgmFile);
                data->matrix[i * data->col + j] = (hi << 8) + lo;
            }
    else
        for (i = 0; i < data->row; ++i)
            for (j = 0; j < data->col; ++j) {
                lo = fgetc(pgmFile);
                data->matrix[i * data->col + j] = lo;
            }
 
    fclose(pgmFile);
    return data;
 
}

void writePGM(const char *filename, const PGMData *data)
{
    FILE *pgmFile;
    int i, j;
    int hi, lo;
 
    pgmFile = fopen(filename, "wb");
    if (pgmFile == NULL) {
        perror("cannot open file to write");
        exit(EXIT_FAILURE);
    }
 
    fprintf(pgmFile, "P5 ");
    fprintf(pgmFile, "%d %d ", data->col, data->row);
    fprintf(pgmFile, "%d ", data->max_gray);
 
    if (data->max_gray > 255) {
        for (i = 0; i < data->row; ++i) {
            for (j = 0; j < data->col; ++j) {
                hi = HI(data->matrix[i * data->col + j]);
                lo = LO(data->matrix[i * data->col + j]);
                fputc(hi, pgmFile);
                fputc(lo, pgmFile);
            }
 
        }
    } else {
        for (i = 0; i < data->row; ++i)
            for (j = 0; j < data->col; ++j) {
                lo = LO(data->matrix[i * data->col + j]);
                fputc(lo, pgmFile);
            }
    }
 
    fclose(pgmFile);
    deallocate_dynamic_matrix(data->matrix);
}

int main()
{
    PGMData *image = (PGMData *) malloc(sizeof(image));
    if (image == NULL)
    {
        return 0;
    }

    int n, m, i, j;

    scanf("%d %d", &n, &m);

    image->row = n;
    image->col = m;
    image->max_gray = 255;
    image->matrix = (int *) malloc(sizeof(int) * n * m);

    for (i = 0; i < n; ++i)
    {
        for (j = 0; j < m; ++j)
        {
            scanf("%d", &image->matrix[i * m + j]);
        }
    }

    writePGM("copy.pgm", image);

    return 0;
}
