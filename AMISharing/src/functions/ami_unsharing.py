import boto3
import os
import logging
from datetime import date, timedelta

client = boto3.client('ec2')
waiter = client.get_waiter('image_available')

# put lambda in shared services account and try to call it from there

LOGGER = logging.getLogger()
if "log_level" in os.environ:
    LOGGER.setLevel(os.environ["log_level"])
    LOGGER.info("Log level set to %s" % LOGGER.getEffectiveLevel())
else:
    LOGGER.setLevel(logging.INFO)
logging.getLogger("boto3").setLevel(logging.INFO)
logging.getLogger("botocore").setLevel(logging.INFO)

session = boto3.Session()


def lambda_handler(event, context):
    print(event)

    days_to_keep_ami = int(os.environ["DaysToKeepAmi"])
    date_expired = (date.today()-timedelta(days=days_to_keep_ami)).isoformat()

    # Get all AMIs that are bsam and are not shared to this account
    response = client.describe_images(
        Owners=['self'],
        Filters=[
            {
                'Name': 'name',
                'Values': ['BSAM*']
            }
        ]
    )
    LOGGER.info(response)
    # Loop through all the amis and unshare the ones that are expired
    for image in response['Images']:
        ami_name = image['Name']
        ami_creation_date = image['CreationDate']
        if ami_creation_date < date_expired:
            tags = image['Tags']
            retain_ami = False
            for tag in tags:
                # Check and see if tag RetainAMI is set to true
                if (tag.get('Key')).lower() == "retainami" and tag.get('Value').lower() == 'true':
                    retain_ami = True
            if retain_ami is False:
                LOGGER.info("%s is expired Created: %s" % (ami_name, ami_creation_date))
                # Remove share on AMI
                image_attribute_response = client.describe_image_attribute(
                    Attribute='launchPermission',
                    ImageId=image['ImageId']
                )
                LOGGER.info(image_attribute_response)
                for launch_permission in image_attribute_response['LaunchPermissions']:
                    LOGGER.info("%s - remove %s" % (ami_name, launch_permission['UserId']))
                    response = client.modify_image_attribute(
                        Attribute=('launchPermission'),
                        ImageId=image['ImageId'],
                        LaunchPermission={
                            'Remove': [{'UserId': launch_permission['UserId']}]
                        }
                    )
                    print(response)
            else:
                LOGGER.info("%s RetainAMI tag is set to True. AMI will still be shared") % (ami_name)
