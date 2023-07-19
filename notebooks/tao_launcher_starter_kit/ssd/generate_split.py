# Copyright (c) 2017-2020, NVIDIA CORPORATION.  All rights reserved.

"""Script to generate splitted dataset for SSD/DSSD/Retinanet tutorial."""

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import argparse
import os
import shutil


def parse_args(args=None):
    """parse the arguments."""
    parser = argparse.ArgumentParser(description='Generate splitted dataset for SSD/DSSD/Retinanet tutorial')

    parser.add_argument(
        "--input_image_dir",
        type=str,
        required=True,
        help="Input directory to KITTI training dataset images."
    )

    parser.add_argument(
        "--input_label_dir",
        type=str,
        required=True,
        help="Input directory to KITTI training dataset labels."
    )

    parser.add_argument(
        "--output_dir",
        type=str,
        required=True,
        help="Ouput directory to TAO split dataset."
    )

    parser.add_argument(
        "--val_split",
        type=int,
        required=False,
        default=10,
        help="Percentage of training dataset for generating val dataset"
    )

    return parser.parse_args(args)


def main(args=None):
    """Main function for data preparation."""

    args = parse_args(args)

    img_files = []
    for file_name in os.listdir(args.input_image_dir):
        if file_name.split(".")[-1] == "png":
            img_files.append(file_name)

    total_cnt = len(img_files)
    val_ratio = float(args.val_split) / 100.0
    val_cnt = int(total_cnt * val_ratio)
    train_cnt = total_cnt - val_cnt
    val_img_list = img_files[0: val_cnt]
    train_img_list = img_files[val_cnt:]
    print(f"Total {total_cnt} samples in KITTI training dataset")
    print(f"{train_cnt} for train and {val_cnt} for val")

    # Create split
    os.makedirs(os.path.join(args.output_dir, "training"), exist_ok=True)
    os.makedirs(os.path.join(args.output_dir, "val"), exist_ok=True)

    train_target_img_path = os.path.join(args.output_dir, "training", "image")
    train_target_label_path = os.path.join(args.output_dir, "training", "label")

    os.makedirs(train_target_img_path, exist_ok=True)
    os.makedirs(train_target_label_path, exist_ok=True)

    val_target_img_path = os.path.join(args.output_dir, "val", "image")
    val_target_label_path = os.path.join(args.output_dir, "val", "label")

    os.makedirs(val_target_img_path, exist_ok=True)
    os.makedirs(val_target_label_path, exist_ok=True)

    for img_name in train_img_list:
        label_name = img_name.split(".")[0] + ".txt"
        shutil.copyfile(os.path.join(args.input_image_dir, img_name),
                  os.path.join(train_target_img_path, img_name))
        shutil.copyfile(os.path.join(args.input_label_dir, label_name),
                  os.path.join(train_target_label_path, label_name))
    print("Finished copying training set")

    for img_name in val_img_list:
        label_name = img_name.split(".")[0] + ".txt"
        shutil.copyfile(os.path.join(args.input_image_dir, img_name),
                  os.path.join(val_target_img_path, img_name))
        shutil.copyfile(os.path.join(args.input_label_dir, label_name),
                  os.path.join(val_target_label_path, label_name))
    print("Finished copying validation set")


if __name__ == "__main__":
    main()
