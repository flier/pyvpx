%module(docstring="Python Binding of WebM VP8 Codec") vpx

%include "cpointer.i"

/**
 * Describes the vpx image descriptor and associated operations
 */
%{
#include <vpx/vpx_image.h>
%}


/*!\brief Current ABI version number
 *
 * \internal
 * If this file is altered in any way that changes the ABI, this value
 * must be bumped.  Examples include, but are not limited to, changing
 * types, removing or reassigning enums, adding/removing/rearranging
 * fields to structures
 */
%constant int VPX_IMAGE_ABI_VERSION = (1); /**<\hideinitializer*/


%constant int VPX_IMG_FMT_PLANAR     = 0x100;  /**< Image is a planar format */
%constant int VPX_IMG_FMT_UV_FLIP    = 0x200;  /**< V plane precedes U plane in memory */
%constant int VPX_IMG_FMT_HAS_ALPHA  = 0x400;  /**< Image has an alpha channel component */


/*!\brief List of supported image formats */
typedef enum vpx_img_fmt {
    VPX_IMG_FMT_NONE,
    VPX_IMG_FMT_RGB24,   /**< 24 bit per pixel packed RGB */
    VPX_IMG_FMT_RGB32,   /**< 32 bit per pixel packed 0RGB */
    VPX_IMG_FMT_RGB565,  /**< 16 bit per pixel, 565 */
    VPX_IMG_FMT_RGB555,  /**< 16 bit per pixel, 555 */
    VPX_IMG_FMT_UYVY,    /**< UYVY packed YUV */
    VPX_IMG_FMT_YUY2,    /**< YUYV packed YUV */
    VPX_IMG_FMT_YVYU,    /**< YVYU packed YUV */
    VPX_IMG_FMT_BGR24,   /**< 24 bit per pixel packed BGR */
    VPX_IMG_FMT_RGB32_LE, /**< 32 bit packed BGR0 */
    VPX_IMG_FMT_ARGB,     /**< 32 bit packed ARGB, alpha=255 */
    VPX_IMG_FMT_ARGB_LE,  /**< 32 bit packed BGRA, alpha=255 */
    VPX_IMG_FMT_RGB565_LE,  /**< 16 bit per pixel, gggbbbbb rrrrrggg */
    VPX_IMG_FMT_RGB555_LE,  /**< 16 bit per pixel, gggbbbbb 0rrrrrgg */
    VPX_IMG_FMT_YV12    = VPX_IMG_FMT_PLANAR | VPX_IMG_FMT_UV_FLIP | 1, /**< planar YVU */
    VPX_IMG_FMT_I420    = VPX_IMG_FMT_PLANAR | 2,
    VPX_IMG_FMT_VPXYV12 = VPX_IMG_FMT_PLANAR | VPX_IMG_FMT_UV_FLIP | 3, /** < planar 4:2:0 format with vpx color space */
    VPX_IMG_FMT_VPXI420 = VPX_IMG_FMT_PLANAR | 4   /** < planar 4:2:0 format with vpx color space */
}
vpx_img_fmt_t; /**< alias for enum vpx_img_fmt */

%constant int VPX_PLANE_PACKED = 0;   /**< To be used for all packed formats */
%constant int VPX_PLANE_Y      = 0;   /**< Y (Luminance) plane */
%constant int VPX_PLANE_U      = 1;   /**< U (Chroma) plane */
%constant int VPX_PLANE_V      = 2;   /**< V (Chroma) plane */
%constant int VPX_PLANE_ALPHA  = 3;   /**< A (Transparency) plane */

/**\brief Image Descriptor */
typedef struct vpx_image
{
    vpx_img_fmt_t fmt; /**< Image Format */

    /* Image storage dimensions */
    unsigned int  w;   /**< Stored image width */
    unsigned int  h;   /**< Stored image height */

    /* Image display dimensions */
    unsigned int  d_w;   /**< Displayed image width */
    unsigned int  d_h;   /**< Displayed image height */

    /* Chroma subsampling info */
    unsigned int  x_chroma_shift;   /**< subsampling order, X */
    unsigned int  y_chroma_shift;   /**< subsampling order, Y */

    /* Image data pointers. */
    unsigned char *planes[4];  /**< pointer to the top left pixel for each plane */
    int      stride[4];  /**< stride between rows for each plane */

    int     bps; /**< bits per sample (for packed formats) */

    /* The following member may be set by the application to associate data
     * with this image.
     */
    void    *user_priv; /**< may be set by the application to associate data
                     *   with this image. */

    /* The following members should be treated as private. */
    unsigned char *img_data;       /**< private */
    int      img_data_owner; /**< private */
    int      self_allocd;    /**< private */
} vpx_image_t; /**< alias for struct vpx_image */

%inline%{

int vpx_img_get_size(vpx_image_t *img)
{
    int s = (img->fmt & VPX_IMG_FMT_PLANAR) ? img->w : img->bps * img->w / 8;
    return (img->fmt & VPX_IMG_FMT_PLANAR) ? img->h * img->w * img->bps / 8 : img->h * s;
}

PyObject* vpx_img_get_data(vpx_image_t *img)
{
    return PyBuffer_FromReadWriteMemory(img->planes[0], vpx_img_get_size(img));
}

void vpx_img_clear(vpx_image_t *img)
{
    memset(img->planes[0], 0, vpx_img_get_size(img));
}

int vpx_img_copy_to(vpx_image_t *img, PyObject *obj)
{
    void *buf = NULL;
    int len = 0, size = 0;

    if (!PyBuffer_Check(obj) || -1 == PyObject_AsWriteBuffer(obj, &buf, &len))
    {
        PyErr_SetString(PyExc_ValueError,"Expected a writable buffer");
        return 0;
    }

    size = vpx_img_get_size(img);

    if (size > len)
    {
        PyErr_SetString(PyExc_ValueError,"the writable buffer is too small");
        return 0;
    }

    printf("copying %d bytes from %p/%p/%p to %p", size, img->planes[0], img->planes[1], img->planes[2], buf);

    memcpy(buf, img->planes[0], size);

    return size;
}

////
// YUV to RGB Conversion
//
// http://fourcc.org/fccyvrgb.php
//
void vpx_img_convert_to(vpx_image_t *src, vpx_image_t *dst)
{
    int row, col, y, u, v, r, g, b;
    unsigned char *pY, *pU, *pV, *pRGB, *pU1, *pV1, *pU2, *pV2, *ubuf, *vbuf;

    if (src->d_w != dst->d_w || src->d_h != dst->d_h)
    {
        PyErr_SetString(PyExc_ValueError,"the source and destination image should be same size");
    }
    else if (src->fmt == VPX_IMG_FMT_I420 && dst->fmt == VPX_IMG_FMT_RGB24)
    {
        pRGB = dst->planes[VPX_PLANE_PACKED];

        for (row = 0; row < src->d_h; row++)
        {
            pY = src->planes[VPX_PLANE_Y] + row * src->stride[VPX_PLANE_Y];
            pU = src->planes[VPX_PLANE_U] + (row >> src->y_chroma_shift) * src->stride[VPX_PLANE_U];
            pV = src->planes[VPX_PLANE_V] + (row >> src->y_chroma_shift) * src->stride[VPX_PLANE_V];

            for (col = 0; col < src->d_w; col++)
            {
                y = pY[col];
                u = pU[col >> src->x_chroma_shift];
                v = pV[col >> src->x_chroma_shift];

                b = (((y-16)*1164               +(u-128)*2018)/1000);
                g = (((y-16)*1164 -(v-128)* 813 -(u-128)* 391)/1000);
                r = (((y-16)*1164 +(v-128)*1596              )/1000);

                *pRGB++ = (unsigned char)b;
                *pRGB++ = (unsigned char)g;
                *pRGB++ = (unsigned char)r;
            }
        }
    }
    else if (src->fmt == VPX_IMG_FMT_RGB24 && dst->fmt == VPX_IMG_FMT_I420)
    {
        pU = ubuf = (unsigned char *) malloc(src->d_w*src->d_h);
        pV = vbuf = (unsigned char *) malloc(src->d_w*src->d_h);

        pRGB = src->planes[VPX_PLANE_PACKED];

        for (row = 0; row < src->d_h; row++)
        {
            pY = dst->planes[VPX_PLANE_Y] + row * dst->stride[VPX_PLANE_Y];

            for (col = 0; col < src->d_w; col++)
            {
                r = *pRGB++;
                g = *pRGB++;
                b = *pRGB++;

			    *pY++ = (unsigned char)(( r*257 +g*504 +b* 98)/1000+16);
			    *pV++ = (unsigned char)(( r*439 -g*368 -b* 71)/1000+128);
			    *pU++ = (unsigned char)((-r*148 -g*291 +b*439)/1000+128);
            }
        }

        for (row = 0; row < dst->d_h; row+=2)
        {
            pU = dst->planes[VPX_PLANE_U] + (row >> dst->y_chroma_shift) * dst->stride[VPX_PLANE_U];
            pV = dst->planes[VPX_PLANE_V] + (row >> dst->y_chroma_shift) * dst->stride[VPX_PLANE_V];

            pU1 = ubuf + dst->d_w * row;
            pU2 = ubuf + dst->d_w * (row + 1);
            pV1 = vbuf + dst->d_w * row;
            pV2 = vbuf + dst->d_w * (row + 1);

            for (col = 0; col < dst->d_w; col+=2)
            {
                *pU++ = (*pU1 + *(pU1+1) + *pU2 + *(pU2+1)) / 4;
                *pV++ = (*pV1 + *(pV1+1) + *pV2 + *(pV2+1)) / 4;

                pU1+=2;
                pU2+=2;
                pV1+=2;
                pV2+=2;
            }
        }

        free(ubuf);
        free(vbuf);
    }
    else
    {
        PyErr_SetString(PyExc_ValueError,"unsupported format conversion");
    }
}

%}

/**\brief Representation of a rectangle on a surface */
typedef struct vpx_image_rect
{
    unsigned int x; /**< leftmost column */
    unsigned int y; /**< topmost row */
    unsigned int w; /**< width */
    unsigned int h; /**< height */
} vpx_image_rect_t; /**< alias for struct vpx_image_rect */

/*!\brief Open a descriptor, allocating storage for the underlying image
 *
 * Returns a descriptor for storing an image of the given format. The
 * storage for the descriptor is allocated on the heap.
 *
 * \param[in]    img       Pointer to storage for descriptor. If this parameter
 *                         is NULL, the storage for the descriptor will be
 *                         allocated on the heap.
 * \param[in]    fmt       Format for the image
 * \param[in]    d_w       Width of the image
 * \param[in]    d_h       Height of the image
 * \param[in]    align     Alignment, in bytes, of each row in the image.
 *
 * \return Returns a pointer to the initialized image descriptor. If the img
 *         parameter is non-null, the value of the img parameter will be
 *         returned.
 */
