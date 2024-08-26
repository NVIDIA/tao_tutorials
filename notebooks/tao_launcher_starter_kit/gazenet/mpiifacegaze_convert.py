# Copyright (c) 2020, NVIDIA CORPORATION.  All rights reserved.
"""GazeNet public dataset conversion scripts."""

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import cv2
import errno
import os
import json
import argparse
import scipy.io as scio


def mkdir_p(new_path):
    """Makedir, making also non-existing parent dirs.

    Args:
        new_path (str): path to the directory to be created
    """
    try:
        print("Creating path {}".format(new_path))
        os.makedirs(new_path)
    except OSError as exc:
        if exc.errno == errno.EEXIST and os.path.isdir(new_path):
            pass
        else:
            raise


def parse_args(args=None):
    """parse the arguments.

    Args:
        args (list): input argument
    """
    parser = argparse.ArgumentParser(description='Transfer MPIIFaceGaze dataset for GazeNet')

    parser.add_argument(
        '--data_path',
        type=str,
        required=True,
        help="MPIIFaceGaze dataset path"
    )
    parser.add_argument(
        '--json_label_root_path',
        type=str,
        required=True,
        help="root path to the json label folders"
    )

    return parser.parse_args(args)


def decode_mat(path):
    """Decode mat file.

    Args:
        path (str): path to the mat file
    """
    data = scio.loadmat(path)
    return data


def generate_config_folder(calibration_path, config_path):
    """Generate config folder as required data format.

    Args:
        calibration_path (str): path to the calibration file in MPIIFullFace dataset
        config_path (str): config folder path
    """
    camera_file_path = os.path.join(calibration_path, 'Camera.mat')
    extrinsic_file_path = os.path.join(calibration_path, 'monitorPose.mat')
    screen_file_path = os.path.join(calibration_path, 'screenSize.mat')

    # Get camera matrix and distortion information
    camera_info = decode_mat(camera_file_path)
    cameraMatrix = camera_info['cameraMatrix']
    distCoeffs = camera_info['distCoeffs']

    # Convert camera matrix to expected format
    camera_file = os.path.join(config_path, 'camera_parameters.txt')
    with open(camera_file, 'w') as f_camera:
        content = ''
        for k in range(0, 3):
            for j in range(0, 2):
                content += str(cameraMatrix[k][j]) + ','
            content += str(cameraMatrix[k][2]) + '\n'
        content += '\n'

        for k in range(0, 5):
            content += str(distCoeffs[0][k]) + '\n'
        f_camera.write(content)

    # Get extrinsic information
    extrinsic_info = decode_mat(extrinsic_file_path)
    rvects = extrinsic_info['rvects']
    tvecs = extrinsic_info['tvecs']
    R, _ = cv2.Rodrigues(rvects)

    # Convert translation vector to expected format
    R_file = os.path.join(config_path, 'R.txt')
    with open(R_file, 'w') as f_R:
        content = ''
        for k in range(0, 3):
            for j in range(0, 2):
                content += str(R[k][j]) + ','
            content += str(R[k][2]) + '\n'
        f_R.write(content)

    # Convert translation vector to expected format
    T_file = os.path.join(config_path, 'T.txt')
    with open(T_file, 'w') as f_T:
        content = ''
        for k in range(0, 3):
            content += str(tvecs[k][0]) + '\n'
        f_T.write(content)

    # get screen information
    screen_info = decode_mat(screen_file_path)
    screen_width = screen_info['width_pixel'][0][0]
    screen_height = screen_info['height_pixel'][0][0]
    screen_width_phy = screen_info['width_mm'][0][0]
    screen_height_phy = screen_info['height_mm'][0][0]

    # Convert screen physical size values to expected format
    TV_size_file = os.path.join(config_path, 'TV_size')
    with open(TV_size_file, 'w') as f_TV_size:
        content = str(screen_width_phy) + '\n' + str(screen_height_phy) + '\n'
        f_TV_size.write(content)

    # Convert screen resolution values to expected format
    resolution_file = os.path.join(config_path, 'resolution.txt')
    with open(resolution_file, 'w') as f_resolution:
        content = str(screen_width) + '\n' + str(screen_height) + '\n'
        f_resolution.write(content)


