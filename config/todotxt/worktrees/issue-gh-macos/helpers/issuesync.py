#!/usr/bin/env python3

import sys
import os
import re
import argparse
import json
from itertools import chain
import pytodotxt
from github import Github


#maps github labels to todo.txt tags, e.g:    
#{
#   "enhancement": "feat"
#}
#these replace the github label
LABEL_MAP = {}

#maps projects to tags/contexts/projects, these will be added in addition to the project (rather than replacing it)
#example: { "frog": ["@work","@huc","@clariah","+wp3t139"] }
INFER_FROM_PROJECT = {}


TAG_RE = re.compile(r'(\s+|^)#([^\s]+)')

def infer_from_project(task: pytodotxt.Task):
    """Infer additional tags based on the project"""
    for project in task.projects:
        project = project.strip('+')
        if project in INFER_FROM_PROJECT:
            for tag in INFER_FROM_PROJECT[project]:
                if str(task).find(tag) == -1:
                    task.append(tag)
    

def update_task_with_github_issue(task: pytodotxt.Task, issue):
    if issue.state == "open" and task.is_completed:
        #reopen locally
        task.is_completed = False
        print("Reopening: ", task, file=sys.stderr)
    elif issue.state != "open" and not task.is_completed:
        #close locally
        task.is_completed = True
        print("Closing: ", task, file=sys.stderr)

    updated = issue.updated_at.strftime("%Y-%m-%d")
    if 'updated' in task.attributes and task.attributes['updated'] != [updated]:
        task.remove_attribute('updated')
        task.add_attribute('updated', updated)
    elif 'updated' not in task.attributes:
        task.add_attribute('updated', updated)

    #sync labels
    foundlabels = set()
    tags = [ m.group(0).strip(' #') for m in task.parse_tags(TAG_RE) ]
    for label in issue.labels:
        label = fmtlabel(label.name)
        foundlabels.add(label)
        if label not in tags:
            task.append("#" + label)

    for label in tags:
        if label not in foundlabels: 
            task.remove_tag(label, TAG_RE)


def fmtlabel(label: str) -> str:
    label = fmt(label)
    if label in LABEL_MAP:
        return LABEL_MAP[label]
    else:
        return label

def fmt(s: str) -> str:
    """Formatter for projects/tags"""
    return "".join(c for c in s if c.isalnum()).lower()


parser = argparse.ArgumentParser(description="Issue syncer", formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument('--todo','-t',type=str, help="todo.txt file", action='store', required=True)
parser.add_argument('--done','-d',type=str, help="done.txt file", action='store', required=True)
parser.add_argument('--labelmap','-l',type=str, help="label file (json)", action='store', required=False)
parser.add_argument('--infermap','-i',type=str, help="tag inference map (json), infers tags and contexts from projects", action='store', required=False)
args = parser.parse_args() #parsed arguments can be accessed as attributes


TODO_FILE = args.todo
DONE_FILE = args.done
if args.labelmap:
    with open(args.labelmap,'r',encoding='utf-8') as f:
        LABEL_MAP = json.load(f)
if args.infermap:
    with open(args.infermap,'r',encoding='utf-8') as f:
        INFER_FROM_PROJECT = json.load(f)

todo = pytodotxt.TodoTxt(TODO_FILE)
todo.parse()

done = pytodotxt.TodoTxt(DONE_FILE)
done.parse()

gh = Github(os.environ['GITHUB_TOKEN'])
ghuser = gh.get_user()

ghissues = {}
for issue in ghuser.get_issues(state="all"):
    ghissues[issue.html_url] = issue
print(f"Retrieved {len(ghissues)} issues from Github", file=sys.stderr)

ghissues_found = set()
ghissues_notfound = set()

for task in chain(todo.tasks,done.tasks):
    if 'issue:https' in task.attributes: #bug in pytodotxt, https is interpeted as part of the key rather than value
        for url in task.attributes['issue:https']:
            url = "https:" + url
            if url in ghissues:
                print("Matched issue ", url, file=sys.stderr)
                issue = ghissues[url]
                ghissues_found.add(url)
                update_task_with_github_issue(task, issue)
            else:
                print("Unable to match issue ", url, file=sys.stderr)
                ghissues_notfound.add(url)

for url, issue in ghissues.items():
    if url not in ghissues_found:
        taskline = ""
        if issue.state != "open":
            taskline += "x "
        created = issue.created_at.strftime("%Y-%m-%d")
        taskline += f"{created} +{fmt(issue.repository.name)}"
        for label in issue.labels:
            taskline += f" #{fmtlabel(label.name)}"
        updated = issue.updated_at.strftime("%Y-%m-%d")
        taskline += f" {issue.title} issue:{issue.html_url} updated:{updated}"
        task = pytodotxt.Task(taskline)
        infer_from_project(task)
        if task.is_completed:
            done.add(task)
            print("Added completed: ", task, file=sys.stderr)
        else:
            todo.add(task)
            print("Added: ", task, file=sys.stderr)

#pytodotxt stumbles over symlinks (overwriting them with a new file rather than following them), so we do it this way:
todo.save(target="/tmp/todo.txt", safe=False)
with open("/tmp/todo.txt","r",encoding="utf-8") as f_in:
    with open(TODO_FILE,"w+",encoding="utf-8") as f_out:
        f_out.write(f_in.read())

done.save(target="/tmp/done.txt", safe=False)
with open("/tmp/done.txt","r",encoding="utf-8") as f_in:
    with open(DONE_FILE ,"w+",encoding="utf-8") as f_out:
        f_out.write(f_in.read())

