# Copyright (c) 2020, NVIDIA CORPORATION.  All rights reserved.
"""EmotionNet visualization util scripts."""

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import cv2
import errno
import os
import numpy as np
import json
import argparse


def mkdir_p(new_path):
    """Makedir, making also non-existing parent dirs.

    Args:
        new_path (str): path to the directory to be created
    """
    try:
        print(new_path)
        os.makedirs(new_path)
    except OSError as exc:
        if exc.errno == errno.EEXIST and os.path.isdir(new_path):
            pass
        else:
            raise


def check_dataset_structure(data_path):
    """Check the dataset structure.

    Args:
        data_path (str): path to the dataset
    """

    ret = True
    if not os.path.isdir(data_path):
        print("Dataset does not exist.")
        ret = False

    image_path = os.path.join(data_path, 'cohn-kanade-images')
    emotion_label_path = os.path.join(data_path, 'Emotion')
    landmarks_label_path = os.path.join(data_path, 'Landmarks')

    if not os.path.isdir(image_path):
        print("Image data path {} does not exist.".format(image_path))
        ret = False

    if not os.path.isdir(emotion_label_path):
        print("Emotion label path {} does not exist.".format(emotion_label_path))
        ret = False

    if not os.path.isdir(landmarks_label_path):
        print("Landmarks label path {} does not exist.".format(landmarks_label_path))
        ret = False

    return ret, image_path, emotion_label_path, landmarks_label_path


def extract_face_bbox(landmarks_2D):
    """Extract face bounding box from 2D bounding box.

    Args:
        landmarks_2D (array): 2D landmarks array
    """
    data_x = landmarks_2D[:, 0]
    data_y = landmarks_2D[:, 1]
    x_min = min(data_x)
    y_min = min(data_y)
    x_max = max(data_x)
    y_max = max(data_y)

    x1 = x_min
    y1 = y_min
    x2 = x_max
    y2 = y_max

    return list(map(int, [x1, y1, x2-x1, y2-y1]))


def isEmpty(path):
    """Determine if a directory is empty.

    Args:
        path (str): path to the directory
    """
    isEmpty = False
    if os.path.exists(path) and not os.path.isfile(path):
        # Checking if the directory is empty or not
        if not os.listdir(path):
            isEmpty = True
        else:
            isEmpty = False
    else:
        isEmpty = True
    return isEmpty


def read_landmarks_data(landmarks_file_path):
    """Read landmarks data.

    Args:
        landmarks_file_path (str): input landmarks path.
    """
    landmarks_data = []
    with open(landmarks_file_path, 'r') as f:
        contents = f.readlines()
        for j in range(len(contents)):
            content = contents[j].rstrip('\n')
            content = content.split(' ')
            for k in range(len(content)):
                if(content[k]!='' and content[k]!='\n'):
                    landmarks_data.append(float(content[k]))
        landmarks_data = np.array(landmarks_data, dtype=np.float32)
        landmarks_data = landmarks_data.astype(np.longdouble)
        landmarks_2D = landmarks_data.reshape(-1, 2)
    return landmarks_2D


def parse_args(args=None):
    """parse the arguments.

    Args:
        args (list): input argument
    """
    parser = argparse.ArgumentParser(description='Transfer CK+ dataset for EmotionNet')

    parser.add_argument(
        "--root_path",
        type=str,
        required=True,
        help="Root path to the testing dataset"
    )
    parser.add_argument(
        "--dataset_folder_name",
        type=str,
        required=True,
        help="CK+ dataset folder name"
    )
    parser.add_argument(
        "--container_root_path",
        type=str,
        required=True,
        help="Root path to the testing dataset inside container"
    )

    return parser.parse_args(args)


