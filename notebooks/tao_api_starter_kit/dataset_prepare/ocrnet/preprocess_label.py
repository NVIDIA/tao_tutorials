# SPDX-FileCopyrightText: Copyright (c) 2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# Clean the label to alphanumeric, non-sensitive (lower case). Filter the label with length larger than 25
import os
import re
import sys
from tqdm import tqdm

def preprocess_label(gt_file, filtered_file):
    gt_list = open(gt_file, "r").readlines()
    filtered_list = []

    character_list = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    for label_line in tqdm(gt_list):
        try:
            path, label = label_line.strip().split()
        except Exception:
            continue
        path = path[:-1]
        label = label.strip("\"")
        if re.search(f"[^{character_list}]", label):
            continue
        else:
            if len(label) <= 25:
                label = label.lower() # ignore the case
                filtered_list.append(f"{path}\t{label}\n")

    with open(filtered_file, "w") as f:
        f.writelines(filtered_list)

def main():
    preprocess_label(sys.argv[1], sys.argv[2])
    character_list = "0123456789abcdefghijklmnopqrstuvwxyz"
    with open(os.path.join(os.getenv("DATA_DIR"), "character_list"), "w") as f:
         for ch in character_list:
                f.write(f"{ch}\n")

if __name__ == "__main__":
    main()