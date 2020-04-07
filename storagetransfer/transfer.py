import argparse
import json

import googleapiclient.discovery


def main(project_id, source_bucket, sink_bucket, run_once):
    """Create a daily transfer from Standard to Nearline Storage class."""
    storagetransfer = googleapiclient.discovery.build('storagetransfer', 'v1')

    # Instead of determining actual dates, use hardcoded date in past
    if run_once:
        description = source_bucket + ' Restore'
        schedule = {
            'scheduleStartDate': {'day': 1, 'month': 1, 'year': 1970},
            'scheduleEndDate': {'day': 1, 'month': 1, 'year': 1970},
        }
    else:
        description = source_bucket + ' Daily Backup'
        schedule = {
            'scheduleStartDate': {'day': 1, 'month': 1, 'year': 1970},
            'startTimeOfDay': {'hours': 0, 'minutes': 0, 'seconds': 0},
        }

    # Edit this template with desired parameters.
    transfer_job = {
        'status': 'ENABLED',
        'description': description,
        'projectId': project_id,
        'schedule': schedule,
        'transferSpec': {
            'gcsDataSource': {
                'bucketName': source_bucket
            },
            'gcsDataSink': {
                'bucketName': sink_bucket
            },
            'transferOptions': {
                'overwriteObjectsAlreadyExistingInSink': True,
                'deleteObjectsUniqueInSink': True,
            }
        }
    }

    result = storagetransfer.transferJobs().create(body=transfer_job).execute()
    print('Returned transferJob: {}'.format(
        json.dumps(result, indent=4)))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('project_id', help='Your Google Cloud project ID.')
    parser.add_argument('source_bucket', help='Standard GCS bucket name.')
    parser.add_argument('sink_bucket', help='Nearline GCS bucket name.')
    parser.add_argument('--run-once', default=False, action="store_true", help='Only run once')

    args = parser.parse_args()
    main(args.project_id, args.source_bucket, args.sink_bucket, args.run_once)