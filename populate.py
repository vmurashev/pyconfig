from __future__ import print_function 
import argparse
import json
import os
import os.path
import shutil


def copy_tree_by_catalog(catalog_file, input_dir, output_dir):
    extra = ['LICENSE']
    with open(catalog_file) as fh:
        catalog = json.load(fh)
    catalog.extend(extra)
    for entry in catalog:
        if entry in extra:
            fref = entry
        else:
            bits = entry.split('/')
            bits = bits[2:]
            fref = '/'.join(bits)
        if not fref:
            raise Exception("Bad catalog entry: '{}'".format(entry))
        src = os.path.normpath(os.path.abspath(os.path.join(input_dir, fref)))
        if not os.path.isfile(src):
            if fref in [ 'PC/invalid_parameter_handler.c' ]:
                continue
        dest = os.path.normpath(os.path.abspath(os.path.join(output_dir, fref)))
        dest_dir = os.path.dirname(dest)
        if not os.path.isdir(dest_dir):
            os.makedirs(dest_dir)
        print("['{}'] - {} >>> {}".format(fref, src, dest))
        shutil.copyfile(src, dest)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--catalog', nargs=1, type=str, required=True)
    parser.add_argument('--input', nargs=1, type=str, required=True)
    parser.add_argument('--output', nargs=1, type=str, required=True)
    args = parser.parse_args()

    catalog_file = args.catalog[0]
    input_dir = args.input[0]
    output_dir = args.output[0]

    copy_tree_by_catalog(catalog_file, input_dir, output_dir)
    print('Done!')
