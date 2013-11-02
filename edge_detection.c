#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <string.h>
#include <ctype.h>

#define DEG_TO_RAD  0.01745329252f

#define HI(num) (((num) & 0x0000FF00) >> 8)
#define LO(num) ((num) & 0x000000FF)

struct point {
    int x;
    int y;
    struct point *next;
};

extern void sobel(int *matrix, int row, int col, int *response, int threshold);
extern int hough_transform(int *matrix, int row, int col, int* acc, int angle_count,
        int angle_step, int radius_half, struct point **data);
extern int print_paths(int rows, int cols, struct point **data, int threshold,
        int max_break);

int threshold;
int max_break;
int angle_count;
int sobel_threshold;


/*
 * Funkcje do wczytywania / zapisywania obrazków PGM.
 * Pobrane ze strony: 
 * http://ugurkoltuk.wordpress.com/2010/03/04/an-extreme-simple-pgm-io-api/
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
}

int hough(PGMData *sobel)
{
    int i;
   
    /* Maksymalny promień okręgu (połowa przekątnej obrazka) */
    int radius = sqrt((sobel->row * sobel->row)/4 + (sobel->col * sobel->col)/4);
    /* Krok */
    int angle_step = 180 / angle_count;

    struct point **data = (struct point **) calloc(sizeof(struct point *), 
            2 * radius * angle_count);
    if (data == NULL)
    {
        goto fail_data_alloc;
    }
    for (i = 0; i < 2 * radius * angle_count; ++i)
    {
        data[i] = (struct point *) malloc(sizeof(struct point));
        if (data[i] == NULL)
        {
            goto fail_data_i_alloc;
        }
        data[i]->x = data[i]->y = 0;
        data[i]->next = NULL;
    }

    /*
     * Obliczenie parametrów prostej, na której może znajdować się dany punkt.
     */
    hough_transform(sobel->matrix, sobel->row, sobel->col, NULL, angle_count,
            angle_step, radius, data);
    /*
     * Łączenie punktów znajdujących się na tej samej prostej w linie, o ile
     * punkty te nie są zbytnio oddalone od siebie a tworzona przez nie linia
     * jest wystarczająco długa.
     */
    print_paths(radius * 2, angle_count, data, threshold, max_break);

    return 0;

fail_data_i_alloc:
fail_data_alloc:
    return -1;
}

int main(int argc, char *argv[])
{
    if (argc != 6 && argc != 7)
    {
        printf("Usage: <input_file> <min_length> <max_break> \
                <angle_count> <sobel_threshold> [<sobel_image>]\n");
        printf("    input_file:         ścieżka do pliku z obrazkiem\n");
        printf("    min_length:         minimalna liczba punktów, z której ma się \
                składać linia\n");
        printf("    max_break:          maksymalna przerwa między sąsiednimi punktami \
                w linii\n");
        printf("    angle_count:        liczba kątów, jaką program ma przeanalizować -\
                kąty są z przedziału [0, 180)\n");
        printf("    sobel_threshold:    minimalna wartość gradientu, jeśli w danym \
                punkcie jest większa od progu, uznajemy, że przez punkt przechodzi \
                linia\n");

        printf("    sobel_image:        opcjonalny, do wskazanego pliku zostanie \
                zapisany wynik pośredni - wynik aplikacji operatora Sobela\n");
        exit(1);
    }
    char *input_file = argv[1];
    threshold = atoi(argv[2]);
    max_break = atoi(argv[3]);
    angle_count = atoi(argv[4]);
    sobel_threshold = atoi(argv[5]);
    char *sobel_file = NULL;

    if (argc == 7)
    {
        sobel_file = argv[6];
    }

    PGMData *image = (PGMData *) malloc(sizeof(image));
    if (image == NULL)
    {
        goto fail_image_malloc;
    }
 
    PGMData *copy = (PGMData *) malloc(sizeof(copy));
    if (copy == NULL)
    {
        goto fail_copy_malloc;
    }  

    printf("Otwieranie obrazka.\n");
    image = readPGM(input_file, image);
    printf("Aplikowanie operatora Sobela.\n");

    copy->col = image->col;
    copy->row = image->row;
    copy->max_gray = image->max_gray;
    copy->matrix = (int *) malloc(sizeof(int) * image->row * image->col);
    if (copy->matrix == NULL)
    {
        goto fail_response_malloc;
    }
    
    sobel(image->matrix, image->row, image->col, copy->matrix, sobel_threshold);

    if (sobel_file != NULL)
    {
        writePGM(sobel_file, copy);
    }
    
    printf("Transformacja Hough.\n");
    hough(copy); 

    return 0;

fail_response_malloc:
    free(copy);
fail_copy_malloc:
    free(image);
fail_image_malloc:
    return -1;
}
