import sys
from pyopencv import *

from vpx import *
from pyvpx import *

__author__ = 'Flier Lu'

if __name__ == '__main__':
    namedWindow('Camera', CV_WINDOW_AUTOSIZE)
    moveWindow('Camera', 10, 10)

    capture = VideoCapture(0)

    # check that capture device is OK
    if not capture.isOpened():
        print("Error opening capture device")
        sys.exit (1)

    # create a Mat instance
    frame = Mat()

    # capture the 1st frame to get some propertie on it
    capture >> frame

    # get size of the frame
    frame_size = frame.size()

    pts = 0

    with Encoder(frame_size.width, frame_size.height) as encoder:
        with Decoder() as decoder:
            try:
                while True:
                    # do forever

                    # 1. capture the current image
                    capture >> frame

                    if frame.empty():
                        # no image captured... end the processing
                        break

                    src = Image(frame_size.width, frame_size.height, VPX_IMG_FMT_RGB24, data=frame.data)

                    for kind, packet in encoder.encode(src.convertTo(VPX_IMG_FMT_I420), pts):
                        #print "encoded packet %d bytes" % len(packet)

                        for img in decoder.decode(packet):
                            img.convertTo(src)

                            # display the frames to have a visual output
                            imshow('Camera', frame)

                    # handle events
                    key = waitKey (5) & 255
                    if key == 27:
                        # user has press the ESC key, so exit
                        break
                    elif key == ord('p'):
                        print "take a preview"
                        src.asPilImage().save("preview.png")
                    elif key != 255:
                        print "unknown shotkey - ", key
                        
            except KeyboardInterrupt:
                pass