import base64
import json
import logging
from google.cloud import iam_admin_v1
from google.cloud import logging as cloud_logging

# Initialize clients
iam_client = iam_admin_v1.IAMClient()
log_client = cloud_logging.Client()
log_client.setup_logging()

def respond_to_threat(event, context):
    """
    Cloud Function triggered by Pub/Sub message from SCC.
    Automatically disables compromised service accounts.
    """
    
    # Decode the Pub/Sub message
    pubsub_message = base64.b64decode(event['data']).decode('utf-8')
    finding = json.loads(pubsub_message)
    
    logging.info(f"Received SCC finding: {json.dumps(finding, indent=2)}")
    
    # Extract finding details
    try:
        category = finding.get('finding', {}).get('category', '')
        resource_name = finding.get('finding', {}).get('resourceName', '')
        severity = finding.get('finding', {}).get('severity', '')
        
        logging.info(f"Finding category: {category}, Severity: {severity}")
        
        # Respond to IAM anomaly findings
        if category in [
            'ANOMALOUS_IAM_GRANT',
            'SERVICE_ACCOUNT_SELF_INVESTIGATION', 
            'PERSISTENCE_IAM_ANOMALOUS_GRANT'
        ]:
            logging.warning(f"IAM threat detected: {category} on {resource_name}")
            
            # Extract service account from resource name
            # resource_name format: //iam.googleapis.com/projects/{project}/serviceAccounts/{email}
            if 'serviceAccounts' in resource_name:
                sa_email = resource_name.split('serviceAccounts/')[-1]
                disable_service_account(sa_email, category)
            else:
                logging.info(f"No service account to disable for finding: {category}")
        else:
            logging.info(f"Finding category {category} does not require automated response")
            
    except Exception as e:
        logging.error(f"Error processing finding: {str(e)}")
        raise

def disable_service_account(sa_email, reason):
    """
    Disables a compromised service account.
    """
    try:
        # Get project from service account email
        # email format: name@project-id.iam.gserviceaccount.com
        project_id = sa_email.split('@')[1].split('.iam.')[0]
        sa_name = f"projects/{project_id}/serviceAccounts/{sa_email}"
        
        logging.warning(f"Disabling compromised service account: {sa_email}")
        logging.warning(f"Reason: {reason}")
        
        # Disable the service account
        request = iam_admin_v1.DisableServiceAccountRequest(name=sa_name)
        iam_client.disable_service_account(request=request)
        
        logging.warning(
            f"SECURITY ACTION: Service account {sa_email} has been DISABLED. "
            f"Reason: {reason}. "
            f"Manual review required before re-enabling."
        )
        
    except Exception as e:
        logging.error(f"Failed to disable service account {sa_email}: {str(e)}")
        raise