%feature("docstring", "Open a descriptor, allocating storage for the underlying image") vpx_img_alloc;
vpx_image_t *vpx_img_alloc(vpx_image_t  *img,
                           vpx_img_fmt_t fmt,
                           unsigned int d_w,
                           unsigned int d_h,
                           unsigned int align);

/*!\brief Open a descriptor, using existing storage for the underlying image
 *
 * Returns a descriptor for storing an image of the given format. The
 * storage for descriptor has been allocated elsewhere, and a descriptor is
 * desired to "wrap" that storage.
 *
 * \param[in]    img       Pointer to storage for descriptor. If this parameter
 *                         is NULL, the storage for the descriptor will be
 *                         allocated on the heap.
 * \param[in]    fmt       Format for the image
 * \param[in]    d_w       Width of the image
 * \param[in]    d_h       Height of the image
 * \param[in]    align     Alignment, in bytes, of each row in the image.
 * \param[in]    img_data  Storage to use for the image
 *
 * \return Returns a pointer to the initialized image descriptor. If the img
 *         parameter is non-null, the value of the img parameter will be
 *         returned.
 */

%typemap(in) unsigned char *img_data
{
    if (PyBuffer_Check($input))
    {
        void *buf = NULL;
        int len = 0;

        if (-1 == PyObject_AsReadBuffer($input, &buf, &len))
        {
            PyErr_SetString(PyExc_ValueError,"Expected a readable buffer");
            return NULL;
        }

        $1 = (unsigned char *) buf;
    }
    else if (PyString_Check($input))
    {
        $1 = (unsigned char *) PyString_AsString($input);
    }
    else
    {
        PyErr_SetString(PyExc_ValueError,"Expected a string or readable buffer");
        return NULL;
    }
}

%feature("docstring", "Open a descriptor, using existing storage for the underlying image") vpx_img_wrap;
vpx_image_t *vpx_img_wrap(vpx_image_t  *img,
                          vpx_img_fmt_t fmt,
                          unsigned int d_w,
                          unsigned int d_h,
                          unsigned int align,
                          unsigned char *img_data);

/*!\brief Set the rectangle identifying the displayed portion of the image
 *
 * Updates the displayed rectangle (aka viewport) on the image surface to
 * match the specified coordinates and size.
 *
 * \param[in]    img       Image descriptor
 * \param[in]    x         leftmost column
 * \param[in]    y         topmost row
 * \param[in]    w         width
 * \param[in]    h         height
 *
 * \return 0 if the requested rectangle is valid, nonzero otherwise.
 */
%feature("docstring", "Set the rectangle identifying the displayed portion of the image") vpx_img_set_rect;
int vpx_img_set_rect(vpx_image_t  *img,
                     unsigned int  x,
                     unsigned int  y,
                     unsigned int  w,
                     unsigned int  h);


/*!\brief Flip the image vertically (top for bottom)
 *
 * Adjusts the image descriptor's pointers and strides to make the image
 * be referenced upside-down.
 *
 * \param[in]    img       Image descriptor
 */
%feature("docstring", "Flip the image vertically (top for bottom)") vpx_img_flip;
void vpx_img_flip(vpx_image_t *img);

/*!\brief Close an image descriptor
 *
 * Frees all allocated storage associated with an image descriptor.
 *
 * \param[in]    img       Image descriptor
 */
%feature("docstring", "Close an image descriptor") vpx_img_free;
void vpx_img_free(vpx_image_t *img);


/*!\file
 * \brief Describes the codec algorithm interface to applications.
 *
 * This file describes the interface between an application and a
 * video codec algorithm.
 *
 * An application instantiates a specific codec instance by using
 * vpx_codec_init() and a pointer to the algorithm's interface structure:
 *     <pre>
 *     my_app.c:
 *       extern vpx_codec_iface_t my_codec;
 *       {
 *           vpx_codec_ctx_t algo;
 *           res = vpx_codec_init(&algo, &my_codec);
 *       }
 *     </pre>
 *
 * Once initialized, the instance is manged using other functions from
 * the vpx_codec_* family.
 */
%{
#include <vpx/vpx_codec.h>
%}

/*!\brief Current ABI version number
 *
 * \internal
 * If this file is altered in any way that changes the ABI, this value
 * must be bumped.  Examples include, but are not limited to, changing
 * types, removing or reassigning enums, adding/removing/rearranging
 * fields to structures
 */
%constant int VPX_CODEC_ABI_VERSION = (2 + VPX_IMAGE_ABI_VERSION); /**<\hideinitializer*/

/*!\brief Algorithm return codes */
typedef enum {
    /*!\brief Operation completed without error */
    VPX_CODEC_OK,

    /*!\brief Unspecified error */
    VPX_CODEC_ERROR,

    /*!\brief Memory operation failed */
    VPX_CODEC_MEM_ERROR,

    /*!\brief ABI version mismatch */
    VPX_CODEC_ABI_MISMATCH,

    /*!\brief Algorithm does not have required capability */
    VPX_CODEC_INCAPABLE,

    /*!\brief The given bitstream is not supported.
     *
     * The bitstream was unable to be parsed at the highest level. The decoder
     * is unable to proceed. This error \ref SHOULD be treated as fatal to the
     * stream. */
    VPX_CODEC_UNSUP_BITSTREAM,

    /*!\brief Encoded bitstream uses an unsupported feature
     *
     * The decoder does not implement a feature required by the encoder. This
     * return code should only be used for features that prevent future
     * pictures from being properly decoded. This error \ref MAY be treated as
     * fatal to the stream or \ref MAY be treated as fatal to the current GOP.
     */
    VPX_CODEC_UNSUP_FEATURE,

    /*!\brief The coded data for this stream is corrupt or incomplete
     *
     * There was a problem decoding the current frame.  This return code
     * should only be used for failures that prevent future pictures from
     * being properly decoded. This error \ref MAY be treated as fatal to the
     * stream or \ref MAY be treated as fatal to the current GOP. If decoding
     * is continued for the current GOP, artifacts may be present.
     */
    VPX_CODEC_CORRUPT_FRAME,

    /*!\brief An application-supplied parameter is not valid.
     *
     */
    VPX_CODEC_INVALID_PARAM,

    /*!\brief An iterator reached the end of list.
     *
     */
    VPX_CODEC_LIST_END

}
vpx_codec_err_t;

/*! \brief Codec capabilities bitfield
 *
 *  Each codec advertises the capabilities it supports as part of its
 *  ::vpx_codec_iface_t interface structure. Capabilities are extra interfaces
 *  or functionality, and are not required to be supported.
 *
 *  The available flags are specified by VPX_CODEC_CAP_* defines.
 */
typedef long vpx_codec_caps_t;
%constant int VPX_CODEC_CAP_DECODER = 0x1; /**< Is a decoder */
%constant int VPX_CODEC_CAP_ENCODER = 0x2; /**< Is an encoder */
%constant int VPX_CODEC_CAP_XMA     = 0x4; /**< Supports eXternal Memory Allocation */


/*! \brief Initialization-time Feature Enabling
 *
 *  Certain codec features must be known at initialization time, to allow for
 *  proper memory allocation.
 *
 *  The available flags are specified by VPX_CODEC_USE_* defines.
 */
typedef long vpx_codec_flags_t;
%constant int VPX_CODEC_USE_XMA = 0x00000001;    /**< Use eXternal Memory Allocation mode */


/*!\brief Codec interface structure.
 *
 * Contains function pointers and other data private to the codec
 * implementation. This structure is opaque to the application.
 */
typedef const struct vpx_codec_iface vpx_codec_iface_t;


/*!\brief Codec private data structure.
 *
 * Contains data private to the codec implementation. This structure is opaque
 * to the application.
 */
typedef       struct vpx_codec_priv  vpx_codec_priv_t;


/*!\brief Iterator
 *
 * Opaque storage used for iterating over lists.
 */
typedef const void *vpx_codec_iter_t;

%inline%{

PyObject *vpx_codec_iter_alloc()
{
    PyObject *obj = PyBuffer_New(sizeof(vpx_codec_iter_t));

    void *buf = NULL;
    Py_ssize_t len = 0;

    if (-1 == PyObject_AsWriteBuffer(obj, &buf, &len) || len < 4)
    {
        PyErr_SetString(PyExc_ValueError,"Expected a 4 bytes writable buffer");
        return NULL;
    }

    memset(buf, 0, len);

    return obj;
}

%}

%typemap(in)  vpx_codec_iter_t*
{
    void *buf = NULL;
    Py_ssize_t len = 0;

    if (!PyBuffer_Check($input))
    {
        PyErr_SetString(PyExc_ValueError,"Expected a buffer object");
        return NULL;
    }

    if (-1 == PyObject_AsWriteBuffer($input, &buf, &len) || len < 4)
    {
        PyErr_SetString(PyExc_ValueError,"Expected a 4 bytes writable buffer");
        return NULL;
    }

    $1 = (vpx_codec_iter_t *) buf;
}

/*!\brief Codec context structure
 *
 * All codecs \ref MUST support this context structure fully. In general,
 * this data should be considered private to the codec algorithm, and
 * not be manipulated or examined by the calling application. Applications
 * may reference the 'name' member to get a printable description of the
 * algorithm.
 */
typedef struct vpx_codec_ctx
{
    char                    *name;        /**< Printable interface name */
    vpx_codec_iface_t       *iface;       /**< Interface pointers */
    vpx_codec_err_t          err;         /**< Last returned error */
    char                    *err_detail;  /**< Detailed info, if available */
    vpx_codec_flags_t        init_flags;  /**< Flags passed at init time */
    union
    {
        struct vpx_codec_dec_cfg  *dec;   /**< Decoder Configuration Pointer */
        struct vpx_codec_enc_cfg  *enc;   /**< Encoder Configuration Pointer */
        void                      *raw;
    }                        config;      /**< Configuration pointer aliasing union */
    vpx_codec_priv_t        *priv;        /**< Algorithm private storage */
} vpx_codec_ctx_t;


/*
 * Library Version Number Interface
 *
 * For example, see the following sample return values:
 *     vpx_codec_version()           (1<<16 | 2<<8 | 3)
 *     vpx_codec_version_str()       "v1.2.3-rc1-16-gec6a1ba"
 *     vpx_codec_version_extra_str() "rc1-16-gec6a1ba"
 */

/*!\brief Return the version information (as an integer)
 *
 * Returns a packed encoding of the library version number. This will only include
 * the major.minor.patch component of the version number. Note that this encoded
 * value should be accessed through the macros provided, as the encoding may change
 * in the future.
 *
 */
