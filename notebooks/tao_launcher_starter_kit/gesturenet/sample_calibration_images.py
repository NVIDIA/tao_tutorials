# Copyright (c) 2021, NVIDIA CORPORATION.  All rights reserved.

"""Helper script to sample calibration data for INT8 post-training quantization."""

import argparse
import json
import os
import random
import cv2


# Color definition for stdout logs.
CYELLOW = '\033[93m'
CEND = '\033[0m'


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
        default=100,
        help='Number of images to sample for calibration.')

    parser.add_argument(
        '-mi',
        '--model_input_dim',
        required=False,
        type=int,
        default=160,
        help='Input size of model input.')

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
    model_input_dim = args.model_input_dim

    # Create output folder
    if not os.path.exists(output_image_root_dir):
        os.makedirs(output_image_root_dir)
    elif len(os.listdir(output_image_root_dir)):
        raise Exception("Output directory contains files! Please specify a valid output directory.")

    # Initialize the dataset and read image ids
    with open(annotation_file) as json_file:
        data = json.load(json_file)
        images_train = data['train_set']['images']
        images_val = data['validation_set']['images']

    # Randomize the dataset
    if args.randomize:
        random.shuffle(images_train)

    N = len(images_train)
    count = 0

    for i in range(N):
        img = images_train[i]['bbox_path']
        image_path = os.path.join(image_root_dir, img)

        img = cv2.imread(image_path)
        img = cv2.resize(img, (model_input_dim, model_input_dim), interpolation=cv2.INTER_CUBIC)
        cv2.imwrite(os.path.join(output_image_root_dir, str(count+1)+'.png'), img)

        count = count + 1
        # Check if enough images have been selected
        if count >= num_images:
            break

    print(CYELLOW + 'Number of images selected: {}'.format(count) + CEND)


if __name__ == '__main__':
    main()
