# copyright Yang Lab 2023
#
# This is a python script that auto converts Yang Lab ephys formats
# into other formats .
# Works in Linux 6.4.3+, WSL 1.2.5+, and MacOS 10.17+
import os, re
import neo.io
import numpy as np
from neo.io import NWBIO, AsciiSignalIO, IgorIO
from tqdm import tqdm

def nwb2txt(w_dir,inputfilename=None, outputfilename=None):
    # e.g. ephysCONV.nwb2txt('inputfilename.nwb', 'outputfilename.txt') for mark's ephys work
    if w_dir is not None: os.chdir(w_dir)
    if inputfilename is None:
        inputfilename = [f for f in os.listdir(os.getcwd()) if f.endswith('.nwb')]
    else:
        inputfilename = [inputfilename]

    print('recognized {}'.format(inputfilename))

    for i in range(len(inputfilename)):
        print('reading {} of {}...'.format(i+1,len(inputfilename)))
        if not(os.path.exists(inputfilename[i][:-4])):
            os.mkdir(inputfilename[i][:-4])
            print('creating new directory {}'.format(inputfilename[i][:-4]))
        r = NWBIO(filename=inputfilename[i])
        blocks = r.read()
        with tqdm(total=100) as pbar:
            for j in range(len(blocks[0].segments[0].analogsignals)):   # type: ignore
                signal = blocks[0].segments[0].analogsignals[j]         # type: ignore
                fname = "_".join(re.findall('(\d+|\D+)',signal.name))
                outputfilename = fname + '.txt'
                pbar.set_description('writing {}...'.format(outputfilename))
                np.savetxt(os.path.join(inputfilename[i][:-4],outputfilename),signal)
                pbar.update(100*1/len(blocks[0].segments[0].analogsignals))     # type: ignore
        pbar.close()

def txt2nwb(objectname, inputfilename, outputfilename):
    #TODO: e.g. ephysCONV.nwb2txt('inputfilename.nwb', 'outputfilename.txt')

    pass

def pxp2nwb(objectname, inputfilename, outputfilename):
    # TODO: e.g. ephysCONV.nwb2txt('inputfilename.nwb', 'outputfilename.txt')
    pass
