# Copyright (c) 2017-2020, NVIDIA CORPORATION.  All rights reserved.

"""Script to transform Wider face dataset to kitti format for Facenet tutorial."""

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import argparse
import os
import cv2
import numpy as np


def letterbox_image(image, target_size):
    """Resize image preserving aspect ratio using padding.

    Args:
        image (numpy.ndarray): Input image to be resized
        target_size (tuple): Target image dimensions in (H,W,C) format.

    Return:
        new_image (numpy.ndarray): Output Image post resize.
        scale (float): Scale factor of resize.
        dx (int): Padding along x dimension to main aspect ratio.
        dy (int): Padding along y dimension to main aspect ratio.
    """
    iw, ih = image.shape[0:2][::-1]
    w, h = target_size[1], target_size[0]
    scale = min(float(w)/float(iw), float(h)/float(ih))
    nw = int(iw*scale)
    nh = int(ih*scale)
    image = cv2.resize(image, (nw, nh), interpolation=cv2.INTER_CUBIC)
    new_image = np.zeros(target_size,  dtype=np.uint8)
    dx = (w-nw)//2
    dy = (h-nh)//2
    new_image[dy:dy+nh, dx:dx+nw, :] = image
    return new_image, scale, dx, dy


def adjust_box_coords(x1, y1, x2, y2, scale, dx, dy, image_height, image_width):
    """Adjust bounding box coordinates based on resize.

    Args:
        x1 (int): Top left x-coordinate of bounding box before resize.
        y1 (int): Top left y-coordinate of bounding box before resize.
        x2 (int): Bottom right x-coordinate of bounding box before resize.
        y2 (int): Bottom right y-coordinate of bounding box before resize.
        scale (int): Scale factor of resize.
        dx (int): Padding along x dimension to main aspect ratio.
        dy (int): Padding along y dimension to main aspect ratio.
        image_height (int): Height of resized image.
        image_width (int): Width of resized image.

    Return:
        x1 (int): Top left x-coordinate of bounding box after resize.
        y1 (int): Top left y-coordinate of bounding box after resize.
        x2 (int): Bottom right x-coordinate of bounding box after resize.
        y2 (int): Bottom right y-coordinate of bounding box after resize.
    """
    x1 = (int(dx + x1*scale))
    x1 = min(max(x1, 0), image_width)
    y1 = (int(dy + y1*scale))
    y1 = min(max(y1, 0), image_height)
    x2 = (int(dx + x2*scale))
    x2 = min(max(x2, 0), image_width)
    y2 = (int(dy + y2*scale))
    y2 = min(max(y2, 0), image_height)

    return x1, y1, x2, y2


def parse_args(args=None):
    """parse the arguments."""
    parser = argparse.ArgumentParser(description='Transform Wider dataset for Facenet tutorial')

    parser.add_argument(
        "--input_image_dir",
        type=str,
        required=True,
        help="Input directory to Wider dataset images."
    )

    parser.add_argument(
        "--input_label_file",
        type=str,
        required=True,
        help="Input path to Wider dataset labels."
    )

    parser.add_argument(
        "--output_dir",
        type=str,
        required=True,
        help="Ouput directory to TLT dataset."
    )

    parser.add_argument(
        "--image_height",
        type=int,
        required=True,
        help="Height of output image."
    )

    parser.add_argument(
        "--image_width",
        type=int,
        required=True,
        help="Width of output image."
    )

    parser.add_argument(
        "--grayscale",
        required=False,
        action='store_true',
        help='Convert images to grayscale.'
    )

    return parser.parse_args(args)


def main(args=None):
    """Main function for data preparation."""

    args = parse_args(args)

    target_img_path = os.path.join(args.output_dir, "images")
    target_label_path = os.path.join(args.output_dir, "labels")
    target_size = (args.image_height, args.image_width, 3)

    if not os.path.exists(target_img_path):
        os.makedirs(target_img_path)
    else:
        print("This script will not run as output image path already exists.")
        return

    if not os.path.exists(target_label_path):
        os.makedirs(target_label_path)
    else:
        print("This script will not run as output label path already exists.")
        return

    # read wider ground truth file
    fd_gt_file  = os.path.join(args.input_label_file)
    f = open(fd_gt_file, 'r')
    fd_gt = f.readlines()
    f.close()

    total_cnt = 0
    i = 0
    image_name = None
    while i < len(fd_gt):
        line = fd_gt[i].strip()
        if "jpg" in line:
            # start of new image
            total_cnt += 1
            image_name = line
            image_prefix = image_name.split("/")[-1].split(".")[0]
            image_path = os.path.join(args.input_image_dir, line)

            if not os.path.exists(image_path):
                print("Error reading image, Please check data")
                return

            # Transform Image
            img = cv2.imread(image_path)
            new_image, scale, dx, dy = letterbox_image(img, target_size)
            if args.grayscale:
                new_image = cv2.cvtColor(new_image, cv2.COLOR_BGR2GRAY)
                new_image = np.expand_dims(new_image, axis=-1)
                new_image = np.repeat(new_image, 3, axis=-1)

            i += 1
            num_bbox_in_image = int(fd_gt[i].strip())
            i += 1
            labels = []
            for k in range(num_bbox_in_image):
                label = fd_gt[i].strip()
                label_parts = label.split(" ")
                kitti_output = [0]*15
                kitti_output[0] = "face"
                kitti_output[2] = label_parts[8]
                x1 = int(label_parts[0])
                y1 = int(label_parts[1])
                x2 = int(label_parts[2]) + x1
                y2 = int(label_parts[3]) + y1
                x1, y1, x2, y2 = adjust_box_coords(
                    x1, y1, x2, y2, scale, dx, dy, args.image_height, args.image_width)
                kitti_output[4:8] = x1, y1, x2, y2
                kitti_output = [str(x) for x in kitti_output]
                labels.append(" ".join(kitti_output))
                i += 1

            if len(labels) != num_bbox_in_image:
                print("Error parsing label, skipping")
                continue

            # save image and label
            cv2.imwrite(os.path.join(target_img_path, image_prefix+".png"), new_image)
            # save label
            with open(os.path.join(target_label_path, image_prefix+".txt"), 'w') as f:
                for item in labels:
                    f.write("%s\n" % item)

        elif set(line.split(" ")) == {'0'}:
            # no faces in image, continuing
            i += 1

        else:
            print("Error parsing labels, Please check data")
            return

    print("Total {} samples in dataset".format(total_cnt))

if __name__ == "__main__":
    main()