%feature("docstring", "Return the version information (as an integer)") vpx_codec_version;
int vpx_codec_version(void);

/*!\brief Return the version information (as a string)
 *
 * Returns a printable string containing the full library version number. This may
 * contain additional text following the three digit version number, as to indicate
 * release candidates, prerelease versions, etc.
 *
 */
%feature("docstring", "Return the version information (as a string)") vpx_codec_version_str;
const char *vpx_codec_version_str(void);


/*!\brief Return the version information (as a string)
 *
 * Returns a printable "extra string". This is the component of the string returned
 * by vpx_codec_version_str() following the three digit version number.
 *
 */
%feature("docstring", "Return the version information (as a string)") vpx_codec_version_extra_str;
const char *vpx_codec_version_extra_str(void);


/*!\brief Return the build configuration
 *
 * Returns a printable string containing an encoded version of the build
 * configuration. This may be useful to vpx support.
 *
 */
%feature("docstring", "Return the build configuration") vpx_codec_build_config;
const char *vpx_codec_build_config(void);


/*!\brief Return the name for a given interface
 *
 * Returns a human readable string for name of the given codec interface.
 *
 * \param[in]    iface     Interface pointer
 *
 */
%feature("docstring", "Return the name for a given interface") vpx_codec_iface_name;
const char *vpx_codec_iface_name(vpx_codec_iface_t *iface);


/*!\brief Convert error number to printable string
 *
 * Returns a human readable string for the last error returned by the
 * algorithm. The returned error will be one line and will not contain
 * any newline characters.
 *
 *
 * \param[in]    err     Error number.
 *
 */
%feature("docstring", "Convert error number to printable string") vpx_codec_err_to_string;
const char *vpx_codec_err_to_string(vpx_codec_err_t  err);


/*!\brief Retrieve error synopsis for codec context
 *
 * Returns a human readable string for the last error returned by the
 * algorithm. The returned error will be one line and will not contain
 * any newline characters.
 *
 *
 * \param[in]    ctx     Pointer to this instance's context.
 *
 */
%feature("docstring", "Retrieve error synopsis for codec context") vpx_codec_error;
const char *vpx_codec_error(vpx_codec_ctx_t  *ctx);


/*!\brief Retrieve detailed error information for codec context
 *
 * Returns a human readable string providing detailed information about
 * the last error.
 *
 * \param[in]    ctx     Pointer to this instance's context.
 *
 * \retval NULL
 *     No detailed information is available.
 */
%feature("docstring", "Retrieve detailed error information for codec context") vpx_codec_error_detail;
const char *vpx_codec_error_detail(vpx_codec_ctx_t  *ctx);


/* REQUIRED FUNCTIONS
 *
 * The following functions are required to be implemented for all codecs.
 * They represent the base case functionality expected of all codecs.
 */

/*!\brief Destroy a codec instance
 *
 * Destroys a codec context, freeing any associated memory buffers.
 *
 * \param[in] ctx   Pointer to this instance's context
 *
 * \retval #VPX_CODEC_OK
 *     The codec algorithm initialized.
 * \retval #VPX_CODEC_MEM_ERROR
 *     Memory allocation failed.
 */
%feature("docstring", "Destroy a codec instance") vpx_codec_destroy;
vpx_codec_err_t vpx_codec_destroy(vpx_codec_ctx_t *ctx);


/*!\brief Get the capabilities of an algorithm.
 *
 * Retrieves the capabilities bitfield from the algorithm's interface.
 *
 * \param[in] iface   Pointer to the algorithm interface
 *
 */
%feature("docstring", "Get the capabilities of an algorithm.") vpx_codec_get_caps;
vpx_codec_caps_t vpx_codec_get_caps(vpx_codec_iface_t *iface);


/*!\brief Control algorithm
 *
 * This function is used to exchange algorithm specific data with the codec
 * instance. This can be used to implement features specific to a particular
 * algorithm.
 *
 * This wrapper function dispatches the request to the helper function
 * associated with the given ctrl_id. It tries to call this function
 * transparently, but will return #VPX_CODEC_ERROR if the request could not
 * be dispatched.
 *
 * Note that this function should not be used directly. Call the
 * #vpx_codec_control wrapper macro instead.
 *
 * \param[in]     ctx              Pointer to this instance's context
 * \param[in]     ctrl_id          Algorithm specific control identifier
 *
 * \retval #VPX_CODEC_OK
 *     The control request was processed.
 * \retval #VPX_CODEC_ERROR
 *     The control request was not processed.
 * \retval #VPX_CODEC_INVALID_PARAM
 *     The data was not valid.
 */
%feature("docstring", "Control algorithm") vpx_codec_control_;
vpx_codec_err_t vpx_codec_control_(vpx_codec_ctx_t  *ctx,
                                   int               ctrl_id,
                                   ...);

/*!\defgroup cap_xma External Memory Allocation Functions
 *
 * The following functions are required to be implemented for all codecs
 * that advertise the VPX_CODEC_CAP_XMA capability. Calling these functions
 * for codecs that don't advertise this capability will result in an error
 * code being returned, usually VPX_CODEC_INCAPABLE
 * @{
 */


/*!\brief Memory Map Entry
 *
 * This structure is used to contain the properties of a memory segment. It
 * is populated by the codec in the request phase, and by the calling
 * application once the requested allocation has been performed.
 */
typedef struct vpx_codec_mmap
{
    /*
     * The following members are set by the codec when requesting a segment
     */
    unsigned int   id;     /**< identifier for the segment's contents */
    unsigned long  sz;     /**< size of the segment, in bytes */
    unsigned int   align;  /**< required alignment of the segment, in bytes */
    unsigned int   flags;  /**< bitfield containing segment properties */
#define VPX_CODEC_MEM_ZERO     0x1  /**< Segment must be zeroed by allocation */
#define VPX_CODEC_MEM_WRONLY   0x2  /**< Segment need not be readable */
#define VPX_CODEC_MEM_FAST     0x4  /**< Place in fast memory, if available */

    /* The following members are to be filled in by the allocation function */
    void          *base;   /**< pointer to the allocated segment */
    void (*dtor)(struct vpx_codec_mmap *map);         /**< destructor to call */
    void          *priv;   /**< allocator private storage */
} vpx_codec_mmap_t; /**< alias for struct vpx_codec_mmap */


/*!\brief Iterate over the list of segments to allocate.
 *
 * Iterates over a list of the segments to allocate. The iterator storage
 * should be initialized to NULL to start the iteration. Iteration is complete
 * when this function returns VPX_CODEC_LIST_END. The amount of memory needed to
 * allocate is dependent upon the size of the encoded stream. In cases where the
 * stream is not available at allocation time, a fixed size must be requested.
 * The codec will not be able to operate on streams larger than the size used at
 * allocation time.
 *
 * \param[in]      ctx     Pointer to this instance's context.
 * \param[out]     mmap    Pointer to the memory map entry to populate.
 * \param[in,out]  iter    Iterator storage, initialized to NULL
 *
 * \retval #VPX_CODEC_OK
 *     The memory map entry was populated.
 * \retval #VPX_CODEC_ERROR
 *     Codec does not support XMA mode.
 * \retval #VPX_CODEC_MEM_ERROR
 *     Unable to determine segment size from stream info.
 */
%feature("docstring", "Iterate over the list of segments to allocate.") vpx_codec_get_mem_map;
vpx_codec_err_t vpx_codec_get_mem_map(vpx_codec_ctx_t                *ctx,
                                      vpx_codec_mmap_t               *mmap,
                                      vpx_codec_iter_t               *iter);


/*!\brief Identify allocated segments to codec instance
 *
 * Stores a list of allocated segments in the codec. Segments \ref MUST be
 * passed in the order they are read from vpx_codec_get_mem_map(), but may be
 * passed in groups of any size. Segments \ref MUST be set only once. The
 * allocation function \ref MUST ensure that the vpx_codec_mmap_t::base member
 * is non-NULL. If the segment requires cleanup handling (e.g., calling free()
 * or close()) then the vpx_codec_mmap_t::dtor member \ref MUST be populated.
 *
 * \param[in]      ctx     Pointer to this instance's context.
 * \param[in]      mmaps   Pointer to the first memory map entry in the list.
 * \param[in]      num_maps  Number of entries being set at this time
 *
 * \retval #VPX_CODEC_OK
 *     The segment was stored in the codec context.
 * \retval #VPX_CODEC_INCAPABLE
 *     Codec does not support XMA mode.
 * \retval #VPX_CODEC_MEM_ERROR
 *     Segment base address was not set, or segment was already stored.

 */
%feature("docstring", "Identify allocated segments to codec instance") vpx_codec_set_mem_map;
vpx_codec_err_t  vpx_codec_set_mem_map(vpx_codec_ctx_t   *ctx,
                                       vpx_codec_mmap_t  *mmaps,
                                       unsigned int       num_maps);

/*!@} - end defgroup cap_xma*/
/*!@} - end defgroup codec*/


/*!\defgroup vp8_encoder WebM VP8 Encoder
 * \ingroup vp8
 *
 * @{
 */
%{
#include <vpx/vp8cx.h>
%}

/*!\name Algorithm interface for VP8
 *
 * This interface provides the capability to encode raw VP8 streams, as would
 * be found in AVI files.
 * @{
 */
vpx_codec_iface_t* vpx_codec_vp8_cx(void);
/*!@} - end algorithm interface member group*/


/*
 * Algorithm Flags
 */

/*!\brief Don't reference the last frame
 *
 * When this flag is set, the encoder will not use the last frame as a
 * predictor. When not set, the encoder will choose whether to use the
 * last frame or not automatically.
 */
%constant int VP8_EFLAG_NO_REF_LAST      = (1<<16);


/*!\brief Don't reference the golden frame
 *
 * When this flag is set, the encoder will not use the golden frame as a
 * predictor. When not set, the encoder will choose whether to use the
 * golden frame or not automatically.
 */
%constant int VP8_EFLAG_NO_REF_GF        = (1<<17);


/*!\brief Don't reference the alternate reference frame
 *
 * When this flag is set, the encoder will not use the alt ref frame as a
 * predictor. When not set, the encoder will choose whether to use the
 * alt ref frame or not automatically.
 */
%constant int VP8_EFLAG_NO_REF_ARF       = (1<<21);


/*!\brief Don't update the last frame
 *
 * When this flag is set, the encoder will not update the last frame with
 * the contents of the current frame.
 */
%constant int VP8_EFLAG_NO_UPD_LAST      = (1<<18);


/*!\brief Don't update the golden frame
 *
 * When this flag is set, the encoder will not update the golden frame with
 * the contents of the current frame.
 */
%constant int VP8_EFLAG_NO_UPD_GF        = (1<<22);


