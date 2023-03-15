import requests
import time
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("ip_address", help="The IP address of the service to check")
args = parser.parse_args()

while True:
    try:
        # Check if the service is up
        response = requests.get(f"http://{args.ip_address}:443/healthz")
        if response.status_code != 200:
            print("Service is down at", time.ctime())
            continue
        
        # Check the current time on the /now endpoint
        response = requests.get(f"http://{args.ip_address}:443/now")
        if response.status_code == 200:
            # Check if the response contains a path starting with /internal/
            path = response.json().get('path', '')
            if path.startswith('/internal/'):
                print("Access Denied 403")
            else:
                print("Service is healthy")
                print("Current time on", path, "is", response.json()['current_time'], "at", time.ctime())
        else:
            print("Failed to retrieve current time with status code", response.status_code, "at", time.ctime())
    except Exception as e:
        print("Error:", e, "at", time.ctime())
    time.sleep(30)  # Wait for 30 seconds before checking again