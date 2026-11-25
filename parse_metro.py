import re
import json

with open('database_dump.sql') as f:
    sql = f.read()

# Extract lines
lines_match = re.search(r"INSERT INTO `metro_lines` VALUES\s*(.*?);", sql, re.DOTALL)
if lines_match:
    print("Found metro_lines!")
    lines_str = lines_match.group(1).strip()
    # parse each row
    rows = re.findall(r"\((.*?)\)(?:,|$)", lines_str, re.DOTALL)
    print("Rows in metro_lines:", len(rows))
    for r in rows:
        print("  Line:", r.strip()[:80])

stns_match = re.search(r"INSERT INTO `metro_stations` VALUES\s*(.*?);", sql, re.DOTALL)
if stns_match:
    print("\nFound metro_stations!")
    stns_str = stns_match.group(1).strip()
    rows = re.findall(r"\((.*?)\)(?:,|$)", stns_str, re.DOTALL)
    print("Rows in metro_stations:", len(rows))
    for r in rows[:6]:
        print("  Station:", r.strip())