/*!\brief Don't update the alternate reference frame
 *
 * When this flag is set, the encoder will not update the alt ref frame with
 * the contents of the current frame.
 */
%constant int VP8_EFLAG_NO_UPD_ARF       = (1<<23);


/*!\brief Force golden frame update
 *
 * When this flag is set, the encoder copy the contents of the current frame
 * to the golden frame buffer.
 */
%constant int VP8_EFLAG_FORCE_GF         = (1<<19);


/*!\brief Force alternate reference frame update
 *
 * When this flag is set, the encoder copy the contents of the current frame
 * to the alternate reference frame buffer.
 */
%constant int VP8_EFLAG_FORCE_ARF        = (1<<24);


/*!\brief Disable entropy update
 *
 * When this flag is set, the encoder will not update its internal entropy
 * model based on the entropy of this frame.
 */
%constant int VP8_EFLAG_NO_UPD_ENTROPY   = (1<<20);


/*!\brief VP8 encoder control functions
 *
 * This set of macros define the control functions available for the VP8
 * encoder interface.
 *
 * \sa #vpx_codec_control
 */
enum vp8e_enc_control_id
{
    VP8E_UPD_ENTROPY           = 5,  /**< control function to set mode of entropy update in encoder */
    VP8E_UPD_REFERENCE,              /**< control function to set reference update mode in encoder */
    VP8E_USE_REFERENCE,              /**< control function to set which reference frame encoder can use */
    VP8E_SET_ROI_MAP,                /**< control function to pass an ROI map to encoder */
    VP8E_SET_ACTIVEMAP,              /**< control function to pass an Active map to encoder */
    VP8E_SET_SCALEMODE         = 11, /**< control function to set encoder scaling mode */
    /*!\brief control function to set vp8 encoder cpuused
     *
     * Changes in this value influences, among others, the encoder's selection
     * of motion estimation methods. Values greater than 0 will increase encoder
     * speed at the expense of quality.
     * The full set of adjustments can be found in
     * onyx_if.c:vp8_set_speed_features().
     * \todo List highlights of the changes at various levels.
     *
     * \note Valid range: -16..16
     */
    VP8E_SET_CPUUSED           = 13,
    VP8E_SET_ENABLEAUTOALTREF,       /**< control function to enable vp8 to automatic set and use altref frame */
    VP8E_SET_NOISE_SENSITIVITY,      /**< control function to set noise sensitivity */
    VP8E_SET_SHARPNESS,              /**< control function to set sharpness */
    VP8E_SET_STATIC_THRESHOLD,       /**< control function to set the threshold for macroblocks treated static */
    VP8E_SET_TOKEN_PARTITIONS,       /**< control function to set the number of token partitions  */
    VP8E_GET_LAST_QUANTIZER,         /**< return the quantizer chosen by the
                                          encoder for the last frame using the internal
                                          scale */
    VP8E_GET_LAST_QUANTIZER_64,      /**< return the quantizer chosen by the
                                          encoder for the last frame, using the 0..63
                                          scale as used by the rc_*_quantizer config
                                          parameters */
    VP8E_SET_ARNR_MAXFRAMES,         /**< control function to set the max number of frames blurred creating arf*/
    VP8E_SET_ARNR_STRENGTH ,         /**< control function to set the filter strength for the arf */
    VP8E_SET_ARNR_TYPE     ,         /**< control function to set the type of filter to use for the arf*/
    VP8E_SET_TUNING,                 /**< control function to set visual tuning */
    /*!\brief control function to set constrained quality level
     *
     * \attention For this value to be used vpx_codec_enc_cfg_t::g_usage must be
     *            set to #VPX_CQ.
     * \note Valid range: 0..63
     */
    VP8E_SET_CQ_LEVEL,

    /*!\brief Max data rate for Intra frames
     *
     * This value controls additional clamping on the maximum size of a
     * keyframe. It is expressed as a percentage of the average
     * per-frame bitrate, with the special (and default) value 0 meaning
     * unlimited, or no additional clamping beyond the codec's built-in
     * algorithm.
     *
     * For example, to allocate no more than 4.5 frames worth of bitrate
     * to a keyframe, set this to 450.
     *
     */
    VP8E_SET_MAX_INTRA_BITRATE_PCT,
};

/*!\brief vpx 1-D scaling mode
 *
 * This set of constants define 1-D vpx scaling modes
 */
typedef enum vpx_scaling_mode_1d
{
    VP8E_NORMAL      = 0,
    VP8E_FOURFIVE    = 1,
    VP8E_THREEFIVE   = 2,
    VP8E_ONETWO      = 3
} VPX_SCALING_MODE;


/*!\brief  vpx region of interest map
 *
 * These defines the data structures for the region of interest map
 *
 */

typedef struct vpx_roi_map
{
    unsigned char *roi_map;      /**< specify an id between 0 and 3 for each 16x16 region within a frame */
    unsigned int   rows;         /**< number of rows */
    unsigned int   cols;         /**< number of cols */
    int     delta_q[4];          /**< quantizer delta [-64, 64] off baseline for regions with id between 0 and 3*/
    int     delta_lf[4];         /**< loop filter strength delta [-32, 32] for regions with id between 0 and 3 */
    unsigned int   static_threshold[4];/**< threshold for region to be treated as static */
} vpx_roi_map_t;

/*!\brief  vpx active region map
 *
 * These defines the data structures for active region map
 *
 */


typedef struct vpx_active_map
{
    unsigned char  *active_map; /**< specify an on (1) or off (0) each 16x16 region within a frame */
    unsigned int    rows;       /**< number of rows */
    unsigned int    cols;       /**< number of cols */
} vpx_active_map_t;

/*!\brief  vpx image scaling mode
 *
 * This defines the data structure for image scaling mode
 *
 */
typedef struct vpx_scaling_mode
{
    VPX_SCALING_MODE    h_scaling_mode;  /**< horizontal scaling mode */
    VPX_SCALING_MODE    v_scaling_mode;  /**< vertical scaling mode   */
} vpx_scaling_mode_t;

/*!\brief VP8 encoding mode
 *
 * This defines VP8 encoding mode
 *
 */
typedef enum
{
    VP8_BEST_QUALITY_ENCODING,
    VP8_GOOD_QUALITY_ENCODING,
    VP8_REAL_TIME_ENCODING
} vp8e_encoding_mode;

/*!\brief VP8 token partition mode
 *
 * This defines VP8 partitioning mode for compressed data, i.e., the number of
 * sub-streams in the bitstream. Used for parallelized decoding.
 *
 */

typedef enum
{
    VP8_ONE_TOKENPARTITION   = 0,
    VP8_TWO_TOKENPARTITION   = 1,
    VP8_FOUR_TOKENPARTITION  = 2,
    VP8_EIGHT_TOKENPARTITION = 3,
} vp8e_token_partitions;


/*!\brief VP8 model tuning parameters
 *
 * Changes the encoder to tune for certain types of input material.
 *
 */
typedef enum
{
    VP8_TUNE_PSNR,
    VP8_TUNE_SSIM
} vp8e_tuning;

/*! @} - end defgroup vp8_encoder */

/*!\defgroup encoder Encoder Algorithm Interface
 * \ingroup codec
 * This abstraction allows applications using this encoder to easily support
 * multiple video formats with minimal code duplication. This section describes
 * the interface common to all encoders.
 * @{
 */
%{
#include <vpx/vpx_encoder.h>
%}

/*!\brief Current ABI version number
 *
 * \internal
 * If this file is altered in any way that changes the ABI, this value
 * must be bumped.  Examples include, but are not limited to, changing
 * types, removing or reassigning enums, adding/removing/rearranging
 * fields to structures
 */
%constant int VPX_ENCODER_ABI_VERSION = (2 + VPX_CODEC_ABI_VERSION);

/*! \brief Encoder capabilities bitfield
 *
 *  Each encoder advertises the capabilities it supports as part of its
 *  ::vpx_codec_iface_t interface structure. Capabilities are extra
 *  interfaces or functionality, and are not required to be supported
 *  by an encoder.
 *
 *  The available flags are specified by VPX_CODEC_CAP_* defines.
 */
%constant int VPX_CODEC_CAP_PSNR = 0x10000;             /**< Can issue PSNR packets */

/*! Can output one partition at a time. Each partition is returned in its
 *  own VPX_CODEC_CX_FRAME_PKT, with the FRAME_IS_FRAGMENT flag set for
 *  every partition but the last. In this mode all frames are always
 *  returned partition by partition.
 */
%constant int VPX_CODEC_CAP_OUTPUT_PARTITION = 0x20000;

/*! \brief Initialization-time Feature Enabling
 *
 *  Certain codec features must be known at initialization time, to allow
 *  for proper memory allocation.
 *
 *  The available flags are specified by VPX_CODEC_USE_* defines.
 */
%constant int VPX_CODEC_USE_PSNR = 0x10000;             /**< Calculate PSNR on each frame */
%constant int VPX_CODEC_USE_OUTPUT_PARTITION = 0x20000; /**< Make the encoder output one partition at a time. */

/*!\brief Generic fixed size buffer structure
 *
 * This structure is able to hold a reference to any fixed size buffer.
 */
typedef struct vpx_fixed_buf
{
    void          *buf; /**< Pointer to the data */
    size_t         sz;  /**< Length of the buffer, in chars */
} vpx_fixed_buf_t; /**< alias for struct vpx_fixed_buf */

/*!\brief Time Stamp Type
 *
 * An integer, which when multiplied by the stream's time base, provides
 * the absolute time of a sample.
 */
typedef int64_t vpx_codec_pts_t;

%typemap(in) vpx_codec_pts_t
{
    $1 = PyLong_AsLongLong($input);
}

/*!\brief Compressed Frame Flags
 *
 * This type represents a bitfield containing information about a compressed
 * frame that may be useful to an application. The most significant 16 bits
 * can be used by an algorithm to provide additional detail, for example to
 * support frame types that are codec specific (MPEG-1 D-frames for example)
 */
typedef uint32_t vpx_codec_frame_flags_t;
%constant int VPX_FRAME_IS_KEY       = 0x1; /**< frame is the start of a GOP */
%constant int VPX_FRAME_IS_DROPPABLE = 0x2; /**< frame can be dropped without affecting
                                                 the stream (no future frame depends on this one) */
%constant int VPX_FRAME_IS_INVISIBLE = 0x4; /**< frame should be decoded but will not be shown */
%constant int VPX_FRAME_IS_FRAGMENT  = 0x8; /**< this is a fragment of the encoded frame */

/*!\brief Error Resilient flags
 *
 * These flags define which error resilient features to enable in the
 * encoder. The flags are specified through the
 * vpx_codec_enc_cfg::g_error_resilient variable.
 */
