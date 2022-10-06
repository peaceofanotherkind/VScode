# AMI UNSharing Lambda
## Introduction
This lambda will go through each AMI and unshare it with the org after a specific amount of time has passed.

# Design

Use tag: RetainAMI:True to keep the AMI longer than six months.

The Serverless Framework code is as follows (refer to actual code for any updates):
```
amiUnSharing:
    handler: "src/functions/ami_unsharing.lambda_handler"
    role: GoldenAMISharingExecutionRole
    layers:
      - { Ref: PythonRequirementsLambdaLayer }
    memorySize: 512
    timeout: 900
    environment:
      DaysToKeepAmi: 183 #6 months plus a day for leap year
    events:
      - eventBridge:
          schedule: rate(30 days)
```
Variables:
- DaysToKeepAmi - set this for how many days to keep AMIs, currently set to six months

1. EventBridge rule is triggered every 30 days
2. The event will trigger the lambda function to run

# Source
/src/functions/ami_unsharing.py

The lambda will get a list of AMIs that are older than the DaysToKeepAMi variable and remove 
the permissions to the AMI.  It currently will not delete any AMI, this is so the AMI can be
referenced later if needed.
