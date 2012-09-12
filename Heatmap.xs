#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#include <math.h>   /* exp(3), sqrt(3), ceil(3) */

/* Ignore calculating pixel value if its value is less than this. */
#define EXP_IGNORE_THRESHOLD -36.04365338911715

typedef unsigned int uint;

typedef struct {
    AV     *matrix;      /* Probability density matrix  */
    uint    xsize;       /* Width of image              */
    uint    ysize;       /* Height of image             */
    double  xsigma;      /* X-dimentional sigma         */
    double  ysigma;      /* Y-dimentional sigma         */
    double  correlation; /* Correlation between x and y */
} density_matrix_t;

static int
fetch_insert_data(AV *insert_datas, int buf[3])
{
    int i;
    SV *point = av_shift(insert_datas);
    SV **tmp;
    I32 datalen;

    /* Validations */
    if (!SvOK(point)) return 0;
    if (!SvROK(point) || SvTYPE(SvRV(point)) != SVt_PVAV) {
        croak("insert_datas containing non ARRAY refs item");
    }

    datalen = av_len((AV *)SvRV(point)) + 1;
    if (datalen < 2) {
        croak("insert_data must contain x([0]), y([1]) and optionally weight([2])");
    }

    for (i = 0; i < datalen; i++) {
        if ((tmp = av_fetch((AV *)SvRV(point), i, 1)) == NULL) {
            croak("fetched datas was NULL");
        }
        buf[i] = SvIV(*tmp);
    }

    // Default 1 for weight
    if (datalen == 2) {
        buf[2] = 1;
    }

    return 1;
}

static inline max(int a, int b) { return (a > b) ? a : b; }
static inline min(int a, int b) { return (a < b) ? a : b; }

/* Calculate the probability density of each point insertion
 * for each pixels around it which to be get affected of insertion. */
static void
calc_probability_density(density_matrix_t *dm, AV *insert_datas)
{
    int  point[3];
    int  x, y;
    int  x_beg, y_beg, x_end, y_end;
    int  xd, yd;

    const int w = dm->xsize, h = dm->ysize;

    /* Calculate things to not calculate these again. */
    const double xsig_sq   = dm->xsigma * dm->xsigma;
    const double ysig_sq   = dm->ysigma * dm->ysigma;
    const double xysig_mul = dm->xsigma * dm->ysigma;
    const double alpha     = 2 * dm->correlation;
    const double beta      = 2 * (1 - dm->correlation * dm->correlation);

    /* (X|Y)-dimentional effective range of point insertion. */
    const uint x_effect_range = (uint)ceil(sqrt(-(EXP_IGNORE_THRESHOLD * beta) * xsig_sq));
    const uint y_effect_range = (uint)ceil(sqrt(-(EXP_IGNORE_THRESHOLD * beta) * ysig_sq));

    /*
     * The equation used to calculate 2-dimentional probability density
     * can be found at following URL:
     * Multivariate normal distribution - Wikipedia, the free encyclopedia
     *    http://en.wikipedia.org/wiki/Multivariate_normal_distribution#Bivariate_case
     */
    while (fetch_insert_data(insert_datas, point)) {
        x_beg = max(0, point[0] - x_effect_range);
        x_end = min(w, point[0] + x_effect_range);
        y_beg = max(0, point[1] - y_effect_range);
        y_end = min(h, point[1] + y_effect_range);

        for (x = x_beg; x < x_end; x++) {
            for (y = y_beg; y < y_end; y++) {
                xd = x - point[0];
                yd = y - point[1];

                SV **pixel_valsv = av_fetch(dm->matrix, x+w*y, 1);
                if (pixel_valsv == NULL)
                    croak("Failed fetching value of matrix[%d]", x+w*y);

                double pixel_val = 0.0;
                if (SvOK(*pixel_valsv))
                    pixel_val = SvNV(*pixel_valsv);

                pixel_val += exp(
                    -(xd*xd/xsig_sq + yd*yd/ysig_sq - alpha*xd*yd/xysig_mul) / beta
                ) * point[2];

                sv_setnv(*pixel_valsv, pixel_val);
            }
        }
    }
}

static AV*
generate_matrix(AV *matrix, uint xsize, uint ysize, 
                double xsigma, double ysigma, double correlation, AV *insert_datas)
{
    int i;
    void *ptr;

    density_matrix_t dm = {
        .matrix      = matrix,
        .xsize       = xsize,
        .ysize       = ysize,
        .xsigma      = xsigma,
        .ysigma      = ysigma,
        .correlation = correlation,
    };

    calc_probability_density(&dm, insert_datas);

    return matrix;
}

MODULE = Imager::Heatmap		PACKAGE = Imager::Heatmap
PROTOTYPES: DISABLE

AV*
xs_generate_matrix(matrix, xsize, ysize, xsigma, ysigma, correlation, insert_datas)
    AV          *matrix;
    unsigned int xsize;
    unsigned int ysize;
    double       xsigma;
    double       ysigma;
    double       correlation;
    AV          *insert_datas;

    CODE:

        RETVAL = generate_matrix(matrix, xsize, ysize,
                                 xsigma, ysigma, correlation, insert_datas);
    OUTPUT:
        RETVAL
