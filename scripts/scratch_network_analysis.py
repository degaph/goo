# encoding=utf8  
import sys  
reload(sys)  
sys.setdefaultencoding('utf8')
import csv
from collections import Counter
import json
import numpy as np
import igraph
import dateparser
import datetime
import filters

def parse_csv(filename):
  first = True
  keys = []
  dataset = []
  with open(filename, 'rb') as f:
      reader = csv.reader(f)
      for row in reader:
        if first:
          first = False
          keys = row
        else:
          parsed_row = {}
          for i,val in enumerate(row):
            parsed_row[keys[i]] = val
          dataset.append(parsed_row)
  return dataset

nodes = parse_csv("nodelist.csv")
full_edges = parse_csv("edgelist.csv")
graph = igraph.Graph()
for node in nodes:
  graph.add_vertex(node["id"])
  target_node = graph.vs.select(name=node["id"])[0]
  target_node["event_name"] = node["id"]

for edge in full_edges:
  source_node = graph.vs.select(name=edge["source"])[0]
  target_node = graph.vs.select(name=edge["target"])[0]
  edges = list(graph.es.select(_between = ([source_node.index], [target_node.index])))
  if len(edges) == 0:
    graph.add_edge(source_node, target_node)
    edge = list(graph.es.select(_between = ([source_node.index], [target_node.index])))[0]
    edge["weight"] = 1
  else:
    edge = list(graph.es.select(_between = ([source_node.index], [target_node.index])))[0]
    edge["weight"] += 1

filters.prune(graph, "weight", num_remove=len(graph.es())*0.8)
for e in graph.es():
  print str(graph.vs(e.source)["event_name"][0])+","+str(graph.vs(e.target)["event_name"][0])