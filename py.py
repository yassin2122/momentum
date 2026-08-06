import json
import time
import requests

BASE_URL = "https://oss.exercisedb.dev/api/v1/exercises"

OUTPUT_FILE = "exercises.json"

HEADERS = {
    "User-Agent": "Momentum-Importer/1.0"
}

all_exercises = []
seen_ids = set()

cursor = None
page = 1

while True:
    if cursor:
        url = f"{BASE_URL}?cursor={cursor}"
    else:
        url = BASE_URL

    print(f"Downloading page {page}...")

    # Retry up to 3 times
    for attempt in range(3):
        try:
            response = requests.get(url, headers=HEADERS, timeout=30)
            response.raise_for_status()
            data = response.json()
            break
        except Exception as e:
            if attempt == 2:
                raise
            print(f"Retry {attempt + 1}/3: {e}")
            time.sleep(2)

    exercises = data.get("data", [])

    added = 0
    for exercise in exercises:
        exercise_id = exercise.get("exerciseId")

        if exercise_id not in seen_ids:
            seen_ids.add(exercise_id)
            all_exercises.append(exercise)
            added += 1

    print(
        f"Added {added} exercises "
        f"(Total: {len(all_exercises)}/{data['meta']['total']})"
    )

    meta = data.get("meta", {})

    if not meta.get("hasNextPage"):
        break

    cursor = meta.get("nextCursor")

    page += 1

    # Be nice to the API
    time.sleep(0.2)

print("\nSaving JSON...")

with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
    json.dump(all_exercises, f, indent=2, ensure_ascii=False)

print(f"\nDone!")
print(f"Downloaded {len(all_exercises)} exercises.")
print(f"Saved to {OUTPUT_FILE}")


retry_after = response.headers.get("Retry-After")

if retry_after:
    time.sleep(int(retry_after))
else:
    time.sleep(10)