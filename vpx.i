%module vpx

%{
#include <vpx/vpx_image.h>

#include <vpx/vpx_encoder.h>
#include <vpx/vp8cx.h>

#include <vpx/vpx_decoder.h>
#include <vpx/vp8dx.h>
%}

extern
vpx_codec_err_t vpx_codec_enc_init_ver(vpx_codec_ctx_t      *ctx,
                                       vpx_codec_iface_t    *iface,
                                       vpx_codec_enc_cfg_t  *cfg,
                                       vpx_codec_flags_t     flags,
                                       int                   ver);
                                       