typedef uint32_t vpx_codec_er_flags_t;
%constant int VPX_ERROR_RESILIENT_DEFAULT    = 0x1; /**< Improve resiliency against losses of whole frames */
%constant int VPX_ERROR_RESILIENT_PARTITIONS = 0x2; /**< The frame partitions are independently decodable by the
                                                          bool decoder, meaning that partitions can be decoded even
                                                          though earlier partitions have been lost. Note that intra
                                                          predicition is still done over the partition boundary. */


/*!\brief Encoder output packet variants
 *
 * This enumeration lists the different kinds of data packets that can be
 * returned by calls to vpx_codec_get_cx_data(). Algorithms \ref MAY
 * extend this list to provide additional functionality.
 */
enum vpx_codec_cx_pkt_kind
{
    VPX_CODEC_CX_FRAME_PKT,    /**< Compressed video frame */
    VPX_CODEC_STATS_PKT,       /**< Two-pass statistics for this frame */
    VPX_CODEC_PSNR_PKT,        /**< PSNR statistics for this frame */
    VPX_CODEC_CUSTOM_PKT = 256 /**< Algorithm extensions  */
};

/*!\brief Encoder output packet
 *
 * This structure contains the different kinds of output data the encoder
 * may produce while compressing a frame.
 */
typedef struct vpx_codec_cx_pkt
{
    enum vpx_codec_cx_pkt_kind  kind; /**< packet variant */
    union
    {
        struct
        {
            void                    *buf;      /**< compressed data buffer */
            size_t                   sz;       /**< length of compressed data */
            vpx_codec_pts_t          pts;      /**< time stamp to show frame
                                                (in timebase units) */
            unsigned long            duration; /**< duration to show frame
                                                (in timebase units) */
            vpx_codec_frame_flags_t  flags;    /**< flags for this frame */
            int                      partition_id; /**< the partition id
                                          defines the decoding order
                                          of the partitions. Only
                                          applicable when "output partition"
                                          mode is enabled. First partition
                                          has id 0.*/

        } frame;  /**< data for compressed frame packet */
        struct vpx_fixed_buf twopass_stats;  /**< data for two-pass packet */
        struct vpx_psnr_pkt
        {
            unsigned int samples[4];  /**< Number of samples, total/y/u/v */
            uint64_t     sse[4];      /**< sum squared error, total/y/u/v */
            double       psnr[4];     /**< PSNR, total/y/u/v */
        } psnr;                       /**< data for PSNR packet */
        struct vpx_fixed_buf raw;     /**< data for arbitrary packets */

        /* This packet size is fixed to allow codecs to extend this
         * interface without having to manage storage for raw packets,
         * i.e., if it's smaller than 128 bytes, you can store in the
         * packet list directly.
         */
        char pad[128 - sizeof(enum vpx_codec_cx_pkt_kind)]; /**< fixed sz */
    } data; /**< packet data */
} vpx_codec_cx_pkt_t; /**< alias for struct vpx_codec_cx_pkt */

%inline%{

PyObject* vpx_pkt_get_data(vpx_codec_cx_pkt_t *pkt)
{
    return PyBuffer_FromReadWriteMemory(pkt->data.frame.buf, pkt->data.frame.sz);
}

%}

/*!\brief Rational Number
 *
 * This structure holds a fractional value.
 */
typedef struct vpx_rational
{
    int num; /**< fraction numerator */
    int den; /**< fraction denominator */
} vpx_rational_t; /**< alias for struct vpx_rational */


/*!\brief Multi-pass Encoding Pass */
enum vpx_enc_pass
{
    VPX_RC_ONE_PASS,   /**< Single pass mode */
    VPX_RC_FIRST_PASS, /**< First pass of multi-pass mode */
    VPX_RC_LAST_PASS   /**< Final pass of multi-pass mode */
};


/*!\brief Rate control mode */
enum vpx_rc_mode
{
    VPX_VBR, /**< Variable Bit Rate (VBR) mode */
    VPX_CBR,  /**< Constant Bit Rate (CBR) mode */
    VPX_CQ   /**< Constant Quality  (CQ)  mode */
};

/*!\brief Keyframe placement mode.
 *
 * This enumeration determines whether keyframes are placed automatically by
 * the encoder or whether this behavior is disabled. Older releases of this
 * SDK were implemented such that VPX_KF_FIXED meant keyframes were disabled.
 * This name is confusing for this behavior, so the new symbols to be used
 * are VPX_KF_AUTO and VPX_KF_DISABLED.
 */
enum vpx_kf_mode
{
    VPX_KF_FIXED, /**< deprecated, implies VPX_KF_DISABLED */
    VPX_KF_AUTO,  /**< Encoder determines optimal placement automatically */
    VPX_KF_DISABLED = 0 /**< Encoder does not place keyframes. */
};

/*!\brief Encoded Frame Flags
 *
 * This type indicates a bitfield to be passed to vpx_codec_encode(), defining
 * per-frame boolean values. By convention, bits common to all codecs will be
 * named VPX_EFLAG_*, and bits specific to an algorithm will be named
 * /algo/_eflag_*. The lower order 16 bits are reserved for common use.
 */
typedef long vpx_enc_frame_flags_t;
%constant int VPX_EFLAG_FORCE_KF = (1<<0);  /**< Force this frame to be a keyframe */


/*!\brief Encoder configuration structure
 *
 * This structure contains the encoder settings that have common representations
 * across all codecs. This doesn't imply that all codecs support all features,
 * however.
 */
