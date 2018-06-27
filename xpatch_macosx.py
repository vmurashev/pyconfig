import os.path
import subprocess
import sys

DIR_HERE = os.path.normpath(os.path.abspath(os.path.dirname(__file__)))
PATCH_SCRIPT = os.path.join(DIR_HERE, 'xpatch.py')

if __name__ == '__main__':
    py2_input_file = os.path.normpath(os.path.join(DIR_HERE,   'input/python-2.7/pyconfig_macosx.h'))
    py2_output_file = os.path.normpath(os.path.join(DIR_HERE, 'output/python-2.7/pyconfig_macosx.h'))
    py2_args = [sys.executable, PATCH_SCRIPT, '--abi', 'macosx', '--input', py2_input_file, '--output', py2_output_file]
    subprocess.check_call(py2_args)
