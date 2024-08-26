# Copyright (c) 2021, NVIDIA CORPORATION.  All rights reserved.

import argparse
import numpy as np
import h5py
import cv2
import os
import csv

def build_command_line_parser(parser=None):
    """Build command line parser for dataset_convert.

    Args:
        parser (subparser): Provided from the wrapper script to build a chained
            parser mechanism.

    Returns:
        parser
    """

    if parser is None:
        parser = argparse.ArgumentParser(
            prog='process_cohface',
            description='Convert COHFACE into heartratenet api compatible dataset',
        )

    parser.add_argument('-i', '--input_path',
                        type=str,
                        required=True,
                        help='Input path for COHFACE, this is the root of the dataset')
    
    parser.add_argument('-o', '--output_path',
                        type=str,
                        required=True,
                        help = 'Output path for COHFACE, this is the root of the dataset')

    parser.add_argument('-start_subject_id', '--start_subject_id',
                        type=int,
                        required=True,
                        help = 'Start subject id for COHFACE')

    parser.add_argument('-end_subject_id', '--end_subject_id',
                        type=int,
                        required=True,
                        help = 'End subject id for COHFACE')

    parser.add_argument('-b', '--breathing_rate',
                        action = 'store_true',
                        default = False,
                        help = 'If true, processes the dataset for breathing rate, else exports heart rate')

    return parser


def parse_command_line(args=None):
    """Simple function to parse command line arguments.

    Args:
        args (list): List of strings used as command line arguments.

    Returns:
        args_parsed: Parsed arguments.
    """

    parser = build_command_line_parser()
    args_parsed = parser.parse_args()

    return args_parsed

def get_timestamp_from_video(video_filename):
    """get video timestamp.

    Args:
        video_filename (str): video filename

    Returns:
        timestamps(list of float): a list of timestamps for each frame in video
    """

    cap = cv2.VideoCapture(video_filename)
    fps = cap.get(cv2.CAP_PROP_FPS)
    timestamps = [cap.get(cv2.CAP_PROP_POS_MSEC) / 1000] # convert MSEC to SEC
    calc_timestamps = [0.0]
    while(cap.isOpened()):
        frame_exists, curr_frame = cap.read()
        if frame_exists:
            timestamps.append(cap.get(cv2.CAP_PROP_POS_MSEC) / 1000)
        else:
            break
    cap.release()
    return timestamps

def process_subject(path, output, breathing = False):
    """convert COHFACE data format for subject.

    Args:
        path (str): input dataset path
        output (str): output dataset path after format conversion
        breathing (bool): whether get heartrate signal or breathrate signal

    Returns:
        None
    """

    video_file = os.path.join(path, 'data.avi')
    vidcap = cv2.VideoCapture(video_file)
    fps = vidcap.get(cv2.CAP_PROP_FPS)
    timestamps = [vidcap.get(cv2.CAP_PROP_POS_MSEC) / 1000] # convert MSEC to SEC
    print(f'Processing {video_file}, fps {fps}')
    
    subject_file = h5py.File(os.path.join(path, 'data.hdf5'), 'r')

    #Processing video
    count = 0
    while vidcap.isOpened():
        success, image = vidcap.read()
        if success:
            cv2.imwrite(os.path.join(output, 'images', format(count,'04d')+'.bmp'), image)
            count+=1
            timestamps.append(vidcap.get(cv2.CAP_PROP_POS_MSEC) / 1000)
        else:
            break
    vidcap.release()

    #Processing image time stamps
    image_file = os.path.join(output,'image_timestamps.csv')
    with open(image_file, 'w') as file:
        header = ['ID','Time']
        writer = csv.DictWriter(file, fieldnames = header) 
        writer.writeheader()
        for frame, time in zip(range(count), timestamps):
            writer.writerow({'ID': frame,
                             'Time': time})
    
    pulse_time = subject_file['time']
    if breathing:
        pulse = subject_file['respiration']
    else:
        pulse = subject_file['pulse']

    #Processing pulse
    pulse_file = os.path.join(output,'ground_truth.csv')
    with open(pulse_file, 'w') as file:
        header = ['Time','PulseWaveform']
        writer = csv.DictWriter(file, fieldnames = header)
        writer.writeheader()
        for time, pulse_val in zip(pulse_time, pulse):
            writer.writerow({'Time': time,
                            'PulseWaveform': pulse_val})


def main(cl_args=None):
    """process cohface.

    Args:
        args(list): list of arguments to be parsed if called from another module.
    """

    args_parsed = parse_command_line(cl_args)

    input_path = args_parsed.input_path
    output_path = args_parsed.output_path
    start_subject_id = args_parsed.start_subject_id
    end_subject_id = args_parsed.end_subject_id
    breathing_flag = args_parsed.breathing_rate
    session_number = 4

    for sub in range(start_subject_id,end_subject_id):
        for fol in range(session_number):
            input_dir = os.path.join(input_path, str(sub), str(fol))
            output_dir = os.path.join(output_path, str(sub), str(fol))
            os.makedirs(os.path.join(output_dir,'images'))
            process_subject(input_dir, output_dir, breathing = breathing_flag)


if __name__ == '__main__':
    main()
