import sys
import os
import json
first_manifest = json.loads(open(sys.argv[1]).read())
second_manifest = json.loads(open(sys.argv[2]).read())
cleaned_diffs = {"sub_clause": {}, "array_clauses": [], "include_clauses": [], "raw_rule_clauses": []}
for sub_key in second_manifest["sub_clause"].keys():
  if sub_key not in first_manifest["sub_clause"].keys() or first_manifest["sub_clause"][sub_key] != second_manifest["sub_clause"][sub_key]:
    cleaned_diffs["sub_clause"][sub_key] = second_manifest["sub_clause"][sub_key]

array_clauses_names = [v["name"] for v in first_manifest["array_clauses"]]
for array_val in second_manifest["array_clauses"]:
  if array_val["name"] not in array_clauses_names:
    cleaned_diffs["array_clauses"].append(array_val)
  if array_val["name"] in array_clauses_names and array_val["include_list"] != first_manifest["array_clauses"][array_clauses_names.index(array_val["name"])]["include_list"]:
    other_set = first_manifest["array_clauses"][array_clauses_names.index(array_val["name"])]["include_list"]
    altered_group = {"name": array_val["name"], "include_list": []}
    for val in array_val["include_list"]:
      if val not in other_set:
        altered_group["include_list"].append(val)
    if len(altered_group["include_list"]) != 0:
      cleaned_diffs["array_clauses"].append(altered_group)

include_clauses_names = [v["name"] for v in first_manifest["include_clauses"]]
for include_val in second_manifest["include_clauses"]:
  if include_val["name"] not in include_clauses_names:
    cleaned_diffs["include_clauses"].append(include_val)
  if include_val["name"] in include_clauses_names and include_val["include_list"] != first_manifest["include_clauses"][include_clauses_names.index(include_val["name"])]["include_list"]:
    other_set = first_manifest["include_clauses"][include_clauses_names.index(include_val["name"])]["include_list"]
    altered_group = {"name": include_val["name"], "include_list": []}
    for val in include_val["include_list"]:
      if val not in other_set:
        altered_group["include_list"].append(val)
    if len(altered_group["include_list"]) != 0:
      cleaned_diffs["include_clauses"].append(altered_group)

rule_name_topics = [[v["name"], v["topic"]] for v in first_manifest["raw_rule_clauses"]]
for rule in second_manifest["raw_rule_clauses"]:
  if [rule["name"], rule["topic"]] not in rule_name_topics:
    cleaned_diffs["raw_rule_clauses"].append(rule)
  if [rule["name"], rule["topic"]] in rule_name_topics:
    updated_rule = {"name": rule["name"], "topic": rule["topic"], "reply": [], "condition": [], "previous": []}
    for reply in rule["reply"]:
      if reply not in first_manifest["raw_rule_clauses"][rule_name_topics.index([rule["name"], rule["topic"]])]["reply"]:
        updated_rule["reply"].append(reply)
    for condition in rule["condition"]:
      if condition not in first_manifest["raw_rule_clauses"][rule_name_topics.index([rule["name"], rule["topic"]])]["condition"]:
        updated_rule["condition"].append(condition)
    for previous in rule["previous"]:
      if previous not in first_manifest["raw_rule_clauses"][rule_name_topics.index([rule["name"], rule["topic"]])]["previous"]:
        updated_rule["previous"].append(previous)
    if sum([len(updated_rule["reply"]), len(updated_rule["condition"]), len(updated_rule["previous"])]) != 0:
      cleaned_diffs["raw_rule_clauses"].append(updated_rule)

cleaned_diffs["sub_clause"] = {"subs": cleaned_diffs["sub_clause"]}
print json.dumps(cleaned_diffs)