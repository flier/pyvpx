from pyvpx import *
import unittest

__author__ = 'Flier Lu'

class TestImage(unittest.TestCase):
    def testAlloc(self):
        img = Image(320, 200)

        self.assertEquals(320, img.width)
        self.assertEquals(200, img.height)
        self.assertEquals(vpx.VPX_IMG_FMT_I420, img.format)
        self.assertEquals(12, img.bps)
        self.assertEquals(96000, len(img.data))

    def testConvert(self):
        src = Image(320, 200, vpx.VPX_IMG_FMT_I420)
        src.clear()

        img = src.convertTo(vpx.VPX_IMG_FMT_RGB24)

        self.assert_(img)
        self.assertEquals(vpx.VPX_IMG_FMT_RGB24, img.format)
        self.assertEquals(320, img.width)
        self.assertEquals(200, img.height)

        img = img.convertTo(vpx.VPX_IMG_FMT_I420)
        self.assertEquals(vpx.VPX_IMG_FMT_I420, img.format)
        self.assertEquals(320, img.width)
        self.assertEquals(200, img.height)

class TestCodec(unittest.TestCase):
    def testVersion(self):
        major, minor, patch, version, extra, build_config = Codec.version()

        self.assertEquals(version, "v%d.%d.%d-%s" % (major, minor, patch, extra))
        self.assert_(build_config)

    def testInterface(self):
        self.assert_(Encoder.Interface.name.startswith('WebM Project VP8 Encoder'))
        self.assertEquals(vpx.VPX_CODEC_CAP_ENCODER, Encoder.Interface.caps & vpx.VPX_CODEC_CAP_ENCODER)

        self.assertEquals(vpx.VPX_CODEC_CAP_DECODER, Decoder.Interface.caps & vpx.VPX_CODEC_CAP_DECODER)
        self.assert_(Decoder.Interface.name.startswith('WebM Project VP8 Decoder'))

    def testException(self):
        err = VpxError(vpx.VPX_CODEC_OK)

        self.assertEquals(vpx.VPX_CODEC_OK, err.errno)
        self.assertEquals("Success", str(err))

class TestEncoder(unittest.TestCase):
    def testEncode(self):
        with Encoder(320, 240) as encoder:
            with Image(320, 240) as img:
                img.clear()

                packets = encoder.encode(img, 1, flags=vpx.VPX_EFLAG_FORCE_KF)

            self.assert_(packets)

            kind, data = packets.next()

            self.assertEquals(vpx.VPX_CODEC_CX_FRAME_PKT, kind)
            self.assert_(len(data) > 0)

            self.assertRaises(StopIteration, packets.next)

class TestDecode(unittest.TestCase):
    def testDecode(self):
        with Encoder(320, 240) as encoder:
            with Image(320, 240) as img:
                img.clear()

                frames = encoder.encode(img, 1)

                kind, data = frames.next()

                info = Decoder.peek_stream_info(data)

            self.assert_(info)
            self.assertEquals(320, info.w)
            self.assertEquals(240, info.h)
            self.assertEquals(1, info.is_kf)

            with Decoder() as decoder:
                frames = decoder.decode(data)

                self.assert_(frames)

                img = frames.next()

                self.assert_(img)
                self.assertEquals(320, img.width)
                self.assertEquals(240, img.height)
                self.assertEquals(384, img.stored_width)
                self.assertEquals(304, img.stored_height)
                self.assertEquals(vpx.VPX_IMG_FMT_I420, img.format)

                self.assertRaises(StopIteration, frames.next)

                info = decoder.get_stream_info()

                self.assert_(info)
                self.assertEquals(320, info.w)
                self.assertEquals(240, info.h)
                self.assertEquals(1, info.is_kf)

                frame_called = False
                slice_called = False

                if decoder.Interface.caps & vpx.VPX_CODEC_CAP_PUT_FRAME:
                    def on_frame(img):
                        frame_called = True

                    decoder.register_frame_callback(on_frame)

                    def on_slice(img, valid, update):
                        slice_called = True

                    decoder.register_slice_callback(on_slice)

                    decoder.decode(data)

                    self.assert_(frame_called)
                    self.assert_(slice_called)

if __name__ == '__main__':
    unittest.main()