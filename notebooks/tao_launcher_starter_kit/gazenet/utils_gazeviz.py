# Copyright (c) 2020, NVIDIA CORPORATION.  All rights reserved.
"""GazeNet visualization util scripts."""

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import cv2
import os
import numpy as np
import json
import face_model_nv68

MIN_LANDMARK_FOR_PNP = 4
NUM_JSON_LANDMARKS = 104


def get_landmarks_info():
    """Get landmarks information.

    Return:
        landmarks_3D_selected (array): 3D landmarks for a face model
        landmarks_2D_set_selected (array): 2D landmarks index from the labeling
        le_center (array): left eye center
        re_center (array): right eye center
    """
    anthropometic_3D_landmarks = face_model_nv68.anthropometic_3D_landmarks
    anthropometic_3D_landmarks = np.asarray(anthropometic_3D_landmarks, dtype=float)
    anthropometic_3D_landmarks[:, [1, 2]] = anthropometic_3D_landmarks[:, [2, 1]]
    anthropometic_3D_landmarks *= -1  # Inverse X, Y, Z axis.

    le_outer = anthropometic_3D_landmarks[45]
    le_inner = anthropometic_3D_landmarks[42]
    re_outer = anthropometic_3D_landmarks[36]
    re_inner = anthropometic_3D_landmarks[39]

    le_center = (le_inner + le_outer) / 2.0
    le_center = np.reshape(le_center, (1, 3))
    re_center = (re_inner + re_outer) / 2.0
    re_center = np.reshape(re_center, (1, 3))

    face_model_scaling = 65.0 / np.linalg.norm(le_center - re_center)
    anthropometic_3D_landmarks *= face_model_scaling
    le_center *= face_model_scaling
    re_center *= face_model_scaling

    # Selected landmarks to solve the pnp algorithm
    landmarks_2D_set_selected = []
    landmarks_3D_selected = []

    landmarks_2D_set_selected = [26, 22, 21, 17, 45, 42, 39, 36, 35, 31, 54, 48, 57, 8]
    for ind in landmarks_2D_set_selected:
        landmarks_3D_selected.append(anthropometic_3D_landmarks[ind])
    
    landmarks_3D_selected = np.asarray(landmarks_3D_selected, dtype=float)

    return landmarks_3D_selected, landmarks_2D_set_selected, le_center, re_center


def load_cam_intrinsics(config_path):
    """Load camera intrinsic parameters.

    Args:
        config_path: path to the config folder
    Return:
        cam (array): camera matrix
        dist (array): distortion parameters
    """
    filename = os.path.join(config_path, 'camera_parameters.txt')
    assert os.path.isfile(filename)

    with open(filename, 'r') as dataf:
        lines = dataf.readlines()

    cam = []
    dist = []
    idx = 0
    while idx < 3:
        cam.append(list(map(float, lines[idx].split(','))))
        idx += 1
    # to skip the blank line
    idx += 1
    while idx < len(lines):
        dist.append(float(lines[idx]))
        idx += 1

    assert len(cam) == 3
    assert len(dist) >= 5

    return np.asarray(cam, dtype=np.float32), np.asarray(dist, dtype=np.float32)


def get_landmarks_dict(json_file_folder):
    """Get landmarks dictionary.

    Args:
        json_file_folder: input json file folder
    Return:
        landmarks_dict (dict): dictionary of the landmarks from data factory labels in json
    """
    assert os.path.isdir(json_file_folder)
    landmarks_dict = dict()
    json_list = os.listdir(json_file_folder)
    for json_file in json_list:
        json_file_name = os.path.join(json_file_folder, json_file)
        try:
            with open(json_file_name, 'r') as f_json:
                json_reader = json.load(f_json)
        except Exception:
            print('Json file improperly formatted')

        for frame_json in json_reader:
            if 'annotations' not in frame_json:
                continue
            frame_name = frame_json['filename']
            lm = extract_landmarks_from_json(frame_json['annotations'])
            landmarks_dict[frame_name] = lm
    return landmarks_dict