def convert_data(data_path, json_label_root_path):
    """Convert data from public dataset format to required data format.

    Args:
        data_path (str): data root path
        json_label_root_path (str): json label root path
    """
    sample_data_path = os.path.join(data_path, 'sample-dataset')
    mkdir_p(sample_data_path)
    inference_set_path = os.path.join(sample_data_path, 'inference-set')
    mkdir_p(inference_set_path)
    sample_json_label_path = os.path.join(json_label_root_path, 'data_factory', 'day03')
    set_list = os.listdir(sample_json_label_path)

    st = set_list[0]
    set_name = st + '-day03'
    set_path = os.path.join(sample_data_path, set_name)
    mkdir_p(set_path)

    # Generate config folder from calibration folder
    calibration_path = os.path.join(data_path, st, 'Calibration')
    config_path = os.path.join(set_path, 'Config')
    mkdir_p(config_path)
    generate_config_folder(calibration_path, config_path)
    inference_config_path = os.path.join(inference_set_path, 'Config')
    mkdir_p(inference_config_path)
    generate_config_folder(calibration_path, inference_config_path)

    # Extract x, y screen pixel ground truth to a dictionary
    gt_file = os.path.join(data_path, st, st + '.txt')
    public_data_dict = {}
    screen_data_dict = {}
    with open(gt_file, 'r') as f_gt:
        for line in f_gt:
            frame_dict = {}
            line_split = line.rstrip().split(' ')
            frame_name = os.path.join(st, line_split[0])
            frame_dict['screen_y'] = line_split[1]
            frame_dict['screen_x'] = line_split[2]
            screen_data_key = line_split[1] + '_' + line_split[2]
            if screen_data_key not in screen_data_dict.keys():
                screen_data_dict[screen_data_key] = 0
            else:
                screen_data_dict[screen_data_key] += 1
            frame_dict['id'] = screen_data_dict[screen_data_key]
            public_data_dict[frame_name] = frame_dict

    # Re-position the json file to each sample data folder
    json_file_name = st + '_day03.json'
    json_file_full_path = os.path.join(sample_json_label_path, st, json_file_name)
    if not os.path.isfile(json_file_full_path):
        print("File {} does not exist!".format(json_file_full_path))

    # Convert image data
    image_data_path = os.path.join(set_path, 'Data')
    mkdir_p(image_data_path)
    target_json_folder = os.path.join(sample_data_path, set_name, 'json_datafactory_v2')
    mkdir_p(target_json_folder)
    inference_image_data_path = os.path.join(inference_set_path, 'Data')
    mkdir_p(inference_image_data_path)
    inference_target_json_folder = os.path.join(inference_set_path, 'json_datafactory_v2')
    mkdir_p(inference_target_json_folder)

    # create 5 copies of the data (for demonstration purpose)
    for k in range(0, 5):
        with open(json_file_full_path, 'r') as json_file:
            json_reader = json.load(json_file)

        user_name = st + '-' + str(k)
        user_data_path = os.path.join(image_data_path, user_name)
        mkdir_p(user_data_path)

        entry = []
        for frame_json in json_reader:
            if 'annotations' not in frame_json:
                continue
            frame_path = frame_json['filename']
            frame_data_path = os.path.join(data_path, frame_path)
            if not os.path.isfile(frame_data_path):
                raise ValueError('Image file does not exist in path {}.'.format(frame_data_path))
            img = cv2.imread(frame_data_path)
            height, width, _ = img.shape
            assert height > 0 and width > 0
            if frame_path not in public_data_dict.keys():
                print("Data {} does not exist!".format(frame_path))
                continue
            file_name = 'frame_' + public_data_dict[frame_path]['screen_y'] + \
                        '_' + public_data_dict[frame_path]['screen_x'] + \
                        '_' + str(public_data_dict[frame_path]['id']) + '.png'

            update_frame_path = os.path.join(user_data_path, file_name)
            cv2.imwrite(update_frame_path, img)
            frame_json['filename'] = update_frame_path
            entry.append(frame_json)

            update_json_file = st + '-day03' + '_' + user_name + '.json'
            target_json_full_path = os.path.join(target_json_folder, update_json_file)
            updated_json = open(target_json_full_path, 'w')
            json.dump(entry, updated_json, indent=4)

    # Use the provided data copy as inference examples
    with open(json_file_full_path, 'r') as json_file:
        json_reader = json.load(json_file)

    entry = []
    for frame_json in json_reader:
        if 'annotations' not in frame_json:
            continue
        frame_path = frame_json['filename']
        if frame_path not in public_data_dict.keys():
            print("Data {} does not exist!".format(frame_path))
            continue
        frame_data_path = os.path.join(data_path, frame_path)
        if not os.path.isfile(frame_data_path):
            print("Image file {} does not exist!".format(frame_data_path))
            continue
        img = cv2.imread(frame_data_path)
        height, width, _ = img.shape
        assert height > 0 and width > 0
        file_name = 'frame_' + public_data_dict[frame_path]['screen_y'] + \
                    '_' + public_data_dict[frame_path]['screen_x'] + \
                    '_' + str(public_data_dict[frame_path]['id']) + '.png'

        update_frame_path = os.path.join(inference_image_data_path, file_name)
        cv2.imwrite(update_frame_path, img)
        frame_json['filename'] = file_name
        entry.append(frame_json)

        target_json_full_path = os.path.join(inference_target_json_folder, json_file_name)
        updated_json = open(target_json_full_path, 'w')
        json.dump(entry, updated_json, indent=4)


def main(args=None):
    """Main function to parse MPIIFaceGaze public dataset.

    Args:
        args (list): input argument
    """
    args = parse_args(args)
    data_path = args.data_path
    json_label_root_path = args.json_label_root_path

    convert_data(data_path, json_label_root_path)


if __name__ == "__main__":
    main()
