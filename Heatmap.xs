#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#include <math.h>   /* exp(3), sqrt(3), ceil(3) */

/* Buffer size to extend per realloc(3) call. */
#define ALLOCATE_BLOCK 32
/* Ignore calculating pixel value if its value is less than this. */
#define EXP_IGNORE_THRESHOLD -36.04365338911715

typedef unsigned int uint;

typedef struct {
    double *matrix;      /* Probability density matrix  */
    uint    xsize;       /* Width of image              */
    uint    ysize;       /* Height of image             */
    double  xsigma;      /* X-dimentional sigma         */
    double  ysigma;      /* Y-dimentional sigma         */
    double  correlation; /* Correlation between x and y */
} density_matrix_t;

static int debug_flag;

/* TODO: make debug output(for testing) */

/* Call fetch_method and make it return value to array [x, y, weight]. */
static I32
fetch(pTHX_ SV *fetch_method, int insert_data[3])
{
    dSP;
    I32 arrlen, ax;
    
    ENTER;
    SAVETMPS;

    PUSHMARK(SP);

    arrlen = call_sv(fetch_method, G_ARRAY);
    
    SPAGAIN;
    SP -= arrlen;
    ax = (SP - PL_stack_base) + 1;

    if (arrlen >= 2) {
        insert_data[0] = SvIV(ST(0));
        insert_data[1] = SvIV(ST(1));
        /* Weight of this point. default is 1 */
        insert_data[2] = (arrlen >= 3) ? SvIV(ST(2)) : 1;
    }

    PUTBACK;
    FREETMPS;
    LEAVE;

    return arrlen;
}

static inline max(int a, int b) { return (a > b) ? a : b; }
static inline min(int a, int b) { return (a < b) ? a : b; }

/* Calculate the probability density of each point insertion
 * for each pixels around it which to be get affected of insertion. */
static void
calc_probability_density(density_matrix_t *dm, int (*points)[3], long npoints)
{
    long i;
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
    for (i = 0; i < npoints; i++) {
        x_beg = max(0, points[i][0] - x_effect_range);
        x_end = min(w, points[i][0] + x_effect_range);
        y_beg = max(0, points[i][1] - y_effect_range);
        y_end = min(h, points[i][1] + y_effect_range);

        for (x = x_beg; x < x_end; x++) {
            for (y = y_beg; y < y_end; y++) {
                xd = x - points[i][0];
                yd = y - points[i][1];

                dm->matrix[x+w*y] += exp(
                    -(xd*xd/xsig_sq + yd*yd/ysig_sq - alpha*xd*yd/xysig_mul) / beta
                ) * points[i][2];
            }
        }
    }
}

static AV*
generate_matrix(uint xsize, uint ysize, double xsigma, double ysigma,
                double correlation, SV *fetch_method, long max_data_at_time)
{
    int i;
    void *ptr;

    int  (*points)[3]; /* [0] = x, [1] = y, [2] = weight */
    long npoints;

    density_matrix_t dm = {
        .xsize       = xsize,
        .ysize       = ysize,
        .xsigma      = xsigma,
        .ysigma      = ysigma,
        .correlation = correlation,
    };

    /* Probability density matrix */
    AV *perlarray_matrix = (AV *)sv_2mortal((SV *)newAV());

    Newxz(dm.matrix, xsize*ysize, double);

    do {
        if (debug_flag) warn("Start fetching datas");

        points  = NULL;
        npoints = 0;

        while (max_data_at_time == 0 || npoints < max_data_at_time) {
            if (npoints % ALLOCATE_BLOCK == 0) {
                /* Using temporary variable ptr to avoid syntax error.
                   I think there is no way to specify complex types as (*int)[3] in Renew(). */
                ptr = points;
                Renew(ptr, (npoints+ALLOCATE_BLOCK)*3, int);
                points = ptr;
            }

            /* Return value of fetch_method should contain more than 2 items: (x, y[, weight]) */
            if (fetch(aTHX_ fetch_method, points[npoints]) < 2)
                break;

            npoints++;
        }

        if (debug_flag) warn("Fetched %ld datas", npoints);

        /* Process fetched data to generate normal distribution matrix. */
        if (npoints > 0) {
            if (debug_flag) warn("Start calculating density matrix");

            calc_probability_density(&dm, points, npoints);

            if (debug_flag) warn("Finish calculating density matrix");
        }

        Safefree(points);

    } while (npoints);

    for (i = 0; i < xsize*ysize; i++)
        av_push(perlarray_matrix, newSVnv(dm.matrix[i]));

    Safefree(dm.matrix);

    return perlarray_matrix;
}

MODULE = Imager::Heatmap		PACKAGE = Imager::Heatmap
PROTOTYPES: DISABLE

AV*
xs_generate_matrix(xsize, ysize, xsigma, ysigma, correlation, fetch_method, max_data_at_time)
    unsigned int xsize;
    unsigned int ysize;
    double       xsigma;
    double       ysigma;
    double       correlation;
    SV          *fetch_method;
    long         max_data_at_time;

    CODE:
        SV *debug;
        if ((debug = get_sv("Imager::Heatmap::DEBUG", 0)) == NULL)
            croak("Can't see $Imager::Heatmap::DEBUG");

        debug_flag = SvIV(debug);

        if (!(SvROK(fetch_method) && SvTYPE(SvRV(fetch_method)) == SVt_PVCV))
            croak("fetch_method must be a code reference");

        RETVAL = generate_matrix(xsize, ysize, xsigma, ysigma, correlation,
                                 fetch_method, max_data_at_time);

    OUTPUT:
        RETVAL
