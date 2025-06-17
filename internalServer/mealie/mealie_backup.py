import requests

mealieBackupUrl = "http://localhost:9925/api/admin/backups"

payload = {}
headers = {
  'Accept-Language': 'application/json',
  'Authorization': 'Bearer blah'
}

try:
     # Send POST request
    response = requests.post(mealieBackupUrl, headers=headers, data=payload)

    # Check if response status code is 201 and error field is false
    if response.status_code == 201:
        response_json = response.json()
        if response_json.get("error") == False:
            print("Backup created successfully.")
            # Send the healthcheck ping
            # requests.get("https://hc-ping.com/blah", timeout=10)
        else:
            print("Error in backup response: %s" % response_json.get("message"))
    else:
        print("Failed to create backup, status code: %d" % response.status_code)

except requests.RequestException as e:
    # Log ping failure here...
    print("Ping failed: %s" % e)