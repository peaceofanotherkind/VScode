import boto3
import os
import logging
import json

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


def share_ami(ami_id, accounts):
    for account in accounts["Accounts"]:
        print(account)
        response = client.modify_image_attribute(
            Attribute=('launchPermission'),
            ImageId=ami_id,
            LaunchPermission={
                'Add': [{'UserId': account['Id']}]
            }
        )
        print(response)


def assume_role(aws_account_number, role_name):
    """
    Assumes the provided role in each account and returns a session object
    :param aws_account_number: AWS Account Number
    :param role_name: Role to assume in target account
    :param aws_region: AWS Region for the Client call
    :return: Session object for the specified AWS Account and Region
    """
    sts_client = boto3.client("sts")
    partition = sts_client.get_caller_identity()["Arn"].split(":")[1]
    current_account = sts_client.get_caller_identity()["Arn"].split(":")[4]
    if aws_account_number == current_account:
        LOGGER.info("Using existing session for %s." % (aws_account_number))
        return session
    else:
        response = sts_client.assume_role(
            RoleArn="arn:%s:iam::%s:role/%s"
            % (partition, aws_account_number, role_name),
            RoleSessionName="GoldenAmiShare",
        )
        sts_session = boto3.Session(
            aws_access_key_id=response["Credentials"]["AccessKeyId"],
            aws_secret_access_key=response["Credentials"]["SecretAccessKey"],
            aws_session_token=response["Credentials"]["SessionToken"],
        )
        LOGGER.info("Assumed session for %s." % (aws_account_number))
        return sts_session


def list_accounts(remote_session):
    org_master_client = remote_session.client("organizations")
    accounts = org_master_client.list_accounts()
    while "NextToken" in accounts:
        moreaccounts = org_master_client.list_accounts(NextToken=accounts["NextToken"])
        for acct in accounts["Accounts"]:
            moreaccounts["Accounts"].append(acct)
        accounts = moreaccounts
    return accounts


def handler(event, context):
    print(event)
    # print(event['Records'][0]['body'])
    body = json.loads(event['Records'][0]['body'])
    detail = body.get("detail")
    # print(detail['responseElements']['imageId'])
    ami_id = detail['responseElements']['imageId']
    remote_session = assume_role(
        os.environ["MasterAccountId"], os.environ["OrgAccountQueryRole"])
    accounts = list_accounts(remote_session)
    share_ami(ami_id, accounts)
