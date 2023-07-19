# Copyright (c) 2017-2020, NVIDIA CORPORATION.  All rights reserved.

"""Script to transform HGR dataset to Label Studio format for Gesturenet tutorial."""

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import argparse
from collections import defaultdict
import json
import numpy as np
import os
import shutil
from xml.dom import minidom


def mk_dir(path):
    """Create a directory if it doesn't exist.

    Args:
        path (string): Directory path

    """

    if not os.path.exists(path):
        try:
            os.makedirs(path)
        except OSError as e:
            pass


def get_bbox(label_path):
    """Use hgr xml with keypoints to compute tight hand bbox.

    Args:
        label_path (string): Path to hgr feature point xml with keypoints.

    Return:
        bbox_label_dict (dict): Dictionary with handbbox in label format required for GestureNet.
    """

    bbox_label_dict = {}
    bbox_label_dict["type"] = "rectanglelabels"
    label = minidom.parse(label_path)
    img_metadata = label.getElementsByTagName('IMAGE')[0]
    bbox_label_dict["original_width"] = int(
        img_metadata.attributes['WIDTH'].value)
    bbox_label_dict["original_height"] = int(
        img_metadata.attributes['HEIGHT'].value)
    bbox_dict = {}
    feature_points = label.getElementsByTagName('FeaturePoint')
    x_val = [int(fp.attributes['x'].value) for fp in feature_points]
    y_val = [int(fp.attributes['y'].value) for fp in feature_points]
    x1, x2 = min(x_val), max(x_val)
    y1, y2 = min(y_val), max(y_val)
    bbox_width = x2 - x1
    bbox_height = y2 - y1
    bbox_dict["x"] = (float(x1)/bbox_label_dict["original_width"])*100.0
    bbox_dict["y"] = (float(y1)/bbox_label_dict["original_height"])*100.0
    bbox_dict["width"] = (
        float(bbox_width)/bbox_label_dict["original_width"])*100.0
    bbox_dict["height"] = (
        float(bbox_height)/bbox_label_dict["original_height"])*100.0
    bbox_label_dict["value"] = bbox_dict
    return bbox_label_dict


def get_gesture_name(img_prefix):
    """Use image filename to extract user id, session id and gesture class.

    Args:
        img_prefix (string): Name of image without file extension.

    Return:
        u_id (string): Unique identifier for user.
        sess_id (string): Unique name for each recording session.
        gesture_class_dict (dict): Dictionary with gesture class in label format required for GestureNet.
    """
    gesture_code_label_map = {
    "0_A": "random",
    "1_A": "random",
    "1_P": "thumbs_up",
    "2_A": "two",
    "2_P": "random",
    "3_A": "random",
    "3_P": "random",
    "5_A": "stop",
    "9_A": "ok",
    "A_P": "fist",
    "B_P": "stop",
    "C_P": "random",
    "D_P": "random",
    "G_A": "random",
    "I_P": "random",
    "L_P": "random",
    "O_P": "ok",
    "S_A": "fist",
    "S_P": "ok",
    "V_A": "two",
    "Y_A": "random",
    "Y_P": "random"
    }
    gesture_class_dict = {}
    img_prefix_parts = img_prefix.split("_")
    sess_id = img_prefix_parts[2]
    u_id = img_prefix_parts[3]
    gesture_code = "_".join(img_prefix_parts[:2])
    if gesture_code in gesture_code_label_map:
        gesture_class = gesture_code_label_map[gesture_code]
        gesture_dict = {}
        gesture_dict["choices"] = []
        gesture_dict["choices"].append(gesture_class)
        gesture_class_dict["type"] = "choices"
        gesture_class_dict["value"] = gesture_dict

    return u_id, sess_id, gesture_class_dict


def prepare_set_config(user_dict):
    """Create a dummy dataset config with metadata.

    Args:
        user_dict (dict): Dictionary mapping each user id to a list of session ids.

    Return:
        set_config (dict): Dictionary with dataset config.
    """

    set_config = {}
    set_config["set"] = "data"
    set_config["users"] = {}
    for uid in user_dict:
        set_config["users"][uid] = {}
    return set_config


def parse_args(args=None):
    """parse the arguments."""
    parser = argparse.ArgumentParser(
        description='Transform dataset for GestureNet tutorial')

    parser.add_argument(
        "--input_image_dir",
        type=str,
        required=True,
        help="Input directory to HGR dataset images."
    )

    parser.add_argument(
        "--input_label_file",
        type=str,
        required=True,
        help="Input path to HGR dataset feature point labels."
    )

    parser.add_argument(
        "--output_dir",
        type=str,
        required=True,
        help="Ouput directory to TLT dataset."
    )

    return parser.parse_args(args)


def main(args=None):
    """Main function for data preparation."""

    args = parse_args(args)
    target_set_path = os.path.join(args.output_dir, "original", "data")
    target_label_path = os.path.join(target_set_path, "annotation")

    if not os.path.exists(target_set_path):
        mk_dir(target_set_path)
        mk_dir(target_label_path)
    else:
        print("This script will not run as output image path already exists.")
        return

    total_cnt = 0
    user_dict = defaultdict(list)
    for img_name in os.listdir(args.input_image_dir):
        img_prefix = img_name.split(".")[0]
        img_path = os.path.join(args.input_image_dir, img_name)
        label_path = os.path.join(args.input_label_file, img_prefix+".xml")
        if not os.path.exists(label_path):
            print("Error reading feature point xml, Please check data")
            return
        result_list = []
        u_id, sess_id, gesture_class_dict = get_gesture_name(img_prefix)

        if len(gesture_class_dict) == 0:
            continue
        total_cnt += 1
        user_dict[u_id].append(sess_id)
        result_list.append(gesture_class_dict)
        bbox_label_dict = get_bbox(label_path)
        result_list.append(bbox_label_dict)
        img_dest_folder = os.path.join(target_set_path, u_id, sess_id)
        mk_dir(img_dest_folder)
        img_dest_path = os.path.join(img_dest_folder, img_name)
        label_dest_path = os.path.join(target_label_path, img_prefix+".json")

        label_json = {}
        label_json["task_path"] = img_dest_path
        completion_dict = {}
        completion_dict["result"] = result_list
        label_json["completions"] = []
        label_json["completions"].append(completion_dict)
        # write label to disk
        with open(label_dest_path, "w") as label_file:
            json.dump(label_json, label_file, indent=2)
        # copy image to required path
        shutil.copyfile(img_path, img_dest_path)

    print("Total {} samples in dataset".format(total_cnt))

    set_config = prepare_set_config(user_dict)
    # write set config to disk
    with open(os.path.join(target_set_path, "data.json"), "w") as config_file:
        json.dump(set_config, config_file, indent=4)


if __name__ == "__main__":
    main()
