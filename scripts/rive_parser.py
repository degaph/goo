import sys
import os
import json
from rivescript import RiveScript
bot = RiveScript(utf8=True)
bot.load_file(sys.argv[1])
bot.sort_replies()
deparsed = bot.deparse()
full_dump = {"sub_clause": [], "array_clauses": [], "include_clauses": [], "raw_rule_clauses": []}
for raw_rule_topic in deparsed["topic"].keys():
  for raw_rule_key in deparsed["topic"][raw_rule_topic].keys():
    raw_rule = {"topic": raw_rule_topic, "name": raw_rule_key, "reply": [], "condition": [], "previous": []}
    if "reply" in deparsed["topic"][raw_rule_topic][raw_rule_key].keys():
      for reply in deparsed["topic"][raw_rule_topic][raw_rule_key]["reply"]:
        raw_rule["reply"].append(reply)
    if "condition" in deparsed["topic"][raw_rule_topic][raw_rule_key].keys():
      for reply in deparsed["topic"][raw_rule_topic][raw_rule_key]["condition"]:
        raw_rule["condition"].append(reply)
    if "previous" in deparsed["topic"][raw_rule_topic][raw_rule_key].keys():
      raw_rule["previous"].append(deparsed["topic"][raw_rule_topic][raw_rule_key]["previous"])
    full_dump["raw_rule_clauses"].append(raw_rule)

for raw_rule_topic in deparsed["that"].keys():
  for raw_rule_key in deparsed["that"][raw_rule_topic].keys():
    raw_rule = {"topic": raw_rule_topic, "name": raw_rule_key, "reply": [], "condition": [], "previous": []}
    if "reply" in deparsed["that"][raw_rule_topic][raw_rule_key].keys():
      for reply in deparsed["that"][raw_rule_topic][raw_rule_key]["reply"]:
        raw_rule["reply"].append(reply)
    if "condition" in deparsed["that"][raw_rule_topic][raw_rule_key].keys():
      for reply in deparsed["that"][raw_rule_topic][raw_rule_key]["condition"]:
        raw_rule["condition"].append(reply)
    if "previous" in deparsed["that"][raw_rule_topic][raw_rule_key].keys():
      raw_rule["previous"].append(deparsed["that"][raw_rule_topic][raw_rule_key]["previous"])
    full_dump["raw_rule_clauses"].append(raw_rule)

for arr_key in deparsed["begin"]["array"]:
  full_dump["array_clauses"].append({"name": arr_key, "include_list": deparsed["begin"]["array"][arr_key]})

full_dump["sub_clause"] = {"subs": deparsed["begin"]["sub"]}
for key in deparsed["include"].keys():
  full_dump["include_clauses"].append({"name": key, "include_list": deparsed["include"][key]})

print json.dumps(full_dump)