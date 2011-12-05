import vpx

__author__ = 'Flier Lu'

class VpxError(Exception):
    def __init__(self, errno):
        Exception.__init__(self, vpx.vpx_codec_err_to_string(errno))
        self.errno = errno

    @staticmethod
    def check(errno):
        if errno != vpx.VPX_CODEC_OK:
            raise VpxError(errno)

class Codec(object):
    def __init__(self, iface):
        self.iface = iface

    @property
    def name(self):
        "Return the name for a given interface"
        return vpx.vpx_codec_iface_name(self.iface)

    @property
    def caps(self):
        "Get the capabilities of an algorithm."
        return vpx.vpx_codec_get_caps(self.iface)

    @staticmethod
    def version():
        v = vpx.vpx_codec_version()
        return (((v>>16)&0xff), ((v>>8)&0xff), ((v>>0)&0xff),
                vpx.vpx_codec_version_str(),
                vpx.vpx_codec_version_extra_str(),
                vpx.vpx_codec_build_config())



class Encoder(object):
    Interface = Codec(vpx.vpx_codec_vp8_cx())

    def __init__(self, width, height, codec=None):
        self.codec = vpx.vpx_codec_ctx_t()
        self.cfg = vpx.vpx_codec_enc_cfg_t()

        VpxError.check(vpx.vpx_codec_enc_config_default(vpx.vpx_codec_vp8_cx(), self.cfg, 0))

        self.cfg.rc_target_bitrate = width * height * self.cfg.rc_target_bitrate / self.cfg.g_w / self.cfg.g_h
        self.cfg.g_w = width
        self.cfg.g_h = height

        VpxError.check(vpx.vpx_codec_enc_init(self.codec, vpx.vpx_codec_vp8_cx(), self.cfg, 0))

    @property
    def width(self):
        return self.cfg.g_w

    @property
    def height(self):
        return self.cfg.g_h