def main(args=None):
    """Main function to parse CK+ public dataset.

    Args:
        args (list): input argument
    """
    args = parse_args(args)
    root_path = args.root_path
    dataset_folder_name = args.dataset_folder_name
    container_root_path = args.container_root_path

    data_path = os.path.join(root_path, 'orgData', dataset_folder_name)
    container_data_path = os.path.join(container_root_path, 'orgData', dataset_folder_name)
    output_path = os.path.join(root_path, 'postData', dataset_folder_name)

    ret, image_dir, emotion_label_dir, landmarks_label_dir = check_dataset_structure(data_path)
    if not ret:
        raise Exception("CK+ dataset does not match expected structure.")

    # create path for json labels:
    json_result_path = os.path.join(data_path, 'data_factory', 'fiducial')
    mkdir_p(json_result_path)

    emotion_map_ckpulus = {0: 'neutral', 1: 'angry', 2: 'contempt', 3: 'disgust', 4: 'fear', 5: 'happy', 6: 'sad', 7: 'surprise'}
    neutral_image_percentage = 0.1
    emotion_image_percentage = 0.9

    user_list = os.listdir(image_dir)
    for k in range(0, len(user_list)):
        user_name = user_list[k]
        user_png_path = os.path.join(image_dir, user_name)
        sequence_png_list = os.listdir(user_png_path)

        for seq in sequence_png_list:
            seq_png_path = os.path.join(user_png_path, seq)
            seq_landmarks_path = os.path.join(landmarks_label_dir, user_name, seq)
            seq_emotion_path = os.path.join(emotion_label_dir, user_name, seq)

            if isEmpty(seq_emotion_path) or isEmpty(seq_landmarks_path) or\
                isEmpty(seq_png_path):
                continue
            else:
                label_file_list = os.listdir(seq_emotion_path)
                # For CK+, only one emotion label text file exist in each sequence folder
                assert(len(label_file_list)) == 1
                emotion_label_path = os.path.join(seq_emotion_path, label_file_list[0])
                f = open(emotion_label_path, 'r')
                emotion_label = int(float(f.read()))
                emotion_name_ckplus = emotion_map_ckpulus[emotion_label]

                # get image file
                image_file_list = os.listdir(seq_png_path)
                if '.DS_Store' in image_file_list:
                    image_file_list.remove('.DS_Store')
                image_num_all = len(image_file_list)
                image_num_neutral = max(1, int(image_num_all * neutral_image_percentage))
                image_num_curr_emotion = max(1, int(image_num_all * emotion_image_percentage))
                neutral_list_prefix = []
                curr_emotion_prefix = []
                for i in range(1, image_num_all + 1):
                    frame_id = str(i).zfill(8)
                    file_prefix = user_name + '_' + seq + '_' + frame_id
                    if i <= image_num_neutral:
                        neutral_list_prefix.append(file_prefix)
                    elif i > image_num_curr_emotion:
                        curr_emotion_prefix.append(file_prefix)
                    else:
                        continue

                ret = False
                for file_prefix in neutral_list_prefix:
                    emotion_name = 'neutral'
                    ret = setup_frame_dict(file_prefix, seq_png_path, seq_landmarks_path,
                                           emotion_label, emotion_name, user_name,
                                           json_result_path, data_path, container_data_path, False)
                for file_prefix in curr_emotion_prefix:
                    ret = setup_frame_dict(file_prefix, seq_png_path, seq_landmarks_path,
                                           emotion_label, emotion_name_ckplus, user_name,
                                           json_result_path, data_path, container_data_path, False)
                if not ret:
                    continue


def setup_frame_dict(file_prefix, image_path, landmarks_path, emotion_label,
                     emotion_class_name, user_name, json_result_path,
                     data_path, container_data_path, debug=False):
    """Set up frame dictionary.

    Args:
        file_prefix (str): prefix for the file
        image_path (str): path to the image
        landmarks_path (str): path to the landmarks
        emotion_label (int): emotion label id of the provided image
        emotion_class_name (str): emotion class name of the provided image
        user_name (str): user name 
        json_result_path (str): json result path
        debug (bool): debug flag
    """

    image_file_name = file_prefix + '.png'
    landmarks_file_name = file_prefix + '_landmarks.txt'
    frame_path = os.path.join(image_path, image_file_name)
    image_frame = cv2.imread(frame_path)
    assert image_frame.shape[0] > 0 and image_frame.shape[1] > 0

    # read landmarks file and process/normalize the landmarks
    landmarks_file_path = os.path.join(landmarks_path, landmarks_file_name)
    landmarks_2D = read_landmarks_data(landmarks_file_path)
    num_landmarks = landmarks_2D.shape[0]
    facebbox = extract_face_bbox(landmarks_2D)

    main_label_json = []
    label_json = {}
    label_json['class'] = 'image'
    path_info = frame_path.split(data_path)
    container_frame_path = container_data_path + path_info[-1]
    label_json['filename'] = container_frame_path
    label_annotations = []
    facebbox_dict = {}
    landmarks_dict = {}

    # set face bounding box dictionary
    facebbox_dict['class'] = "FaceBbox"
    landmarks_dict["tool-version"] = "1.0"
    facebbox_dict['face_tight_bboxx'] = str(facebbox[0])
    facebbox_dict['face_tight_bboxy'] = str(facebbox[1])
    facebbox_dict['face_tight_bboxwidth'] = str(facebbox[2])
    facebbox_dict['face_tight_bboxheight'] = str(facebbox[3])

    # set landmarks face bounding box dictionary
    landmarks_dict['class'] = "FiducialPoints"
    landmarks_dict['tool-version'] = "1.0"
    for k in range(0, num_landmarks):
        pt_x_name = 'P' + str(k + 1) + 'x'
        pt_y_name = 'P' + str(k + 1) + 'y'
        landmarks_dict[pt_x_name] = float(landmarks_2D[k][0])
        landmarks_dict[pt_y_name] = float(landmarks_2D[k][1])

    label_annotations.append(facebbox_dict)
    label_annotations.append(landmarks_dict)
    label_json['annotations'] = label_annotations

    main_label_json.append(label_json)

    json_file_name = os.path.join(json_result_path, file_prefix + '_' + emotion_class_name + '.json')
    print("Generate json: ", json_file_name)
    with open(json_file_name, "w") as label_file:
        json.dump(main_label_json, label_file, indent=4)

    return True


if __name__ == "__main__":
    main()
