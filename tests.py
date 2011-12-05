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

class TestCodec(unittest.TestCase):
    def testVersion(self):
        major, minor, patch, version, extra, build_config = Codec.version()

        self.assertEquals(version, "v%d.%d.%d-%s" % (major, minor, patch, extra))
        self.assert_(build_config)

    def testInterface(self):
        self.assert_(Encoder.Interface.name.startswith('WebM Project VP8 Encoder'))
        self.assertEquals(vpx.VPX_CODEC_CAP_ENCODER, Encoder.Interface.caps & vpx.VPX_CODEC_CAP_ENCODER)

    def testException(self):
        err = VpxError(vpx.VPX_CODEC_OK)

        self.assertEquals(vpx.VPX_CODEC_OK, err.errno)
        self.assertEquals("Success", str(err))

class TestEncoder(unittest.TestCase):
    def testEncode(self):
        with Encoder(320, 240) as encoder:
            with Image(320, 240) as img:
                img.clear()

                frames = encoder.encode(img, 1)

            self.assert_(frames)

            kind, data = frames.next()

            self.assertEquals(vpx.VPX_CODEC_CX_FRAME_PKT, kind)
            self.assert_(len(data) > 0)

            self.assertRaises(StopIteration, frames.next)

class TestDecode(unittest.TestCase):
    def testDecode(self):
        pass

if __name__ == '__main__':
    unittest.main()