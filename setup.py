# http://peak.telecommunity.com/DevCenter/setuptools#using-setuptools-without-bundling-it
import ez_setup
ez_setup.use_setuptools()

import sys, os, os.path

from setuptools import setup, find_packages, Extension

__author__ = 'Flier Lu'

is_win = os.name == 'nt' and sys.platform == 'win32'

VPX_HOME = os.environ['VPX_HOME']
vpx_inc_path = os.path.join(VPX_HOME, 'include')
vpx_lib_path = os.path.join(VPX_HOME, 'lib', 'Win32') if is_win else ''
vpx_lib = 'vpxmt' if is_win else 'vpx'

vpx = Extension(name = '_vpx',
                sources = ['vpx.i'],
                include_dirs = [vpx_inc_path],
                library_dirs = [vpx_lib_path],
                libraries = [vpx_lib],
                language = 'c++')

setup(name = 'pyvpx',
      version = '0.1',
      description = 'Python Binding of WebM VP8 Codec',
      long_description = open('README').read(),
      author = __author__,
      author_email = 'flier.lu@gmail.com',
      url = 'https://github.com/flier/pyvpx',
      download_url = 'https://github.com/flier/pyvpx/downloads',
      packages = find_packages(),
      ext_modules = [vpx],
      py_modules = ['vpx', 'ez_setup'],
      test_suite = "tests",
      license = 'BSD',
      keywords = 'VPX video codec encoder decoder',
      classifiers = [
        'Development Status :: 3 - Alpha',
        'Intended Audience :: Developers',
        'License :: OSI Approved :: BSD License',
        'Operating System :: OS Independent',
        'Programming Language :: C',
        'Programming Language :: Python',
        'Topic :: Multimedia :: Video',
        'Topic :: Software Development :: Libraries :: Python Modules',
      ],)