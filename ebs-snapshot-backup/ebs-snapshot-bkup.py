# @Author: Alfonso Brown, Brian Torbich
# @Date:   2018-04-25T14:30:03-04:00
# @Filename: ebs-snapshot-bkup.py
# @Last modified by:   Brian Torbich
# @Last modified time: 2019-03-06

import datetime
import os
import threading
from queue import Queue

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError


# Create the backup by using a create_snapshot() API call
def create_snapshot(volume_data):
    try:
        snapshot = resource.create_snapshot(
            VolumeId=volume_data['volume_id'],
            DryRun=bool(os.environ['dryrun']),
            Description=f"{volume_data['volume_name']}_SCHEDULEDBACKUP",
            TagSpecifications=[
                {
                    'ResourceType': 'snapshot',
                    'Tags': [
                        {
                            'Key': 'Name',
                            'Value': f"{volume_data['volume_name']}_SCHEDULEDBACKUP"
                        },
                        {
                            'Key': 'DeleteOn',
                            'Value': volume_data['delete_on']
                        },
                        {
                            'Key': 'DeviceName',
                            'Value': volume_data['device_name']
                        },
                        {
                            'Key': 'InstanceID',
                            'Value': volume_data['instance_id']
                        },
                        {
                            'Key': 'BackupJob',
                            'Value': os.environ['backuptag1']
                        },
                    ]
                },
            ],
        )
        print(f"Queued ({snapshot.volume_size}GB) backup of ({volume_data['volume_id']}) ({volume_data['instance_id']})"
              f" with ({snapshot.id}) tagged for deletion on ({volume_data['delete_on']})")
    except ClientError as e:
        if e.response['Error']['Code'] == 'DryRunOperation':
            print(f"**DryRun succeeded for ({volume_data['volume_id']}) ({volume_data['instance_id']})")
        else:
            print(f"**Unexpected backup error for ({volume_data['volume_id']})({volume_data['instance_id']}): ({e})")


# Process the queued volumes for backup
def process_queue():
    # While there are volumes in the backup_queue, run each create_snapshot() iteration in its own thread
    while True:
        create_snapshot(backup_queue.get())
        backup_queue.task_done()


# The main function is the lambda_handler()
def lambda_handler(event, context):
    global backup_queue
    backup_queue = Queue()  # Create a thread queue to hold list of volumes to be backed up

    # Set up AWS session, client, and resource
    client = boto3.client('ec2',
                          config=Config(
                              max_pool_connections=int(os.environ['threadcount']),
                              retries=dict(
                                  max_attempts=10
                              ),
                          ))
    global resource
    resource = boto3.resource('ec2',
                              config=Config(
                                  max_pool_connections=int(os.environ['threadcount']),
                                  retries=dict(
                                      max_attempts=10
                                  ),
                              ))

    # Configure the number of threads to be used for the process_queue() and start the threads
    for thread_count in range(int(os.environ['threadcount'])):
        thread = threading.Thread(target=process_queue)
        thread.daemon = True
        thread.start()

    # Filter the instances based on backup tag
    instances = resource.instances.filter(Filters=[
        {
            'Name': 'tag-key',
            'Values': [os.environ['backuptag1'], os.environ['backuptag1']]
        }
    ])

    # Track number of instances and volumes
    instance_count = 0
    volume_count = 0

    print(f"Starting backup queing for instance(s) tagged with '{os.environ['backuptag2']}'")
    for instance in instances:
        instance_count += 1
        # Try to get the retention period for the volume. If not set, make it the default of 28 days
        try:
            retention_days = str([tag['Value'] for tag in instance.tags if tag['Key'] == 'Retention'])[2:-2]
        except IndexError:
            print(f"**Instance ({instance.id}) does not contain a retention tag, 28 days will be used by default.")
            retention_days = 28
        if retention_days == '':
            print(f"**Instance ({instance.id}) does not contain a retention tag, 28 days will be used by default.")
            retention_days = 28
        # Set the snapshot retention date
        delete_date = datetime.date.today() + datetime.timedelta(days=int(retention_days))
        # Format the date as YYYY-MM-DD
        delete_fmt = delete_date.strftime('%Y-%m-%d')
        # Iterate through all of the volumes
        for volume in client.describe_volumes(
                Filters=[
                    {
                        'Name': "attachment.instance-id",
                        'Values': [instance.id]
                    }
                ]).get('Volumes', []):
            # Try to get the name of the volume, if it fails, use the instance ID by default
            try:
                tag = str([tag['Value'] for tag in volume['Tags'] if tag['Key'] == 'Name'])[2:-2]
            except KeyError:
                print(f"**Volume ({volume['VolumeId']}) does not contain a name tag, '{instance.id}' "
                      f"will be used by default.")
                tag = instance.id
            if tag == '':
                print(f"**Volume ({volume['VolumeId']}) does not contain a name tag, '{instance.id}' "
                      f"will be used by default.")
                tag = instance.id
            # Iterate through all of the attachments to create the volume_data
            for attachment in volume['Attachments']:
                volume_data = {
                    'volume_id': attachment['VolumeId'],
                    'instance_id': attachment['InstanceId'],
                    'device_name': attachment['Device'],
                    'volume_name': tag,
                    'delete_on': delete_fmt
                }
                print(f"Queuing backup of ({volume_data['volume_id']}) ({volume_data['instance_id']}): ({volume})")
                volume_count += 1
                # Enqueue volume and volume information for backup
                backup_queue.put(volume_data)
    # Wait for all threads to finish
    backup_queue.join()

    print(f"Finished queing {volume_count} backup(s) for {instance_count} "
          f"instance(s) tagged with '{os.environ['backuptag2']}'")
