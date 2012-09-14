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


static inline SV*
valid_av_fetch(AV *array, int index)
{
    SV **item = av_fetch(array, index, 1);
    if (item == NULL) {
        croak("Fetched data from array was unexpectedly NULL");
    }

    return *item;
}

static int
fetch_pdata(AV *insert_datas, int buf[3])
{
    SV *pdata = av_shift(insert_datas);

    if (!SvOK(pdata)) return 0; /* End of data */

    /* Validate data */
    if (!SvROK(pdata) || SvTYPE(SvRV(pdata)) != SVt_PVAV)
        goto invdata;

    I32 datalen = av_len((AV *)SvRV(pdata)) + 1;
    if (datalen < 2)
        goto invdata;

    AV *pdata_av = (AV *)SvRV(pdata);
    buf[0] = SvIV(valid_av_fetch(pdata_av, 0));
    buf[1] = SvIV(valid_av_fetch(pdata_av, 1));
    buf[2] = (datalen > 2) ? SvIV(valid_av_fetch(pdata_av, 2)) : 1;

    return 1;

invdata:
    croak("insert_data should be an array reference "
          "which contains x, y, and optionally weight");
}

static inline max(int a, int b) { return (a > b) ? a : b; }
static inline min(int a, int b) { return (a < b) ? a : b; }

/* Calculate the probability density of each point insertion
 * for each pixels around it which to be get affected of insertion. */
static void
calc_probability_density(density_matrix_t *dm, AV *insert_datas)
{
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
    int point[3];
    while (fetch_pdata(insert_datas, point)) {
        int x_beg = max(0, point[0] - x_effect_range);
        int x_end = min(w, point[0] + x_effect_range);
        int y_beg = max(0, point[1] - y_effect_range);
        int y_end = min(h, point[1] + y_effect_range);

        int x, y;
        for (x = x_beg; x < x_end; x++) {
            for (y = y_beg; y < y_end; y++) {
                int xd = x - point[0];
                int yd = y - point[1];

                SV *pixel_valsv = valid_av_fetch(dm->matrix, x+w*y);

                double pixel_val = 0.0;
                if (SvOK(pixel_valsv)) {
                    pixel_val = SvNV(pixel_valsv);
                }

                pixel_val += exp(
                    -(xd*xd/xsig_sq + yd*yd/ysig_sq - alpha*xd*yd/xysig_mul) / beta
                ) * point[2];

                sv_setnv(pixel_valsv, pixel_val);
            }
        }
    }
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
        density_matrix_t dm = {
            .matrix      = matrix,
            .xsize       = xsize,
            .ysize       = ysize,
            .xsigma      = xsigma,
            .ysigma      = ysigma,
            .correlation = correlation,
        };

        calc_probability_density(&dm, insert_datas);

        RETVAL = matrix;
    OUTPUT:
        RETVAL
