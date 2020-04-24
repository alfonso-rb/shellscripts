# @Author: Alfonso Brown, Brian Torbich
# @Date:   2018-04-25T14:30:03-04:00
# @Filename: ebs-snapshot-bkup-reaper.py
# @Last modified by:   Brian Torbich
# @Last modified time: 2019-03-12

import datetime
import os
from concurrent.futures import ThreadPoolExecutor

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError


def delete_snapshot(snapshot):
    try:
        client.delete_snapshot(
            DryRun=bool(os.environ['dryrun']),
            SnapshotId=snapshot['SnapshotId']
        )
        print(f"Queued ({snapshot['SnapshotId']}) for deletion ")

    except ClientError as e:
        if e.response['Error']['Code'] == 'DryRunOperation':
            print(f"**DryRun deletion succeeded for ({snapshot['SnapshotId']}) ")
        elif e.response['Error']['Code'] == 'InvalidSnapshot.NotFound':
            print(f"**Snapshot already deleted for ({snapshot['SnapshotId']}) ")
        elif e.response['Error']['Code'] == 'InvalidSnapshot.InUse':
            print(f"**Snapshot currently in use for ({snapshot['SnapshotId']}) ")
        else:
            print(f"**Unexpected delete_snapshot() error for ({snapshot['SnapshotId']}): {e} ")


def lambda_handler(event, context):
    global client  # Set up AWS client
    client = boto3.client('ec2',
                          config=Config(
                              max_pool_connections=10,
                              retries=dict(
                                  max_attempts=10
                              ),
                          ))

    """ Parse the list of snapshots to be deleted and run delete_snapshot() API call with a thread pool"""
    delete_on = datetime.date.today().strftime('%Y-%m-%d')  # Get the current date
    snapshot_count = 0  # track the number of snapshots queued for deletion
    with ThreadPoolExecutor(max_workers=10) as executor:
        for snapshot in client.describe_snapshots(
                OwnerIds=['self'],
                Filters=[
                    {
                        'Name': 'tag-key',
                        'Values': ['DeleteOn']
                    },
                    {
                        'Name': 'tag-value',
                        'Values': [delete_on]
                    },
                ]
        ).get('Snapshots', []):
            executor.submit(delete_snapshot, snapshot)
            snapshot_count += 1

    print(f"Total of {snapshot_count} snapshot(s) queued for deletion")
