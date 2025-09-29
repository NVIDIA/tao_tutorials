# TAO Docker Compose with Configurable Settings

This directory contains a Docker Compose setup for running TAO API with configurable settings and optional SeaweedFS integration.

## Prerequisites

Before setting up Docker Compose, you must configure the NGC API credentials:

### 1. Edit secrets.json

Create or edit the `secrets.json` file with your NGC API keys:

```json
{
  "ngc_api_key": "nvapi-xxxxxxxxxxxxx",
  "ptm_api_key": "your-legacy-api-key"
}
```

### 2. API Key Requirements

Both API keys can be generated at: [NGC API Keys Portal](https://org.ngc.nvidia.com/setup/api-keys)

- **ngc_api_key**: Your NGC Personal API Key (starts with `nvapi-`)
  - Required for authentication and downloading models from your organization
  
- **ptm_api_key**: NGC Legacy API Key 
  - Used for accessing pre-trained models from organizations that your personal key cannot access
  - Found in the "Legacy keys" section at the bottom of the page

> **Security Note**: Keep `secrets.json` secure and never commit it to version control

## API Endpoints

The TAO API endpoints are available at:

```
{base_url}/api/v1/{ngc_org_name}/
```

Where:
- **base_url**: `http://localhost:8090` (or your configured NGINX_HTTP_PORT at config.env)
- **ngc_org_name**: Your NGC organization name

**Example endpoints:**
- Workspaces: `http://localhost:8090/api/v1/your-org/workspaces`
- Experiments: `http://localhost:8090/api/v1/your-org/experiments`
- Datasets: `http://localhost:8090/api/v1/your-org/datasets`

## Quick Start

1. **Default setup (TAO API only):**
   ```bash
   ./run.sh up
   ```

2. **With SeaweedFS storage:**
   ```bash
   ./run.sh up-all
   ```

3. **With custom settings:**
   ```bash
   ./run.sh up --airgapped --python=3.11
   ```

## Configuration

### Settings File: `config.env`

All settings are controlled through the `config.env` file. Key configurable options:

- **AIRGAPPED_MODE**: Enable/disable airgapped mode (`true`/`false`)
- **PTM_PULL**: Enable/disable pretrained models pull (`true`/`false`)
- **PYTHON_VERSION**: Python version for main services (e.g., `3.12`)
- **DEBUG_MODE**: Enable debug mode (`true`/`false`)
- **DEPLOYMENT_MODE**: Deployment mode (`PROD`/`DEV`)
- **IMAGE_TAG**: Docker image tag for services
- **SEAWEEDFS_ENABLED**: Enable SeaweedFS integration (`true`/`false`)

### Command Line Overrides

You can override config.env settings via command line:

```bash
./run.sh up --airgapped           # Enable airgapped mode
./run.sh up --no-airgapped        # Disable airgapped mode
./run.sh up --ptm                 # Enable pretrained models pull
./run.sh up --no-ptm              # Disable pretrained models pull
./run.sh up --python=3.11         # Use Python 3.11
./run.sh config                   # Show current configuration
```

## Available Commands

- `./run.sh up` - Start TAO API services (PTM pull based on config)
- `./run.sh up-all` - Start all services including SeaweedFS
- `./run.sh down` - Stop all services (including all profiles)
- `./run.sh restart` - Restart services
- `./run.sh logs` - Show service logs
- `./run.sh status` - Show service status
- `./run.sh config` - Show current configuration

**Note**: The `down` command automatically stops all services including those in profiles (SeaweedFS, PTM) to ensure a clean shutdown regardless of how services were started.

## Services

### TAO API Services (Always Available)
- **mongodb**: Database backend
- **tao_api_app**: Main TAO API application (http://localhost)
- **tao_api_workflow**: Workflow management service
- **nginx**: Reverse proxy

### Optional Services
- **tao_api_pretrained_models**: Pretrained models initialization (enabled via PTM_PULL setting)

### SeaweedFS Services (Optional)
- **seaweedfs-master**: Cluster coordination (http://localhost:9333)
- **seaweedfs-volume**: Storage backend
- **seaweedfs-filer**: File system interface (http://localhost:8888)
- **seaweedfs-s3**: S3-compatible API (http://localhost:8333)

## Environment Variables

The system supports these configuration approaches (in order of precedence):

1. **Command line overrides** (`--airgapped`, `--ptm`, `--python=X.Y`)
2. **Environment variables** (`export AIRGAPPED_MODE=true PTM_PULL=false`)
3. **config.env file** (default settings)
4. **Built-in defaults** (fallback values)

## Examples

```bash
# Basic TAO API setup (no PTM pull by default)
./run.sh up

# With pretrained models pull
./run.sh up --ptm

# Full setup with storage and PTM
./run.sh up-all --ptm

# Airgapped setup (typically without PTM)
./run.sh up-all --airgapped --no-ptm

# Check what settings are active
./run.sh config
```

## Loading Base Experiments in Air-Gapped Environments

For air-gapped environments where internet access is limited, you can load pre-packaged base experiments (pretrained models) from local cloud storage into the TAO database.

### Prerequisites

1. **TAO API services running** - Ensure services are up with SeaweedFS storage:
   ```bash
   ./run.sh up-all  # Includes SeaweedFS for storage
   ```

2. **Base experiments data** - You need to prepare and transfer model data:

   #### Step 1: Prepare Models (Internet-Connected Machine)

   On a machine with internet access, download the required NGC models using one of three modes:

   ```bash
   # Clone the nvidia-tao-core repository
   git clone https://github.com/NVIDIA/nvidia-tao-core.git
   cd nvidia-tao-core/nvidia_tao_core/microservices
   ```

   **Option 1: Auto-Discovery Mode (Recommended)**
   Automatically downloads all available models from specified organizations:

   ```bash
   # Download all models from nvidia/tao organization
   AIRGAPPED_MODE=True PTM_API_KEY=<legacy key> PYTHONPATH=<Path to cloned tao-core repo> python pretrained_models.py \
     --org-teams "nvidia/tao" \
     --ngc-key "<Personal Key>" \
     --shared-folder-path ./airgapped-models

   # Or auto-discover all accessible organizations
   AIRGAPPED_MODE=True PTM_API_KEY=<legacy key> PYTHONPATH=<Path to cloned tao-core repo> python pretrained_models.py \
     --ngc-key "<Personal Key>" \
     --shared-folder-path ./airgapped-models
   ```

   **Option 2: CSV File Mode (Selective)**
   Download specific models listed in the predefined CSV file:

   ```bash
   # Edit the CSV file to customize your model selection
   # CSV file location: nvidia_tao_core/microservices/pretrained_models.csv
   # CSV format: displayName,ngc_path,network_arch

   # Download specific models from CSV file
   AIRGAPPED_MODE=True PTM_API_KEY=<legacy key> PYTHONPATH=<Path to cloned tao-core repo> python pretrained_models.py \
     --use-csv \
     --ngc-key "<Personal Key>" \
     --shared-folder-path ./airgapped-models
   ```

   **Option 3: Model Names Mode (By Architecture)**
   Download models by matching specific architecture names:

   ```bash
   # Download specific model architectures
   AIRGAPPED_MODE=True PTM_API_KEY=<legacy key> PYTHONPATH=<Path to cloned tao-core repo> python pretrained_models.py \
     --model-names "classification_pyt,dino,segformer,centerpose" \
     --ngc-key "<Personal Key>" \
     --shared-folder-path ./airgapped-models
   ```

   **Option 4: Combined Mode**
   Use both CSV file and auto-discovery together:

   ```bash
   # Download models from both CSV file AND NGC auto-discovery
   AIRGAPPED_MODE=True PTM_API_KEY=<legacy key> PYTHONPATH=<Path to cloned tao-core repo> python pretrained_models.py \
     --use-both \
     --org-teams "nvidia/tao" \
     --ngc-key "<Personal Key>" \
     --shared-folder-path ./airgapped-models
   ```

   **Verify download completed successfully**

   ```bash
   ls -la airgapped-models/
   # Should contain: ptm_metadatas.json (metadata file) and model directories
   ```

   **CSV File Format (Option 2):**
   The CSV file uses the following format with headers:

   ```csv
   displayName,ngc_path,network_arch
   TAO Pretrained EfficientDet TF2,nvidia/tao/pretrained_efficientdet_tf2:efficientnet_b0,efficientdet_tf2
   PoseClassificationNet,nvidia/tao/poseclassificationnet:trainable_v1.0,pose_classification
   Pointpillars,nvidia/tao/pointpillarnet:trainable_v1.0,pointpillars
   ```

   The CSV file supports multiple model sources:

   ```csv
   # NGC models (explicit prefix)
   DINO Object Detection,ngc://nvidia/tao/pretrained_dino:trainable_v1.0,dino

   # NGC models (implicit - default behavior)
   Classification Model,nvidia/tao/pretrained_classification:resnet18,classification_pyt

   # Hugging Face models
   DinoV2 Model,hf_model://microsoft/DinoV2:main,classification_pyt
   DETR Model,hf_model://facebook/detr-resnet-50:main,dino
   ```

   **Supported Prefixes:**
   - `ngc://` (or no prefix): NGC models from NVIDIA's catalog
   - `hf_model://`: Hugging Face models from HuggingFace Hub

   **Model Names Format (Option 3):**

   Use comma-separated architecture names like: `classification_pyt`, `nvdinov2`, `dino`, `segformer`, `mask2former`, `pointpillars`

   #### Step 2: Transfer to Air-Gapped Environment

   Transfer the downloaded models to your air-gapped environment:

   ```bash
   # Create a compressed archive for efficient transfer
   tar -czf airgapped-models.tar.gz airgapped-models/

   # Transfer to air-gapped machine (example methods)
   # Via USB/external media:
   cp airgapped-models.tar.gz /media/usb-drive/

   # Via secure file transfer (if available):
   scp airgapped-models.tar.gz user@airgapped-host:/path/to/models/

   # Extract on air-gapped machine
   tar -xzf airgapped-models.tar.gz
   ```

   #### Step 3: Upload to SeaweedFS

   Once in your air-gapped environment with TAO services running:

   ```bash
   # Start TAO services with SeaweedFS
   ./run.sh up-all --no-ptm

   # Untar the transferred file and Upload the entire airgapped-models directory to SeaweedFS
   # You can use the SeaweedFS web interface (http://localhost:8888) or CLI tools
   # Example using curl to upload via S3 API:

   # Create a new S3 local bucket

   aws s3 mb --endpoint-url http://<MACHINE IP>:8333 s3://tao-storage

   # Upload models using aws-cli (if available) or direct HTTP
   # The exact upload method depends on your preferred tooling

   # This directory that is being used on S3 to copied to is the one that should be present on LOCAL_MODEL_REGISTRY in config.env
   aws s3 cp --endpoint-url http://<MACHINE IP>:8333 ~/airgapped-models/ s3://tao-storage/shared-storage/ptm/airgapped-models/ --recursive
      ```

   **Host URL Configuration**

   Before loading model metadata, configure the base URL for your TAO API service:

   ```python
   # Construct the base URL using the NGINX_HTTP_PORT from config.env
   # Default port is 8090, but check your config.env file for the actual value
   base_url = "http://localhost:8090"  # Replace 8090 with your NGINX_HTTP_PORT if different
   
   # Alternative: Read from config.env programmatically
   # base_url = f"http://localhost:{NGINX_HTTP_PORT}"
   ```

     **Basic Loading**

   Once your services are running and you have the model data in SeaweedFS, load the model metadata using the FTMS API:

   ```python
   import requests
   
   # 1. Login to FTMS and create a SeaweedFS workspace
   # 2. Load base experiments into database
   endpoint = f"{base_url}/experiments:load_airgapped"
   data = {"workspace_id": workspace_id}
   response = requests.post(endpoint, headers=headers, json=data)
   ```

### Complete Workflow Example

```bash
# Air-gapped environment workflow:

# 0. Prepare Pre-trained models required for air-gapped experiments (on internet-connected machine)
AIRGAPPED_MODE=True PTM_API_KEY=<legacy key> PYTHONPATH=<Path to cloned tao-core repo> python pretrained_models.py \
  --use-csv \
  --ngc-key "<Personal Key>" \
  --shared-folder-path ./airgapped-models

# 1. Start all services including SeaweedFS
./run.sh up-all --no-ptm

# 2. Verify services are running
./run.sh status

# 3. Upload your pre-downloaded models and data to SeaweedFS
# (Use the method that works best for your environment)
aws s3 mb --endpoint-url http://<MACHINE IP>:8333 s3://tao-storage
aws s3 cp --endpoint-url http://<MACHINE IP>:8333 ~/airgapped-models/ s3://tao-storage/shared-storage/ptm/airgapped-models/ --recursive
aws s3 cp --endpoint-url http://<MACHINE IP>:8333 ~/data/ s3://tao-storage/data/ --recursive
# Ensure the airgapped-models/ directory with ptm_metadatas.json is uploaded
# 4. Login to TAO-API Service (refer notebook/documentation)
# 5. Create a cloud workspace (refer notebook/documentation) using following metadata
cloud_metadata = {
    "name": "AWS workspace info",
    "cloud_type": "seaweedfs",
    "cloud_specific_details": {
        "cloud_region": "us-east-1",
        "cloud_bucket_name": "tao-storage",
        "access_key": "seaweedfs",
        "secret_key": "seaweedfs123",
        "endpoint_url": "http://seaweedfs-s3:8333"
    }
}
import requests

# 6.1. Login to FTMS and create a SeaweedFS workspace
# 6.2. Load base experiments into database
endpoint = f"{base_url}/experiments:load_airgapped"
data = {"workspace_id": workspace_id}
response = requests.post(endpoint, headers=headers, json=data)
# Your TAO Toolkit air-gapped deployment using docker-compose is now ready for use!
```

## Docker Image Management with Save/Load Scripts

### Saving Images for Airgapped Deployment

The `save-docker-images.sh` script creates portable Docker image archives that can be transferred to airgapped environments.

#### Basic Usage

```bash
# Save all TAO images defined in config.env
./save-docker-images.sh

# Save to a custom directory
./save-docker-images.sh --output-dir=/path/to/images

# Force pull all images before saving
./save-docker-images.sh --pull

# Only save locally available images (no pulling)
./save-docker-images.sh --no-pull

# Overwrite existing files
./save-docker-images.sh --force
```

#### What It Does

1. **Reads config.env**: Automatically processes these image variables:
   - `IMAGE_TAO_API`
   - `IMAGE_TAO_PYTORCH`
   - `IMAGE_TAO_DEPLOY`
   - `IMAGE_VILA`
   - `IMAGE_TAO_DS`

2. **Creates portable archives**: Saves each image as a `.tar` file with parseable names

3. **Generates manifest.json**: Creates a mapping file for accurate image reference reconstruction

4. **Smart handling**: Automatically pulls missing images or skips based on your preferences

#### Example Output

```bash
$ ./save-docker-images.sh
TAO Docker Image Saver (Bundled, JSON manifest, no meta files)
==============================================================
Config:      config.env
Output dir:  ./saved-docker-images
Pull mode:   auto
Force save:  false

Images to process (5):
  nvcr.io/ea-tlt/tao_ea/tao-toolkit_5.2.0-deploy_2507_aut:latest
  nvcr.io/ea-tlt/tao_ea/tao-toolkit-pyt_2507_aut:latest
  nvcr.io/ea-tlt/tao_ea/tao-toolkit_5.2.0-deploy_2507_aut:latest
  nvcr.io/ea-tlt/tao_ea/vila_fine_tuning_inf:latest
  nvcr.io/ea-tlt/tao_ea/tao-toolkit-ds_v5.2.0_2507_inf:latest

[1/5] nvcr.io/ea-tlt/tao_ea/tao-toolkit_5.2.0-deploy_2507_aut:latest
  Status: Found locally
  Saving -> ./saved-docker-images/nvcr.io__ea-tlt__tao_ea__tao-toolkit_5.2.0-deploy_2507_aut__t-latest.tar

[2/5] nvcr.io/ea-tlt/tao_ea/tao-toolkit-pyt_2507_aut:latest
  Status: Found locally
  Saving -> ./saved-docker-images/nvcr.io__ea-tlt__tao_ea__tao-toolkit-pyt_2507_aut__t-latest.tar

# ... continues for all images

================================
Saved:   5
Skipped: 0
Failed:  0
Manifest: ./saved-docker-images/manifest.json
```

### Loading Images in Airgapped Environment

The `load-docker-images.sh` script loads Docker images from the saved archives, automatically detecting duplicates.

#### Basic Usage

```bash
# Load all images from the default directory
./load-docker-images.sh

# Load from a custom directory
./load-docker-images.sh --input-dir=/path/to/images

# Force reload all images (even if they already exist)
./load-docker-images.sh --force

# Keep temporary files for debugging
./load-docker-images.sh --keep-temp
```

#### What It Does

1. **Scans for image files**: Finds `.tar` and `.tar.gz` files in the input directory

2. **Uses manifest.json**: If available, uses the manifest for accurate image reference mapping

3. **Fallback parsing**: If no manifest, intelligently parses filenames back to image references

4. **Duplicate detection**: Automatically skips images that already exist locally (unless `--force` is used)

5. **Smart loading**: Handles both compressed and uncompressed archives

#### Example Output

```bash
$ ./load-docker-images.sh
Found 5 image files:
  nvcr.io__ea-tlt__tao_ea__tao-toolkit_5.2.0-deploy_2507_aut__t-latest.tar
  nvcr.io__ea-tlt__tao_ea__tao-toolkit-pyt_2507_aut__t-latest.tar
  nvcr.io__ea-tlt__tao_ea__vila_fine_tuning_inf__t-latest.tar
  nvcr.io__ea-tlt__tao_ea__tao-toolkit-ds_v5.2.0_2507_inf__t-latest.tar

Processing: nvcr.io__ea-tlt__tao_ea__tao-toolkit_5.2.0-deploy_2507_aut__t-latest.tar
  Target ref: nvcr.io/ea-tlt/tao_ea/tao-toolkit_5.2.0-deploy_2507_aut:latest
  Loading...
  ✓ Loaded (tar)

Processing: nvcr.io__ea-tlt__tao_ea__tao-toolkit-pyt_2507_aut__t-latest.tar
  Target ref: nvcr.io/ea-tlt/tao_ea/tao-toolkit-pyt_2507_aut:latest
  Loading...
  ✓ Loaded (tar)

# ... continues for all images

================================================
Loading complete
Loaded:  5
Skipped: 0
Failed:  0
```

### Complete Workflow Example

#### Step 1: Save Images (Internet-connected machine)

```bash
# 1. Ensure config.env contains your TAO image definitions
cat config.env | grep IMAGE_

# 2. Save all TAO images
./save-docker-images.sh --pull

# 3. Verify files were created
ls -la saved-docker-images/
cat saved-docker-images/manifest.json
```

#### Step 2: Transfer to Airgapped Environment

```bash
# Transfer the entire saved-docker-images directory
scp -r saved-docker-images/ user@airgapped-host:/path/to/tao-deployment/
# OR
rsync -av saved-docker-images/ user@airgapped-host:/path/to/tao-deployment/
# OR use USB drive, etc.
```

#### Step 3: Load Images (Airgapped machine)

```bash
# 1. Navigate to your TAO deployment directory
cd /path/to/tao-deployment

# 2. Load all images
./load-docker-images.sh

# 3. Verify images are loaded
docker images | grep tao

# 4. Start TAO services
./run.sh up
```

