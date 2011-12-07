# http://peak.telecommunity.com/DevCenter/setuptools#using-setuptools-without-bundling-it
import ez_setup
ez_setup.use_setuptools()

import sys, os, os.path

from setuptools import setup, find_packages, Extension

__author__ = 'Flier Lu'

is_debug = True
is_win = os.name == 'nt' and sys.platform == 'win32'

VPX_HOME = os.environ.get('VPX_HOME', None)

if VPX_HOME:
    vpx_inc_path = os.path.join(VPX_HOME, 'include')
    vpx_lib_path = os.path.join(VPX_HOME, 'lib', 'Win32') if is_win else ''
    vpx_lib = 'vpxmt' if is_win else 'vpx'
else:
    vpx_inc_path = vpx_lib_path = vpx_lib = None

if is_win:
    macros = ['WIN32', '_WINDOWS']
    
    if is_debug:
        macros += ['_DEBUG']
        ccflags = ['/Od', '/Oy-', '/ZI']
        ldflags = ['/DEBUG']
    else:
        macros += ['NDEBUG']
        ccflags = ['/O2', '/Zi']
        ldflags = ['/DEBUG']

vpx = Extension(name = '_vpx',
                sources = ['vpx.i'],
                include_dirs = [vpx_inc_path],
                library_dirs = [vpx_lib_path],
                libraries = [vpx_lib],
                extra_compile_args = ccflags,
                extra_link_args = ldflags,
                language = 'c++')

setup(name = 'pyvpx',
      version = '0.3',
      description = 'Python Binding of WebM VP8 Codec',
      long_description = open('README').read(),
      author = __author__,
      author_email = 'flier.lu@gmail.com',
      url = 'https://github.com/flier/pyvpx',
      download_url = 'https://github.com/flier/pyvpx/downloads',
      packages = find_packages(),
      ext_modules = [vpx],
      py_modules = ['pyvpx', 'vpx', 'ez_setup'],
      test_suite = "tests",
      license = 'BSD',
      keywords = 'VPX video codec encoder decoder',
      classifiers = [
        'Development Status :: 4 - Beta',
        'Intended Audience :: Developers',
        'License :: OSI Approved :: BSD License',
        'Operating System :: OS Independent',
        'Programming Language :: C',
        'Programming Language :: Python',
        'Topic :: Multimedia :: Video',
        'Topic :: Software Development :: Libraries :: Python Modules',
      ],)