typedef struct vpx_codec_enc_cfg
{
    /*
     * generic settings (g)
     */

    /*!\brief Algorithm specific "usage" value
     *
     * Algorithms may define multiple values for usage, which may convey the
     * intent of how the application intends to use the stream. If this value
     * is non-zero, consult the documentation for the codec to determine its
     * meaning.
     */
    unsigned int           g_usage;


    /*!\brief Maximum number of threads to use
     *
     * For multi-threaded implementations, use no more than this number of
     * threads. The codec may use fewer threads than allowed. The value
     * 0 is equivalent to the value 1.
     */
    unsigned int           g_threads;


    /*!\brief Bitstream profile to use
     *
     * Some codecs support a notion of multiple bitstream profiles. Typically
     * this maps to a set of features that are turned on or off. Often the
     * profile to use is determined by the features of the intended decoder.
     * Consult the documentation for the codec to determine the valid values
     * for this parameter, or set to zero for a sane default.
     */
    unsigned int           g_profile;  /**< profile of bitstream to use */



    /*!\brief Width of the frame
     *
     * This value identifies the presentation resolution of the frame,
     * in pixels. Note that the frames passed as input to the encoder must
     * have this resolution. Frames will be presented by the decoder in this
     * resolution, independent of any spatial resampling the encoder may do.
     */
    unsigned int           g_w;


    /*!\brief Height of the frame
     *
     * This value identifies the presentation resolution of the frame,
     * in pixels. Note that the frames passed as input to the encoder must
     * have this resolution. Frames will be presented by the decoder in this
     * resolution, independent of any spatial resampling the encoder may do.
     */
    unsigned int           g_h;


    /*!\brief Stream timebase units
     *
     * Indicates the smallest interval of time, in seconds, used by the stream.
     * For fixed frame rate material, or variable frame rate material where
     * frames are timed at a multiple of a given clock (ex: video capture),
     * the \ref RECOMMENDED method is to set the timebase to the reciprocal
     * of the frame rate (ex: 1001/30000 for 29.970 Hz NTSC). This allows the
     * pts to correspond to the frame number, which can be handy. For
     * re-encoding video from containers with absolute time timestamps, the
     * \ref RECOMMENDED method is to set the timebase to that of the parent
     * container or multimedia framework (ex: 1/1000 for ms, as in FLV).
     */
    struct vpx_rational    g_timebase;


    /*!\brief Enable error resilient modes.
     *
     * The error resilient bitfield indicates to the encoder which features
     * it should enable to take measures for streaming over lossy or noisy
     * links.
     */
    vpx_codec_er_flags_t   g_error_resilient;


    /*!\brief Multi-pass Encoding Mode
     *
     * This value should be set to the current phase for multi-pass encoding.
     * For single pass, set to #VPX_RC_ONE_PASS.
     */
    enum vpx_enc_pass      g_pass;


    /*!\brief Allow lagged encoding
     *
     * If set, this value allows the encoder to consume a number of input
     * frames before producing output frames. This allows the encoder to
     * base decisions for the current frame on future frames. This does
     * increase the latency of the encoding pipeline, so it is not appropriate
     * in all situations (ex: realtime encoding).
     *
     * Note that this is a maximum value -- the encoder may produce frames
     * sooner than the given limit. Set this value to 0 to disable this
     * feature.
     */
    unsigned int           g_lag_in_frames;


    /*
     * rate control settings (rc)
     */

    /*!\brief Temporal resampling configuration, if supported by the codec.
     *
     * Temporal resampling allows the codec to "drop" frames as a strategy to
     * meet its target data rate. This can cause temporal discontinuities in
     * the encoded video, which may appear as stuttering during playback. This
     * trade-off is often acceptable, but for many applications is not. It can
     * be disabled in these cases.
     *
     * Note that not all codecs support this feature. All vpx VPx codecs do.
     * For other codecs, consult the documentation for that algorithm.
     *
     * This threshold is described as a percentage of the target data buffer.
     * When the data buffer falls below this percentage of fullness, a
     * dropped frame is indicated. Set the threshold to zero (0) to disable
     * this feature.
     */
    unsigned int           rc_dropframe_thresh;


    /*!\brief Enable/disable spatial resampling, if supported by the codec.
     *
     * Spatial resampling allows the codec to compress a lower resolution
     * version of the frame, which is then upscaled by the encoder to the
     * correct presentation resolution. This increases visual quality at
     * low data rates, at the expense of CPU time on the encoder/decoder.
     */
    unsigned int           rc_resize_allowed;


    /*!\brief Spatial resampling up watermark.
     *
     * This threshold is described as a percentage of the target data buffer.
     * When the data buffer rises above this percentage of fullness, the
     * encoder will step up to a higher resolution version of the frame.
     */
    unsigned int           rc_resize_up_thresh;


    /*!\brief Spatial resampling down watermark.
     *
     * This threshold is described as a percentage of the target data buffer.
     * When the data buffer falls below this percentage of fullness, the
     * encoder will step down to a lower resolution version of the frame.
     */
    unsigned int           rc_resize_down_thresh;


    /*!\brief Rate control algorithm to use.
     *
     * Indicates whether the end usage of this stream is to be streamed over
     * a bandwidth constrained link, indicating that Constant Bit Rate (CBR)
     * mode should be used, or whether it will be played back on a high
     * bandwidth link, as from a local disk, where higher variations in
     * bitrate are acceptable.
     */
    enum vpx_rc_mode       rc_end_usage;


    /*!\brief Two-pass stats buffer.
     *
     * A buffer containing all of the stats packets produced in the first
     * pass, concatenated.
     */
    struct vpx_fixed_buf   rc_twopass_stats_in;


    /*!\brief Target data rate
     *
     * Target bandwidth to use for this stream, in kilobits per second.
     */
    unsigned int           rc_target_bitrate;


    /*
     * quantizer settings
     */


    /*!\brief Minimum (Best Quality) Quantizer
     *
     * The quantizer is the most direct control over the quality of the
     * encoded image. The range of valid values for the quantizer is codec
     * specific. Consult the documentation for the codec to determine the
     * values to use. To determine the range programmatically, call
     * vpx_codec_enc_config_default() with a usage value of 0.
     */
    unsigned int           rc_min_quantizer;


    /*!\brief Maximum (Worst Quality) Quantizer
     *
     * The quantizer is the most direct control over the quality of the
     * encoded image. The range of valid values for the quantizer is codec
     * specific. Consult the documentation for the codec to determine the
     * values to use. To determine the range programmatically, call
     * vpx_codec_enc_config_default() with a usage value of 0.
     */
    unsigned int           rc_max_quantizer;


    /*
     * bitrate tolerance
     */


    /*!\brief Rate control adaptation undershoot control
     *
     * This value, expressed as a percentage of the target bitrate,
     * controls the maximum allowed adaptation speed of the codec.
     * This factor controls the maximum amount of bits that can
     * be subtracted from the target bitrate in order to compensate
     * for prior overshoot.
     *
     * Valid values in the range 0-1000.
     */
    unsigned int           rc_undershoot_pct;


    /*!\brief Rate control adaptation overshoot control
     *
     * This value, expressed as a percentage of the target bitrate,
     * controls the maximum allowed adaptation speed of the codec.
     * This factor controls the maximum amount of bits that can
     * be added to the target bitrate in order to compensate for
     * prior undershoot.
     *
     * Valid values in the range 0-1000.
     */
    unsigned int           rc_overshoot_pct;


    /*
     * decoder buffer model parameters
     */


    /*!\brief Decoder Buffer Size
     *
     * This value indicates the amount of data that may be buffered by the
     * decoding application. Note that this value is expressed in units of
     * time (milliseconds). For example, a value of 5000 indicates that the
     * client will buffer (at least) 5000ms worth of encoded data. Use the
     * target bitrate (#rc_target_bitrate) to convert to bits/bytes, if
     * necessary.
     */
    unsigned int           rc_buf_sz;


    /*!\brief Decoder Buffer Initial Size
     *
     * This value indicates the amount of data that will be buffered by the
     * decoding application prior to beginning playback. This value is
     * expressed in units of time (milliseconds). Use the target bitrate
     * (#rc_target_bitrate) to convert to bits/bytes, if necessary.
     */
    unsigned int           rc_buf_initial_sz;


    /*!\brief Decoder Buffer Optimal Size
     *
     * This value indicates the amount of data that the encoder should try
     * to maintain in the decoder's buffer. This value is expressed in units
     * of time (milliseconds). Use the target bitrate (#rc_target_bitrate)
     * to convert to bits/bytes, if necessary.
     */
    unsigned int           rc_buf_optimal_sz;


    /*
     * 2 pass rate control parameters
     */


    /*!\brief Two-pass mode CBR/VBR bias
     *
     * Bias, expressed on a scale of 0 to 100, for determining target size
     * for the current frame. The value 0 indicates the optimal CBR mode
     * value should be used. The value 100 indicates the optimal VBR mode
     * value should be used. Values in between indicate which way the
     * encoder should "lean."
     */
    unsigned int           rc_2pass_vbr_bias_pct;       /**< RC mode bias between CBR and VBR(0-100: 0->CBR, 100->VBR)   */


    /*!\brief Two-pass mode per-GOP minimum bitrate
     *
     * This value, expressed as a percentage of the target bitrate, indicates
     * the minimum bitrate to be used for a single GOP (aka "section")
     */
    unsigned int           rc_2pass_vbr_minsection_pct;


    /*!\brief Two-pass mode per-GOP maximum bitrate
     *
     * This value, expressed as a percentage of the target bitrate, indicates
     * the maximum bitrate to be used for a single GOP (aka "section")
     */
    unsigned int           rc_2pass_vbr_maxsection_pct;


    /*
     * keyframing settings (kf)
     */

    /*!\brief Keyframe placement mode
     *
     * This value indicates whether the encoder should place keyframes at a
     * fixed interval, or determine the optimal placement automatically
     * (as governed by the #kf_min_dist and #kf_max_dist parameters)
     */
    enum vpx_kf_mode       kf_mode;


    /*!\brief Keyframe minimum interval
     *
     * This value, expressed as a number of frames, prevents the encoder from
     * placing a keyframe nearer than kf_min_dist to the previous keyframe. At
     * least kf_min_dist frames non-keyframes will be coded before the next
     * keyframe. Set kf_min_dist equal to kf_max_dist for a fixed interval.
     */
    unsigned int           kf_min_dist;


    /*!\brief Keyframe maximum interval
     *
     * This value, expressed as a number of frames, forces the encoder to code
     * a keyframe if one has not been coded in the last kf_max_dist frames.
     * A value of 0 implies all frames will be keyframes. Set kf_min_dist
     * equal to kf_max_dist for a fixed interval.
     */
    unsigned int           kf_max_dist;

} vpx_codec_enc_cfg_t; /**< alias for struct vpx_codec_enc_cfg */

/*!\brief Initialize an encoder instance
 *
 * Initializes a encoder context using the given interface. Applications
 * should call the vpx_codec_enc_init convenience macro instead of this
 * function directly, to ensure that the ABI version number parameter
 * is properly initialized.
 *
 * In XMA mode (activated by setting VPX_CODEC_USE_XMA in the flags
 * parameter), the storage pointed to by the cfg parameter must be
 * kept readable and stable until all memory maps have been set.
 *
 * \param[in]    ctx     Pointer to this instance's context.
 * \param[in]    iface   Pointer to the algorithm interface to use.
 * \param[in]    cfg     Configuration to use, if known. May be NULL.
 * \param[in]    flags   Bitfield of VPX_CODEC_USE_* flags
 * \param[in]    ver     ABI version number. Must be set to
 *                       VPX_ENCODER_ABI_VERSION
 * \retval #VPX_CODEC_OK
 *     The decoder algorithm initialized.
 * \retval #VPX_CODEC_MEM_ERROR
 *     Memory allocation failed.
 */
%feature("docstring", "Initialize an encoder instance") vpx_codec_enc_init_ver;
vpx_codec_err_t vpx_codec_enc_init_ver(vpx_codec_ctx_t      *ctx,
                                       vpx_codec_iface_t    *iface,
                                       vpx_codec_enc_cfg_t  *cfg,
                                       vpx_codec_flags_t     flags,
                                       int                   ver);

/*!\brief Get a default configuration
 *
 * Initializes a encoder configuration structure with default values. Supports
 * the notion of "usages" so that an algorithm may offer different default
 * settings depending on the user's intended goal. This function \ref SHOULD
 * be called by all applications to initialize the configuration structure
 * before specializing the configuration with application specific values.
 *
 * \param[in]    iface   Pointer to the algorithm interface to use.
 * \param[out]   cfg     Configuration buffer to populate
 * \param[in]    usage   End usage. Set to 0 or use codec specific values.
 *
 * \retval #VPX_CODEC_OK
 *     The configuration was populated.
 * \retval #VPX_CODEC_INCAPABLE
 *     Interface is not an encoder interface.
 * \retval #VPX_CODEC_INVALID_PARAM
 *     A parameter was NULL, or the usage value was not recognized.
 */
%feature("docstring", "Initialize an encoder instance") vpx_codec_enc_config_default;
vpx_codec_err_t  vpx_codec_enc_config_default(vpx_codec_iface_t    *iface,
                                              vpx_codec_enc_cfg_t  *cfg,
                                              unsigned int          usage);

/*!\brief Set or change configuration
 *
 * Reconfigures an encoder instance according to the given configuration.
 *
 * \param[in]    ctx     Pointer to this instance's context
 * \param[in]    cfg     Configuration buffer to use
 *
 * \retval #VPX_CODEC_OK
 *     The configuration was populated.
 * \retval #VPX_CODEC_INCAPABLE
 *     Interface is not an encoder interface.
 * \retval #VPX_CODEC_INVALID_PARAM
 *     A parameter was NULL, or the usage value was not recognized.
 */
%feature("docstring", "Set or change configuration") vpx_codec_enc_config_set;
vpx_codec_err_t  vpx_codec_enc_config_set(vpx_codec_ctx_t            *ctx,
                                          const vpx_codec_enc_cfg_t  *cfg);

/*!\brief Get global stream headers
 *
 * Retrieves a stream level global header packet, if supported by the codec.
 *
 * \param[in]    ctx     Pointer to this instance's context
 *
 * \retval NULL
 *     Encoder does not support global header
 * \retval Non-NULL
 *     Pointer to buffer containing global header packet
 */
%feature("docstring", "Get global stream headers") vpx_codec_get_global_headers;
vpx_fixed_buf_t *vpx_codec_get_global_headers(vpx_codec_ctx_t   *ctx);


%constant int VPX_DL_REALTIME     = (1);        /**< deadline parameter analogous to VPx REALTIME mode. */
%constant int VPX_DL_GOOD_QUALITY = (1000000);  /**< deadline parameter analogous to VPx GOOD QUALITY mode. */
%constant int VPX_DL_BEST_QUALITY = (0);        /**< deadline parameter analogous to VPx BEST QUALITY mode. */

/*!\brief Encode a frame
 *
 * Encodes a video frame at the given "presentation time." The presentation
 * time stamp (PTS) \ref MUST be strictly increasing.
 *
 * The encoder supports the notion of a soft real-time deadline. Given a
 * non-zero value to the deadline parameter, the encoder will make a "best
 * effort" guarantee to  return before the given time slice expires. It is
 * implicit that limiting the available time to encode will degrade the
 * output quality. The encoder can be given an unlimited time to produce the
 * best possible frame by specifying a deadline of '0'. This deadline
 * supercedes the VPx notion of "best quality, good quality, realtime".
 * Applications that wish to map these former settings to the new deadline
 * based system can use the symbols #VPX_DL_REALTIME, #VPX_DL_GOOD_QUALITY,
 * and #VPX_DL_BEST_QUALITY.
 *
 * When the last frame has been passed to the encoder, this function should
 * continue to be called, with the img parameter set to NULL. This will
 * signal the end-of-stream condition to the encoder and allow it to encode
 * any held buffers. Encoding is complete when vpx_codec_encode() is called
 * and vpx_codec_get_cx_data() returns no data.
 *
 * \param[in]    ctx       Pointer to this instance's context
 * \param[in]    img       Image data to encode, NULL to flush.
 * \param[in]    pts       Presentation time stamp, in timebase units.
 * \param[in]    duration  Duration to show frame, in timebase units.
 * \param[in]    flags     Flags to use for encoding this frame.
 * \param[in]    deadline  Time to spend encoding, in microseconds. (0=infinite)
 *
 * \retval #VPX_CODEC_OK
 *     The configuration was populated.
 * \retval #VPX_CODEC_INCAPABLE
 *     Interface is not an encoder interface.
 * \retval #VPX_CODEC_INVALID_PARAM
 *     A parameter was NULL, the image format is unsupported, etc.
 */
