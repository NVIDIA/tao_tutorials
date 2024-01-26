# TAO Toolkit - Tutorials

* [Introduction](#Introduction)
* [Requirements](#Requirements)
	* [Hardware requirements](#Hardwarerequirements)
		* [Minimum system configuration](#Minimumsystemconfiguration)
		* [Recommended system configuration](#Recommendedsystemconfiguration)
	* [Software requirements](#Softwarerequirements)
* [Package Content](#PackageContent)
	* [File Hierarchy](#FileHierarchy)
* [Jupyter notebooks](#Jupyternotebooks)
* [Blogs](#Blogs)
* [License](#License)

## <a name='Introduction'></a>Introduction

TAO Toolkit is a Python package hosted on the NVIDIA Python Package Index. It interacts with lower-level
TAO dockers available from the NVIDIA GPU Accelerated Container Registry (NGC). The TAO containers
come pre-installed with all dependencies required for training. The output of the TAO workflow is a
trained model that can be deployed for inference on NVIDIA devices using DeepStream, TensorRT and Triton.

This repository contains the tutorial notebooks for installing and running TAO Toolkit.
The notebooks would allow you to leverage the simplicity and convenience of TAO to train, prune, retrian, quantize, export and run inference.

[TAO quick start video](https://www.nvidia.com/en-us/on-demand/session/other2022-tao/).

## <a name='Requirements'></a>Requirements

### <a name='Hardwarerequirements'></a>Hardware requirements

The following system configuration is recommended to achieve reasonable training performance with TAO Toolkit and supported models provided:

#### <a name='Minimumsystemconfiguration'></a>Minimum system configuration

* 8 GB system RAM
* 4 GB of GPU RAM
* 8 core CPU
* 1 NVIDIA GPU
* 100 GB of SSD space

#### <a name='Recommendedsystemconfiguration'></a>Recommended system configuration

* 32 GB system RAM
* 32 GB of GPU RAM
* 8 core CPU
* 1 NVIDIA GPU
* 100 GB of SSD space

TAO Toolkit is supported on discrete GPUs, such as A100, A40, A30, A2, A16, A100x, A30x, V100, T4, Titan-RTX and Quadro-RTX.

> Note: TAO Toolkit is not supported on GPU's before the Pascal generation

### <a name='Softwarerequirements'></a>Software requirements

| **Software**                     | **Version** | **Comment** |
| :--- | :--- | :-- |
| Ubuntu LTS                       | 20.04       ||
| python                           | >=3.6.9<3.7 | Not needed if you are using TAO API \(See #3 below\) |
| docker-ce                        | >19.03.5    | Not needed if you are using TAO API \(See #3 below\) |
| docker-API                       | 1.40        | Not needed if you are using TAO API \(See #3 below\) |
| `nvidia-container-toolkit`       | >1.3.0-1    | Not needed if you are using TAO API \(See #3 below\) |
| nvidia-container-runtime         | 3.4.0-1     | Not needed if you are using TAO API \(See #3 below\) |
| nvidia-docker2                   | 2.5.0-1     | Not needed if you are using TAO API \(See #3 below\) |
| nvidia-driver                    | >525.85     | Not needed if you are using TAO API \(See #3 below\) |
| python-pip                       | >21.06      | Not needed if you are using TAO API \(See #3 below\) |

## <a name='PackageContent'></a>Package Content

Download the TAO package which contains startup scripts, Jupyter notebooks and config files. <br>
TAO is supported on Google Colab; if you want to try on Colab, you can skip this step and directly scroll down to [#4 in the How to run TAO](#colab) section.

```bash
    ngc registry resource download-version "nvidia/tao/tao-getting-started:5.2.0"
    cd ./tao-getting-started_v5.2.0
```

### <a name='FileHierarchy'></a>File Hierarchy

```text
    setup
        |--> quickstart_launcher.sh
        |--> quickstart_api_bare_metal
        |--> quickstart_api_aws_eks
        |--> quickstart_api_azure_aks
        |--> quickstart_api_gcp_gke
    notebooks
        |--> tao_api_starter_kit
            |--> api
                |--> automl
                |--> end2end
                |--> dataset_prepare
            |--> client
                |--> automl
                |--> end2end
                |--> dataset_prepare
        |--> tao_launcher_starter_kit
            |--> dino
            |--> deformable_detr
            |--> ocdnet
            |-->  ...
```

## <a name='Jupyternotebooks'></a>Jupyter notebooks

All Notebooks and required spec files are provided in this package. The table below maps which notebook
to use for fine-tuning either a purpose-build models like PeopleNet or an open model architecture like
YOLO.

|**Purpose-built Model** | **Launcher CLI notebook** |
|:--|:--|
| ActionRecognitionNet | notebooks/tao_launcher_starter_kit/action_recognition_net/action_recognition_net.ipynb |
| Mask Auto Label | notebooks/tao_launcher_starter_kit/mal/mal.ipynb |
| OCRNet | notebooks/tao_launcher_starter_kit/ocrnet/ocrnet.ipynb |
| OCDNet | notebooks/tao_launcher_starter_kit/ocdnet/ocdnet.ipynb |
| Pointpillars | notebooks/tao_launcher_starter_kit/pointpillars/pointpillars.ipynb |
| PoseClassificationNet | notebooks/tao_launcher_starter_kit/pose_classification_net/poseclassificationnet.ipynb |
| ReIdentificationNet | notebooks/tao_launcher_starter_kit/re_identification_net/reidentificationnet.ipynb |
| CitySemSegFormer | notebooks/tao_launcher_starter_kit/segformer/segformer.ipynb |
<br>

|**Open model architecture**| **Jupyter notebook** |
|:--|:--|
| Deformable DETR | notebooks/tao_launcher_starter_kit/deformable_detr/deformable_detr.ipynb |
| DINO | notebooks/tao_launcher_starter_kit/dino/dino.ipynb |
| Image Classification | notebooks/tao_launcher_starter_kit/classification_pyt/classification_pyt.ipynb |
| Optical Inspection | notebooks/tao_launcher_starter_kit/optical_inspection/optical_inspection.ipynb |
| Segformer | notebooks/tao_launcher_starter_kit/segformer/segformer.ipynb |
<br>

## <a name='Blogs'></a>Blogs

[Train like a 'pro' with AutoML in TAO](TBD) <br>
[Deploy TAO on Azure ML](TBD) <br>
[Synthetic Data and TAO](https://developer.nvidia.com/blog/developing-and-deploying-ai-powered-robots-with-nvidia-isaac-sim-and-nvidia-tao/) <br>
[Action Recognition Blog](https://developer.nvidia.com/blog/developing-and-deploying-your-custom-action-recognition-application-without-any-ai-expertise-using-tao-and-deepstream/) <br>
[Real-time License Plate Detection](https://developer.nvidia.com/blog/creating-a-real-time-license-plate-detection-and-recognition-app/) <br>
[2 Pose Estimation: Part 1](https://developer.nvidia.com/blog/training-optimizing-2d-pose-estimation-model-with-tao-toolkit-part-1/) <br>
[Part 2](https://developer.nvidia.com/blog/training-optimizing-2d-pose-estimation-model-with-tao-toolkit-part-2/) <br>
[Building ConvAI with TAO Toolkit](https://developer.nvidia.com/blog/building-and-deploying-conversational-ai-models-using-tao-toolkit/) <br>

## <a name='License'></a>License

This project is licensed under the [Apache-2.0](./LICENSE) License.