def get_landmarks_correpondence(landmarks_3D, landmarks_2D, landmarks_2D_set):
    """Get corresponding 2D and 3D landmarks
       Prepare landmarks before computing the PnP

    Args:
        landmarks_3D (array): 3D landmarks on a face model
        landmarks_2D (array): 2D landmarks from data factory labels
        landmarks_2D_set (array): 2D landmarks index that corresponds to the 3D landmarks
    Return:
        landmarks_2D_final (array): filtered 2D landmarks
        landmarks_3D_final (array): filtered 3D landmarks
    """

    landmarks_2D_final = []
    landmarks_3D_final = []
    for i in range(len(landmarks_2D_set)):
        landmarks_2D_final.append(landmarks_2D[landmarks_2D_set[i]])
        landmarks_3D_final.append(landmarks_3D[i])

    landmarks_2D_final = np.asarray(landmarks_2D_final, dtype=float)
    landmarks_3D_final = np.asarray(landmarks_3D_final, dtype=float)
    return landmarks_2D_final, landmarks_3D_final


def compute_EPnP(points_3D, points_2D, camera_mat, distortion_coeffs):
    """Compute rotation and translation of head

    Args:
        points_3D (array): 3D landmarks points
        points_2D (array): 2D landmarks points
        camera_mat (array): camera matrix
        distortion_coeffs (array): camera distortion

    Return:
        retval (int): return status value from OpenCV solvePnP
        rvec (array): rotation of the head
        tvec (int): translation of the head
    """
    points_2D = np.expand_dims(points_2D, axis=1)
    points_3D = np.expand_dims(points_3D, axis=1)
    # Refer to this for the solvePnP function: 
    # https://docs.opencv.org/3.4/d9/d0c/group__calib3d.html#ga549c2075fac14829ff4a58bc931c033d
    retval, rvec, tvec = cv2.solvePnP(points_3D, points_2D, camera_mat,\
                                      distortion_coeffs, None, None, False, 1)
    return retval, rvec, tvec


def projectObject2Camera(object_coords, rot_mat, tvec):
    """Project object coordinates (WCS) to camera coordinates (CCS)

    Args:
        object_coords (array): object coordinates
        rot_mat (array): rotation matrix
        tvec (array): translation vector

    Return:
        cam_coords (array): camera coordinate
    """
    RPw = rot_mat.dot(object_coords.transpose())
    cam_coords = RPw + tvec
    return cam_coords


def projectCamera2Image(cam_coords, cam_mat):
    """Project cam coordinates (CCS) to image coordinates (ICS)

    Args:
        cam_coords (array): camera coordinates
        cam_mat (array): camera matrix

    Return:
        image_coords (array): image coordinate
    """

    image_coords = np.matmul(cam_mat, cam_coords)
    assert image_coords[2] > 0
    image_coords /= image_coords[2]
    return image_coords


def extract_fiducial_points(chunk):
    """Extract fiducial landmarks points from a chunk in the label file

    Args:
        chunk (array): a chunk in the json labeling file

    Return:
        x (array): 2D landmarks x coordinate
        y (array): 2D landmarks y coordinate
        occlusions (array): occlusions arrays
        num_landmarks (int): number of landmarks points
    """

    x = [-1] * NUM_JSON_LANDMARKS
    y = [-1] * NUM_JSON_LANDMARKS
    occlusions = [-1] * NUM_JSON_LANDMARKS
    num_landmarks = None

    for point in (point for point in chunk if ('class' not in point and 'version' not in point)):
        try:
            number = int(''.join(c for c in str(point) if c.isdigit()))

            if num_landmarks is None or number > num_landmarks:
                num_landmarks = number

            if 'x' in str(point).lower() and number <= NUM_JSON_LANDMARKS:
                x[number - 1] = str(np.float(chunk[point]))
            if 'y' in str(point).lower() and number <= NUM_JSON_LANDMARKS:
                y[number - 1] = str(np.float(chunk[point]))
            if ('occ' in str(point).lower() and number <= NUM_JSON_LANDMARKS and chunk[point]):
                occlusions[number - 1] = 1

            for index in range(num_landmarks):
                if occlusions[index] == -1:
                    occlusions[index] = 0

        except Exception as e:
            print('Exception occured during parsing')
            print(str(e))
            print(str(point))

    return x, y, occlusions, num_landmarks


def extract_landmarks_from_json(json_frame_dict):
    """Extract landmarks form a label file

    Args:
        json_frame_dict (dict): dictionary of a json label file

    Return:
        landmarks_2D (array): if successful, return 2D facial landmarks
                              otherwise, return None
    """
    for chunk in json_frame_dict:
        if 'class' not in chunk:
            continue

        chunk_class = str(chunk['class']).lower()
        if chunk_class == 'fiducialpoints':
            x, y, occlusions, num_landmarks = extract_fiducial_points(chunk)
            landmarks_2D = np.asarray([x, y], dtype=np.float).T
            return landmarks_2D
    return None


