#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Jul 31 15:34:06 2023

@author: markc
"""

import os
from dandi.dandiapi import DandiAPIClient
from pynwb import NWBHDF5IO
import numpy as np
from pynwb.core import NWBDataInterface

api_key = "7d9431a44b9edd9dd1a1137b5b7e09fdde3243de"
dataset_id = "000615"

with DandiAPIClient() as client:
    client.authenticate(api_key)
    dataset = client.get_dandiset(dataset_id, "draft")

    # Loop over all nwb files in DANDI
    for asset in dataset.get_assets():
        filepath = f"./{asset.path.split('/')[-1]}"
        print(f"Downloading {filepath}")
        asset.download(filepath)

        # Create directory for each file
        with NWBHDF5IO(filepath, 'r') as io:
            nwbfile = io.read()
            identifier = nwbfile.identifier
            dir_name = identifier.split('_')[1][:4] + '-' + identifier.split('_')[1][4:6] + '-' + identifier.split('_')[1][6:]
            if not os.path.exists(dir_name):
                os.makedirs(dir_name)

            # Loop over acquisitions to extract AP and PSP files
            for acquisition in nwbfile.acquisition.values():
                if isinstance(acquisition, NWBDataInterface):
                    data = acquisition.data[:]
                    acquisition_number = ''.join(filter(str.isdigit, acquisition.name))
                    file_name = f"AP_{acquisition_number}.txt" if 'AP' in acquisition.name else f"PSP_{acquisition_number}.txt"
                    print(f"\rExtracting {file_name}...", end="")
                    np.savetxt(os.path.join(dir_name, file_name), data)
        print()
