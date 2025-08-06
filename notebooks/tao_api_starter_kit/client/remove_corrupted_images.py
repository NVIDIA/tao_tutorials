import json
import subprocess
import time

def remove_corrupted_images_workflow(workspace_id, dataset_id):
    """Workflow to call Data-Services action to move out corrupted images"""

    model_name = "image"

    # Get default spec schema
    specs = subprocess.getoutput(f"tao-client {model_name} get-spec --action validate_images --job_type dataset --id {dataset_id}")
    specs = json.loads(specs)

    # Run action
    job_id = subprocess.getoutput(f"tao-client {model_name} dataset-run-action --action validate_images --id {dataset_id} --specs '{json.dumps(specs)}'")

    # Monitor job
    while True:
        response = subprocess.getoutput(f"tao-client {model_name} get-action-status --job_type dataset --id {dataset_id} --job {job_id}")
        response = json.loads(response)
        if "error_desc" in response.keys() and response["error_desc"] in ("Job trying to retrieve not found", "No AutoML run found"):
            print("Job is being created")
            time.sleep(5)
            continue
        assert "status" in response.keys() and response.get("status") != "Error"
        if response.get("status") in ["Done","Error"]:
            break
        time.sleep(15)

    return job_id