def load_frame_gray(frame_path):
    """Load a frame and convert to grayscale

    Args:
        frame_path: parth to the image

    Return:
        frame (array): if successful, return a loaded frame in gray scale
                       otherwise, return None
    """
    if os.path.isfile(frame_path):
        frame = cv2.imread(frame_path, 0)
        assert frame.shape[0] > 0 and frame.shape[1] > 0
        return frame
    else:
        print(frame_path, 'does not exist!')
        return None


def visualize_frame(frame_path, landmarks_2D, cam_coord, calib):
    """visualize gaze vector in a frame

    Args:
        frame_path (array): a chunk in the json labeling file
        landmarks_2D (array): 2D landmarks
        cam_coord (array): camera coordinate
        calib (list): camera calibration parameters
    """
    # Eliminate occluded landmarks
    landmarks_3D_selected, landmarks_2D_set_selected, le_center, re_center = get_landmarks_info()
    landmarks_2D_final, landmarks_3D_final = get_landmarks_correpondence(landmarks_3D_selected, landmarks_2D,
                                                                         landmarks_2D_set_selected)

    # Compute PnP between the generic 3D face model landmarks (WCS) and 2D landmarks (ICS)
    # Rotation and translation vectors for 3D-to-2D transformation
    camera_mat = calib['cam']
    distortion_coeffs = calib['dist']
    _, rvec, tvec = compute_EPnP(landmarks_3D_final, landmarks_2D_final, camera_mat, distortion_coeffs)

     # Compute head pose angles (euler)
    rot_mat = cv2.Rodrigues(rvec)[0]
    leye_cam_mm = projectObject2Camera(le_center, rot_mat, tvec).reshape(-1)
    leye_gaze_vec = cam_coord - leye_cam_mm
    leye_gaze_vec /= np.sqrt(leye_gaze_vec[0] ** 2 + leye_gaze_vec[1] ** 2 + leye_gaze_vec[2] ** 2)

    reye_cam_mm = projectObject2Camera(re_center, rot_mat, tvec).reshape(-1)
    reye_gaze_vec = cam_coord - reye_cam_mm
    reye_gaze_vec /= np.sqrt(reye_gaze_vec[0] ** 2 + reye_gaze_vec[1] ** 2 + reye_gaze_vec[2] ** 2)

    le_pc_image_px = (landmarks_2D[42] + landmarks_2D[45]) / 2.0
    le_pc_image_px_hom = np.ones(shape=(3, 1), dtype=float)
    le_pc_image_px_hom[0] = le_pc_image_px[0]
    le_pc_image_px_hom[1] = le_pc_image_px[1]

    re_pc_image_px = (landmarks_2D[36] + landmarks_2D[39]) / 2.0
    re_pc_image_px_hom = np.ones(shape=(3, 1), dtype=float)
    re_pc_image_px_hom[0] = re_pc_image_px[0]
    re_pc_image_px_hom[1] = re_pc_image_px[1]

    # Draw gaze
    # gaze_vector_length: define the length of the line going out off the eyes in visualization
    gaze_vector_length = 100
    gaze_le_ap_cam_mm = leye_cam_mm + (leye_gaze_vec * gaze_vector_length)
    gaze_le_ap_pc_px = projectCamera2Image(gaze_le_ap_cam_mm, camera_mat)

    le_pc_image_px = [int(le_pc_image_px[0]), int(le_pc_image_px[1])]
    gaze_le_ap_pc_px = [int(gaze_le_ap_pc_px[0]), int(gaze_le_ap_pc_px[1])]

    gaze_re_ap_cam_mm = reye_cam_mm + (reye_gaze_vec * gaze_vector_length)
    gaze_re_ap_pc_px = projectCamera2Image(gaze_re_ap_cam_mm, camera_mat)

    re_pc_image_px = [int(re_pc_image_px[0]), int(re_pc_image_px[1])]
    gaze_re_ap_pc_px = [int(gaze_re_ap_pc_px[0]), int(gaze_re_ap_pc_px[1])]

    display_frame = load_frame_gray(frame_path)
    display_frame = cv2.cvtColor(display_frame,cv2.COLOR_GRAY2RGB)

    return display_frame, le_pc_image_px, gaze_le_ap_pc_px, re_pc_image_px, gaze_re_ap_pc_px
