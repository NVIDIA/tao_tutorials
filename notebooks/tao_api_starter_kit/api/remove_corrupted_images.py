import json
import requests
import time

def remove_corrupted_images_workflow(base_url, headers, workspace_id, dataset_id):
    """Workflow to call Data-Services action to move out corrupted images"""

    # Get default spec schema
    endpoint = f"{base_url}/datasets/{dataset_id}/specs/validate_images/schema"
    response = requests.get(endpoint, headers=headers)
    assert response.status_code in (200, 201)
    specs = response.json()["default"]

    # Run action
    parent = None
    action = "validate_images"
    data = json.dumps({"parent_job_id":parent,"action":action,"specs":specs})
    endpoint = f"{base_url}/datasets/{dataset_id}/jobs"
    response = requests.post(endpoint, data=data, headers=headers)
    assert response.status_code in (200, 201)
    assert response.json()
    job_id = response.json()

    # Monitor job
    endpoint = f"{base_url}/datasets/{dataset_id}/jobs/{job_id}"
    while True:    
        response = requests.get(endpoint, headers=headers)
        if "error_desc" in response.json().keys() and response.json()["error_desc"] in ("Job trying to retrieve not found", "No AutoML run found"):
            print("Job is being created")
            time.sleep(5)
            continue
        assert "status" in response.json().keys() and response.json().get("status") != "Error"
        if response.json().get("status") in ["Done","Error", "Canceled"] or response.status_code not in (200,201):
            break
        time.sleep(15)

    return job_id