%feature("docstring", "Encode a frame") vpx_codec_encode;
vpx_codec_err_t  vpx_codec_encode(vpx_codec_ctx_t            *ctx,
                                  const vpx_image_t          *img,
                                  vpx_codec_pts_t             pts,
                                  unsigned long               duration,
                                  vpx_enc_frame_flags_t       flags,
                                  unsigned long               deadline);

/*!\brief Set compressed data output buffer
 *
 * Sets the buffer that the codec should output the compressed data
 * into. This call effectively sets the buffer pointer returned in the
 * next VPX_CODEC_CX_FRAME_PKT packet. Subsequent packets will be
 * appended into this buffer. The buffer is preserved across frames,
 * so applications must periodically call this function after flushing
 * the accumulated compressed data to disk or to the network to reset
 * the pointer to the buffer's head.
 *
 * `pad_before` bytes will be skipped before writing the compressed
 * data, and `pad_after` bytes will be appended to the packet. The size
 * of the packet will be the sum of the size of the actual compressed
 * data, pad_before, and pad_after. The padding bytes will be preserved
 * (not overwritten).
 *
 * Note that calling this function does not guarantee that the returned
 * compressed data will be placed into the specified buffer. In the
 * event that the encoded data will not fit into the buffer provided,
 * the returned packet \ref MAY point to an internal buffer, as it would
 * if this call were never used. In this event, the output packet will
 * NOT have any padding, and the application must free space and copy it
 * to the proper place. This is of particular note in configurations
 * that may output multiple packets for a single encoded frame (e.g., lagged
 * encoding) or if the application does not reset the buffer periodically.
 *
 * Applications may restore the default behavior of the codec providing
 * the compressed data buffer by calling this function with a NULL
 * buffer.
 *
 * Applications \ref MUSTNOT call this function during iteration of
 * vpx_codec_get_cx_data().
 *
 * \param[in]    ctx         Pointer to this instance's context
 * \param[in]    buf         Buffer to store compressed data into
 * \param[in]    pad_before  Bytes to skip before writing compressed data
 * \param[in]    pad_after   Bytes to skip after writing compressed data
 *
 * \retval #VPX_CODEC_OK
 *     The buffer was set successfully.
 * \retval #VPX_CODEC_INVALID_PARAM
 *     A parameter was NULL, the image format is unsupported, etc.
 */
%feature("docstring", "Set compressed data output buffer") vpx_codec_set_cx_data_buf;
vpx_codec_err_t vpx_codec_set_cx_data_buf(vpx_codec_ctx_t       *ctx,
                                          const vpx_fixed_buf_t *buf,
                                          unsigned int           pad_before,
                                          unsigned int           pad_after);

/*!\brief Encoded data iterator
 *
 * Iterates over a list of data packets to be passed from the encoder to the
 * application. The different kinds of packets available are enumerated in
 * #vpx_codec_cx_pkt_kind.
 *
 * #VPX_CODEC_CX_FRAME_PKT packets should be passed to the application's
 * muxer. Multiple compressed frames may be in the list.
 * #VPX_CODEC_STATS_PKT packets should be appended to a global buffer.
 *
 * The application \ref MUST silently ignore any packet kinds that it does
 * not recognize or support.
 *
 * The data buffers returned from this function are only guaranteed to be
 * valid until the application makes another call to any vpx_codec_* function.
 *
 * \param[in]     ctx      Pointer to this instance's context
 * \param[in,out] iter     Iterator storage, initialized to NULL
 *
 * \return Returns a pointer to an output data packet (compressed frame data,
 *         two-pass statistics, etc.) or NULL to signal end-of-list.
 *
 */
%feature("docstring", "Encoded data iterator") vpx_codec_get_cx_data;
const vpx_codec_cx_pkt_t *vpx_codec_get_cx_data(vpx_codec_ctx_t   *ctx,
                                                vpx_codec_iter_t  *iter);

/*!\brief Get Preview Frame
 *
 * Returns an image that can be used as a preview. Shows the image as it would
 * exist at the decompressor. The application \ref MUST NOT write into this
 * image buffer.
 *
 * \param[in]     ctx      Pointer to this instance's context
 *
 * \return Returns a pointer to a preview image, or NULL if no image is
 *         available.
 *
 */
%feature("docstring", "Get Preview Frame") vpx_codec_get_preview_frame;
const vpx_image_t *vpx_codec_get_preview_frame(vpx_codec_ctx_t   *ctx);

/*!@} - end defgroup encoder*/


/*!\defgroup vp8_decoder WebM VP8 Decoder
 * \ingroup vp8
 *
 * @{
 */
/*!\file
 * \brief Provides definitions for using the VP8 algorithm within the vpx Decoder
 *        interface.
 */
%{
#include <vpx/vp8dx.h>
%}

/*!\name Algorithm interface for VP8
 *
 * This interface provides the capability to decode raw VP8 streams, as would
 * be found in AVI files and other non-Flash uses.
 * @{
 */
vpx_codec_iface_t* vpx_codec_vp8_dx(void);
/*!@} - end algorithm interface member group*/

/*!\brief VP8 decoder control functions
 *
 * This set of macros define the control functions available for the VP8
 * decoder interface.
 *
 * \sa #vpx_codec_control
 */
enum vp8_dec_control_id
{
    /** control function to get info on which reference frames were updated
     *  by the last decode
     */
    VP8D_GET_LAST_REF_UPDATES = VP8_DECODER_CTRL_ID_START,

    /** check if the indicated frame is corrupted */
    VP8D_GET_FRAME_CORRUPTED,

    VP8_DECODER_CTRL_ID_MAX
} ;


/*!\file
 * \brief Describes the decoder algorithm interface to applications.
 *
 * This file describes the interface between an application and a
 * video decoder algorithm.
 *
 */
%{
#include <vpx/vpx_decoder.h>
%}
/*!\brief Current ABI version number
 *
 * \internal
 * If this file is altered in any way that changes the ABI, this value
 * must be bumped.  Examples include, but are not limited to, changing
 * types, removing or reassigning enums, adding/removing/rearranging
 * fields to structures
 */
%constant int VPX_DECODER_ABI_VERSION = (2 + VPX_CODEC_ABI_VERSION); /**<\hideinitializer*/

/*! \brief Decoder capabilities bitfield
 *
 *  Each decoder advertises the capabilities it supports as part of its
 *  ::vpx_codec_iface_t interface structure. Capabilities are extra interfaces
 *  or functionality, and are not required to be supported by a decoder.
 *
 *  The available flags are specified by VPX_CODEC_CAP_* defines.
 */
%constant int VPX_CODEC_CAP_PUT_SLICE           = 0x10000; /**< Will issue put_slice callbacks */
%constant int VPX_CODEC_CAP_PUT_FRAME           = 0x20000; /**< Will issue put_frame callbacks */
%constant int VPX_CODEC_CAP_POSTPROC            = 0x40000; /**< Can postprocess decoded frame */
%constant int VPX_CODEC_CAP_ERROR_CONCEALMENT   = 0x80000; /**< Can conceal errors due to packet loss */
%constant int VPX_CODEC_CAP_INPUT_PARTITION     = 0x100000; /**< Can receive encoded frames one partition at a time */

/*! \brief Initialization-time Feature Enabling
 *
 *  Certain codec features must be known at initialization time, to allow for
 *  proper memory allocation.
 *
 *  The available flags are specified by VPX_CODEC_USE_* defines.
 */
%constant int VPX_CODEC_USE_POSTPROC            = 0x10000; /**< Postprocess decoded frame */
%constant int VPX_CODEC_USE_ERROR_CONCEALMENT   = 0x20000; /**< Conceal errors in decoded frames */
%constant int VPX_CODEC_USE_INPUT_PARTITION     = 0x40000; /**< The input frame should be passed
                                                                to the decoder one partition at a time */

/*!\brief Stream properties
 *
 * This structure is used to query or set properties of the decoded
 * stream. Algorithms may extend this structure with data specific
 * to their bitstream by setting the sz member appropriately.
 */
typedef struct vpx_codec_stream_info
{
    unsigned int sz;     /**< Size of this structure */
    unsigned int w;      /**< Width (or 0 for unknown/default) */
    unsigned int h;      /**< Height (or 0 for unknown/default) */
    unsigned int is_kf;  /**< Current frame is a keyframe */
} vpx_codec_stream_info_t;

%inline%{

vpx_codec_stream_info_t vpx_codec_stream_info_alloc()
{
    vpx_codec_stream_info_t info;

    memset(&info, 0, sizeof(info));

    info.sz = sizeof(info);

    return info;
}

%}

/* REQUIRED FUNCTIONS
 *
 * The following functions are required to be implemented for all decoders.
 * They represent the base case functionality expected of all decoders.
 */


/*!\brief Initialization Configurations
 *
 * This structure is used to pass init time configuration options to the
 * decoder.
 */
typedef struct vpx_codec_dec_cfg
{
    unsigned int threads; /**< Maximum number of threads to use, default 1 */
    unsigned int w;      /**< Width */
    unsigned int h;      /**< Height */
} vpx_codec_dec_cfg_t; /**< alias for struct vpx_codec_dec_cfg */


/*!\brief Initialize a decoder instance
 *
 * Initializes a decoder context using the given interface. Applications
 * should call the vpx_codec_dec_init convenience macro instead of this
 * function directly, to ensure that the ABI version number parameter
 * is properly initialized.
 *
 * In XMA mode (activated by setting VPX_CODEC_USE_XMA in the flags
 * parameter), the storage pointed to by the cfg parameter must be
 * kept readable and stable until all memory maps have been set.
 *
 * \param[in]    ctx     Pointer to this instance's context.
 * \param[in]    iface   Pointer to the algorithm interface to use.
 * \param[in]    cfg     Configuration to use, if known. May be NULL.
 * \param[in]    flags   Bitfield of VPX_CODEC_USE_* flags
 * \param[in]    ver     ABI version number. Must be set to
 *                       VPX_DECODER_ABI_VERSION
 * \retval #VPX_CODEC_OK
 *     The decoder algorithm initialized.
 * \retval #VPX_CODEC_MEM_ERROR
 *     Memory allocation failed.
 */
