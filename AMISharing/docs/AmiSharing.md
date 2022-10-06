# AMI Sharing Lambda
## Introduction
This lambda will detect an event when an AMI is created in the Shared Services account and 
share it with every account in the org.  AMIs are created by Packer in the ImageManagement repo.

# Design
1. EventBridge rule is triggered by the criteria defined in the serverless.us-east-1.yml:
    The event will only trigger on AMI name starting with 'BSAM'. This is to filter out any other 
    AMIs from being shared that are created in the SS account.

    ```
    AmiBuilderCustomEvent:
      Type: "AWS::Events::Rule"
      Properties:
        Description: "AmiBuilder-Complete"
        EventPattern:
          source:
            - "aws.ec2"
          detail-type:
            - "AWS API Call via CloudTrail"
          detail:
            eventName:
              - "CreateImage"
            eventSource:
              - "ec2.amazonaws.com"
            requestParameters:
              name:
                - prefix: BSAM
    ```
2. The event will trigger an SNS topic to alert on AMI creation
3. The event will also send the event to an SQS queue
4. ami_sharing lambda function will process these alerts

# Source
/src/functions/ami_sharing.py

The lambda will get a list of accounts in the org and then share the ami with those accounts.
