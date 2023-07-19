# Copyright (c) 2021, NVIDIA CORPORATION.  All rights reserved.

"""Helper script to sample calibration data for INT8 post-training quantization."""

import argparse
import os
import random
import subprocess
import joblib

from pycocotools.coco import COCO


def build_command_line_parser(parser=None):
    """
    Sample subset of a given dataset for INT8 calibration.

    Args:
        parser (subparser): Provided from the wrapper script to build a chained
            parser mechanism.

    Returns:
        parser
    """
    if parser is None:
        parser = argparse.ArgumentParser(prog='sample_calibration_images',
                                         description='Sample Calibration Images.')
    parser.add_argument(
        '-a',
        '--annotation_file',
        required=True,
        help='Path to the annotation file.')

    parser.add_argument(
        '-i',
        '--image_root_dir',
        required=True,
        help='Path to root image directory.')

    parser.add_argument(
        '-o',
        '--output_image_root_dir',
        required=True,
        help='Output file name.')

    parser.add_argument(
        '-n',
        '--num_images',
        required=False,
        type=int,
        default=500,
        help='Number of images to sample for calibration.')

    parser.add_argument(
        '-pth',
        '--min_persons_per_image',
        required=False,
        type=int,
        default=1,
        help='Threshold for number of persons per selected image.')

    parser.add_argument(
        '-kth',
        '--min_kpts_per_person',
        required=False,
        type=int,
        default=5,
        help='Threshold for number of keypoints per selected person.')

    parser.add_argument(
        "-r",
        "--randomize",
        action='store_true',
        help="Include this flag to randomize the sampling of data.")

    return parser


def parse_command_line_args(cl_args=None):
    """Parser command line arguments to the trainer.

    Args:
        cl_args (list): List of strings used as command line arguments.

    Returns:
        args_parsed: Parsed arguments.
    """
    parser = build_command_line_parser()
    args = parser.parse_args(cl_args)
    return args


def main(cl_args=None):
    """Sample subset of a given dataset for INT8 calibration based on user arguments.

    Args:
        args(list): list of arguments to be parsed if called from another module.
    """
    args = parse_command_line_args(cl_args)

    num_images = args.num_images
    annotation_file = args.annotation_file
    image_root_dir = args.image_root_dir
    output_image_root_dir = args.output_image_root_dir
    min_persons_per_image = args.min_persons_per_image
    min_kpts_per_person = args.min_kpts_per_person

    # Create output folder
    if not os.path.exists(output_image_root_dir):
        os.makedirs(output_image_root_dir)
    elif len(os.listdir(output_image_root_dir)):
        raise Exception("Output directory contains files! Please specify a valid output directory.")

    # Initialize the dataset and read image ids
    dataset = COCO(annotation_file)
    image_ids = list(dataset.imgs.keys())

    # Randomize the dataset
    if args.randomize:
        random.shuffle(image_ids)

    selected_images = []
    for _, image_id in enumerate(image_ids):
        filename = dataset.imgs[image_id]['file_name']

        # Get annotations
        annotation_ids = dataset.getAnnIds(imgIds=image_id)
        image_annotation = dataset.loadAnns(annotation_ids)

        num_persons = len(image_annotation)
        # Check if below given threshold
        if num_persons < min_persons_per_image:
            continue

        qualified_person_count = 0
        for pidx in range(num_persons):

            num_keypoints = image_annotation[pidx]["num_keypoints"]
            if num_keypoints < min_kpts_per_person:
                continue

            qualified_person_count += 1

        if qualified_person_count < min_persons_per_image:
            continue

        selected_images.append(filename)

        # Check if enough images have been selected
        if len(selected_images) > num_images:
            break

    if len(selected_images) < num_images:
        print("WARNING: Only {} / {} images sampled.".format(len(selected_images), num_images))

    copy_commands = []
    # Get commands to copy the required images to destination folder
    for idx in range(len(selected_images)):

        filename = selected_images[idx]
        source_image_path = os.path.join(image_root_dir, filename)
        dest_image_path = os.path.join(output_image_root_dir, filename)

        if not os.path.exists(os.path.dirname(dest_image_path)):
            os.makedirs(os.path.dirname(dest_image_path))

        command = 'cp {} {}'.format(source_image_path, dest_image_path)
        copy_commands.append(command)

    # Launch parallel jobs to copy the images
    joblib.Parallel(n_jobs=joblib.cpu_count(), verbose=10)(
        joblib.delayed(subprocess.call)(command, shell=True) for command in copy_commands)


if __name__ == '__main__':
    main()