%feature("docstring", "Initialize a decoder instance") vpx_codec_dec_init_ver;
vpx_codec_err_t vpx_codec_dec_init_ver(vpx_codec_ctx_t      *ctx,
                                       vpx_codec_iface_t    *iface,
                                       vpx_codec_dec_cfg_t  *cfg,
                                       vpx_codec_flags_t     flags,
                                       int                   ver);


%typemap(in) (const uint8_t *data, unsigned int data_sz)
{
    if (PyBuffer_Check($input))
    {
        void *buf;
        int len;

        if (-1 == PyObject_AsReadBuffer($input, &buf, &len))
        {
            PyErr_SetString(PyExc_ValueError,"Expected a readable buffer");
            return NULL;
        }

        $1 = (const uint8_t *) buf;
        $2 = len;
    }
    else if (PyString_Check($input))
    {
       $1 = (const uint8_t *) PyString_AsString($input);
       $2 = PyString_Size($input);
    }
    else
    {
        PyErr_SetString(PyExc_ValueError,"Expected a string or a readable buffer");
        return NULL;
    }
}

/*!\brief Parse stream info from a buffer
 *
 * Performs high level parsing of the bitstream. Construction of a decoder
 * context is not necessary. Can be used to determine if the bitstream is
 * of the proper format, and to extract information from the stream.
 *
 * \param[in]      iface   Pointer to the algorithm interface
 * \param[in]      data    Pointer to a block of data to parse
 * \param[in]      data_sz Size of the data buffer
 * \param[in,out]  si      Pointer to stream info to update. The size member
 *                         \ref MUST be properly initialized, but \ref MAY be
 *                         clobbered by the algorithm. This parameter \ref MAY
 *                         be NULL.
 *
 * \retval #VPX_CODEC_OK
 *     Bitstream is parsable and stream information updated
 */
%feature("docstring", "Parse stream info from a buffer") vpx_codec_peek_stream_info;
vpx_codec_err_t vpx_codec_peek_stream_info(vpx_codec_iface_t       *iface,
                                           const uint8_t           *data,
                                           unsigned int             data_sz,
                                           vpx_codec_stream_info_t *si);


/*!\brief Return information about the current stream.
 *
 * Returns information about the stream that has been parsed during decoding.
 *
 * \param[in]      ctx     Pointer to this instance's context
 * \param[in,out]  si      Pointer to stream info to update. The size member
 *                         \ref MUST be properly initialized, but \ref MAY be
 *                         clobbered by the algorithm. This parameter \ref MAY
 *                         be NULL.
 *
 * \retval #VPX_CODEC_OK
 *     Bitstream is parsable and stream information updated
 */
%feature("docstring", "Return information about the current stream.") vpx_codec_get_stream_info;
vpx_codec_err_t vpx_codec_get_stream_info(vpx_codec_ctx_t         *ctx,
                                          vpx_codec_stream_info_t *si);

/*!\brief Decode data
 *
 * Processes a buffer of coded data. If the processing results in a new
 * decoded frame becoming available, PUT_SLICE and PUT_FRAME events may be
 * generated, as appropriate. Encoded data \ref MUST be passed in DTS (decode
 * time stamp) order. Frames produced will always be in PTS (presentation
 * time stamp) order.
 * If the decoder is configured with VPX_CODEC_USE_INPUT_PARTITION enabled,
 * data and data_sz must contain at most one encoded partition. When no more
 * data is available, this function should be called with NULL as data and 0
 * as data_sz. The memory passed to this function must be available until
 * the frame has been decoded.
 *
 * \param[in] ctx          Pointer to this instance's context
 * \param[in] data         Pointer to this block of new coded data. If
 *                         NULL, a VPX_CODEC_CB_PUT_FRAME event is posted
 *                         for the previously decoded frame.
 * \param[in] data_sz      Size of the coded data, in bytes.
 * \param[in] user_priv    Application specific data to associate with
 *                         this frame.
 * \param[in] deadline     Soft deadline the decoder should attempt to meet,
 *                         in us. Set to zero for unlimited.
 *
 * \return Returns #VPX_CODEC_OK if the coded data was processed completely
 *         and future pictures can be decoded without error. Otherwise,
 *         see the descriptions of the other error codes in ::vpx_codec_err_t
 *         for recoverability capabilities.
 */
%feature("docstring", "Decode data") vpx_codec_decode;
vpx_codec_err_t vpx_codec_decode(vpx_codec_ctx_t    *ctx,
                                 const uint8_t      *data,
                                 unsigned int       data_sz,
                                 void               *user_priv,
                                 long                deadline);

/*!\brief Decoded frames iterator
 *
 * Iterates over a list of the frames available for display. The iterator
 * storage should be initialized to NULL to start the iteration. Iteration is
 * complete when this function returns NULL.
 *
 * The list of available frames becomes valid upon completion of the
 * vpx_codec_decode call, and remains valid until the next call to vpx_codec_decode.
 *
 * \param[in]     ctx      Pointer to this instance's context
 * \param[in,out] iter     Iterator storage, initialized to NULL
 *
 * \return Returns a pointer to an image, if one is ready for display. Frames
 *         produced will always be in PTS (presentation time stamp) order.
 */
%feature("docstring", "Decoded frames iterator") vpx_codec_get_frame;
vpx_image_t *vpx_codec_get_frame(vpx_codec_ctx_t  *ctx,
                                 vpx_codec_iter_t *iter);


/*!\defgroup cap_put_frame Frame-Based Decoding Functions
 *
 * The following functions are required to be implemented for all decoders
 * that advertise the VPX_CODEC_CAP_PUT_FRAME capability. Calling these functions
 * for codecs that don't advertise this capability will result in an error
 * code being returned, usually VPX_CODEC_ERROR
 * @{
 */

/*!\brief put frame callback prototype
 *
 * This callback is invoked by the decoder to notify the application of
 * the availability of decoded image data.
 */
typedef void (*vpx_codec_put_frame_cb_fn_t)(void        *user_priv,
                                            const vpx_image_t *img);


/*!\brief Register for notification of frame completion.
 *
 * Registers a given function to be called when a decoded frame is
 * available.
 *
 * \param[in] ctx          Pointer to this instance's context
 * \param[in] cb           Pointer to the callback function
 * \param[in] user_priv    User's private data
 *
 * \retval #VPX_CODEC_OK
 *     Callback successfully registered.
 * \retval #VPX_CODEC_ERROR
 *     Decoder context not initialized, or algorithm not capable of
 *     posting slice completion.
 */
%feature("docstring", "Register for notification of frame completion.") vpx_codec_register_put_frame_cb;
vpx_codec_err_t vpx_codec_register_put_frame_cb(vpx_codec_ctx_t             *ctx,
                                                vpx_codec_put_frame_cb_fn_t  cb,
                                                void                        *user_priv);

/*!@} - end defgroup cap_put_frame */

/*!\defgroup cap_put_slice Slice-Based Decoding Functions
 *
 * The following functions are required to be implemented for all decoders
 * that advertise the VPX_CODEC_CAP_PUT_SLICE capability. Calling these functions
 * for codecs that don't advertise this capability will result in an error
 * code being returned, usually VPX_CODEC_ERROR
 * @{
 */

/*!\brief put slice callback prototype
 *
 * This callback is invoked by the decoder to notify the application of
 * the availability of partially decoded image data. The
 */
typedef void (*vpx_codec_put_slice_cb_fn_t)(void         *user_priv,
                                            const vpx_image_t      *img,
                                            const vpx_image_rect_t *valid,
                                            const vpx_image_rect_t *update);


/*!\brief Register for notification of slice completion.
 *
 * Registers a given function to be called when a decoded slice is
 * available.
 *
 * \param[in] ctx          Pointer to this instance's context
 * \param[in] cb           Pointer to the callback function
 * \param[in] user_priv    User's private data
 *
 * \retval #VPX_CODEC_OK
 *     Callback successfully registered.
 * \retval #VPX_CODEC_ERROR
 *     Decoder context not initialized, or algorithm not capable of
 *     posting slice completion.
 */
%feature("docstring", "Register for notification of slice completion.") vpx_codec_register_put_slice_cb;
vpx_codec_err_t vpx_codec_register_put_slice_cb(vpx_codec_ctx_t             *ctx,
                                                vpx_codec_put_slice_cb_fn_t  cb,
                                                void                        *user_priv);

%inline%{

void vpx_codec_put_frame_callback(void *user_priv, const vpx_image_t *img)
{
    PyObject *image = SWIG_NewPointerObj(SWIG_as_voidptr(img), SWIGTYPE_p_vpx_image, 0);
    PyObject *args = PyTuple_Pack(1, image);

    PyObject_Call((PyObject *) user_priv, args, NULL);
}

vpx_codec_err_t vpx_codec_register_frame_callback(vpx_codec_ctx_t *ctx, PyObject *callback)
{
    if (!PyCallable_Check(callback))
    {
        PyErr_SetString(PyExc_ValueError,"Expected a function/method or a callable object");
        return VPX_CODEC_INVALID_PARAM;
    }

    Py_INCREF(callback);

    return vpx_codec_register_put_frame_cb(ctx, vpx_codec_put_frame_callback, callback);
}

void vpx_codec_put_slice_callback(void *user_priv, const vpx_image_t *img,
                                  const vpx_image_rect_t *valid, const vpx_image_rect_t *update)
{
    PyObject *image = SWIG_NewPointerObj(SWIG_as_voidptr(img), SWIGTYPE_p_vpx_image, 0);
    PyObject *valid_rect = SWIG_NewPointerObj(SWIG_as_voidptr(valid), SWIGTYPE_p_vpx_image_rect, 0),
             *update_rect = SWIG_NewPointerObj(SWIG_as_voidptr(valid), SWIGTYPE_p_vpx_image_rect, 0);

    PyObject *args = PyTuple_Pack(3, image, valid, update);

    PyObject_Call((PyObject *) user_priv, args, NULL);
}

vpx_codec_err_t vpx_codec_register_slice_callback(vpx_codec_ctx_t *ctx, PyObject *callback)
{
    if (!PyCallable_Check(callback))
    {
        PyErr_SetString(PyExc_ValueError,"Expected a function/method or a callable object");
        return VPX_CODEC_INVALID_PARAM;
    }

    Py_INCREF(callback);

    return vpx_codec_register_put_slice_cb(ctx, vpx_codec_put_slice_callback, callback);
}

%}

/*!@} - end defgroup cap_put_slice*/

/*!@} - end defgroup decoder*/
