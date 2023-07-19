# Copyright (c) 2021, NVIDIA CORPORATION.  All rights reserved.

"""Helper script to sample calibration data for INT8 post-training quantization."""

import argparse
import json
import os
import random
import cv2
import numpy as np

# Color definition for stdout logs.
CRED = '\033[91m'
CGREEN = '\033[92m'
CYELLOW = '\033[93m'
CEND = '\033[0m'


def build_command_line_parser(parser=None):
    """
    Sample subset of given dataset for INT8 calibration.

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
        '-oi',
        '--old_image_root_dir',
        required=True,
        help='Path to old root image directory.')

    parser.add_argument(
        '-ni',
        '--new_image_root_dir',
        required=True,
        help='Path to new root image directory.')

    parser.add_argument(
        '-o',
        '--output_image_root_dir',
        required=True,
        help='Output file name.')

    parser.add_argument(
        '-nk',
        '--num_keypoints',
        required=False,
        type=int,
        default=80,
        help='Number of keypoints.')

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
        default=80,
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


def parse_json_contents(jsonFile, old_image_root, new_image_root, num_keypoints=80):
    '''
    Function to read ground truth json file.

    Args:
        jsonFile (str): Path of json file.
        old_image_root (str): Old/original image root path.
        new_image_root (str): New image root path.
        num_keypoints (int): Number of keypoints to extract from data json.
    Returns:
        dataset (list): list of samples, sample{img_path, landmarks, occ}.
    '''
    json_data = json.loads(open(jsonFile, 'r').read())
    dataset = list()
    for img in json_data:
        sample = dict()
        sample['img_path'] = ''
        sample['landmarks'] = np.zeros((num_keypoints, 2))
        try:
            fname = str(img['filename'])
            fname = fname.replace(old_image_root, new_image_root)
            if not os.path.exists(fname):
                print(CRED + 'Image does not exist: {}'.format(fname) + CEND)
                continue

            # Start collecting points information from the json file.
            x = [0] * num_keypoints
            y = [0] * num_keypoints

            for chunk in img['annotations']:
                if 'fiducialpoints' not in chunk['class'].lower():
                    continue

                points_data = (point for point in chunk if ('class' not in point and
                                                            'version' not in point))
                for point in points_data:
                    number = int(
                        ''.join(c for c in str(point) if c.isdigit()))
                    if 'x' in str(point).lower() and number <= num_keypoints:
                        x[number - 1] = str(int(float(chunk[point])))
                    if 'y' in str(point).lower() and number <= num_keypoints:
                        y[number - 1] = str(int(float(chunk[point])))


                sample = dict()
                sample['img_path'] = fname
                sample['landmarks'] = np.asarray([x, y]).T
                dataset.append(sample)
        except Exception as e:
            print(CRED + str(e) + CEND)
    return dataset


def get_bbox(x1, y1, x2, y2):
    '''
    Function to get normalized bounding box.

    This module makes the bounding box square by
    increasing the lower of the bounding width and height.
    Args:
        x1 (int): x_min value of bbox.
        y1 (int): y_min value of bbox.
        x2 (int): x_max value of bbox.
        y2 (int): y_max value of bbox.
    Returns:
        Normalized bounding box coordinates in form [x1, y1, x2, y2].
    '''
    x_start = int(np.floor(x1))
    x_end = int(np.ceil(x2))
    y_start = int(np.floor(y1))
    y_end = int(np.ceil(y2))

    width = np.ceil(x_end - x_start)
    height = np.ceil(y_end - y_start)

    if width < height:
        diff = height - width
        x_start -= (np.ceil(diff/2.0))
        x_end += (np.floor(diff/2.0))
    elif width > height:
        diff = width - height
        y_start -= (np.ceil(diff/2.0))
        y_end += (np.floor(diff/2.0))

    width = x_end - x_start
    height = y_end - y_start
    assert width == height
    rect_init_square = [int(x_start), int(y_start), int(width), int(height)]
    return rect_init_square


def enlarge_bbox(bbox, ratio=1.0):
    '''
    Module enlarges the bounding box by a scaling factor.

    Args:
        bbox (list): Bounding box coordinates of the form [x1, y1, x2, y2].
        ratio (float): Bounding box enlargement scale/ratio.
    Returns:
        Scaled bounding box coordinates.
    '''
    x_start, y_start, width, height = bbox
    x_end = x_start + width
    y_end = y_start + height
    assert width == height, 'width %s is not equal to height %s'\
        % (width, height)
    change = ratio - 1.0
    shift = int((change/2.0)*width)
    x_start_new = int(np.floor(x_start - shift))
    x_end_new = int(np.ceil(x_end + shift))
    y_start_new = int(np.floor(y_start - shift))
    y_end_new = int(np.ceil(y_end + shift))

    # Assertion for increase length.
    width = int(x_end_new - x_start_new)
    height = int(y_end_new - y_start_new)
    assert height == width
    rect_init_square = [x_start_new, y_start_new, width, height]
    return rect_init_square


def detect_bbox(kpts, img_size, dist_ratio=1.0, num_kpts=80):
    '''
    Utility to get the bounding box using only kpt information.

    This method gets the kpts and the original image size.
    Then, it then gets a square encompassing all key-points and
    later enlarges that by dist_ratio.
    Args:
        kpts: the kpts in either format of 1-dim of size #kpts * 2
            or 2-dim of shape [#kpts, 2].
        img_size: a 2-value tuple indicating the size of the original image
                with format (width_size, height_size)
        dist_ratio: the ratio by which the original key-points to be enlarged.
        num_kpts (int): Number of keypoints.
    Returns:
        bbox with values (x_start, y_start, width, height).
    '''
    x_min = np.nanmin(kpts[:, 0])
    x_max = np.nanmax(kpts[:, 0])
    y_min = np.nanmin(kpts[:, 1])
    y_max = np.nanmax(kpts[:, 1])

    bbox = get_bbox(x_min, y_min, x_max, y_max)
    # Enlarge the bbox by a ratio.
    rect = enlarge_bbox(bbox, dist_ratio)

    # Ensure enlarged bounding box within image bounds.
    if((bbox[0] < 0) or
       (bbox[1] < 0) or
       (bbox[2] + bbox[0] > img_size[0]) or
       (bbox[3] + bbox[1] > img_size[1])):
        return None

    return rect


def main(cl_args=None):
    """Sample subset of a given dataset for INT8 calibration based on user arguments.

    Args:
        args(list): list of arguments to be parsed if called from another module.
    """
    args = parse_command_line_args(cl_args)

    num_images = args.num_images
    annotation_file = args.annotation_file
    old_image_root_dir = args.old_image_root_dir
    new_image_root_dir = args.new_image_root_dir
    output_image_root_dir = args.output_image_root_dir
    model_input_dim = args.model_input_dim
    num_keypoints = args.num_keypoints

    # Create output folder
    if not os.path.exists(output_image_root_dir):
        os.makedirs(output_image_root_dir)
    elif len(os.listdir(output_image_root_dir)):
        raise Exception("Output directory contains files! Please specify a valid output directory.")

    # Initialize the dataset and read image ids
    jsondata = parse_json_contents(annotation_file, old_image_root_dir,
                                   new_image_root_dir, num_keypoints)

    # Randomize the dataset
    if args.randomize:
        random.shuffle(jsondata)

    N = len(jsondata)
    count = 0
    for i in range(N):

        landmarks = jsondata[i]['landmarks'].astype('float')
        image_path = jsondata[i]['img_path']
        image = cv2.imread(image_path)
        if image is None:
            print(CRED + 'Bad image:{}'.format(image_path) + CEND)
            continue

        image_shape = image.shape

        bbox = detect_bbox(kpts=landmarks,
                           img_size=(image_shape[1], image_shape[0]))
        if bbox is None:
            continue

        # crop face bbox and resize
        img = image[bbox[1]:bbox[1] + bbox[3], bbox[0]:bbox[0] + bbox[2], :]
        img = cv2.resize(img, (model_input_dim, model_input_dim), interpolation=cv2.INTER_CUBIC)

        cv2.imwrite(os.path.join(output_image_root_dir, image_path.replace('/', '_')), img)

        count = count + 1

        # Check if enough images have been selected
        if count >= num_images:
            break

    print(CYELLOW + 'Number of images selected: {}'.format(count) + CEND)


if __name__ == '__main__':
    main()
