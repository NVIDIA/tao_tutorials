# Copyright (c) 2024, NVIDIA CORPORATION.  All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Copyright (c) 2022, NVIDIA CORPORATION.  All rights reserved.

import os
import sys


def drop_class(label_dir, classes):
    """drop label by class names."""
    labels = os.listdir(label_dir)
    labels = [os.path.join(label_dir, x) for x in labels]
    for gt in labels:
        print("Processing ", gt)
        with open(gt) as f:
            lines = f.readlines()
            lines_ret = []
            for line in lines:
                ls = line.strip()
                line = ls.split()
                if line[0] in classes:
                    print("Dropping ", line[0])
                    continue
                else:
                    lines_ret.append(ls)
        with open(gt, "w") as fo:
            out = '\n'.join(lines_ret)
            fo.write(out)


if __name__ == "__main__":
    drop_class(sys.argv[1], sys.argv[2].split(','))
