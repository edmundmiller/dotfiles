# Jira CLI aliases
alias sdoc='jira issue list -p SDOC -a $(jira me) -s"Open" -s"In Progress" -s"To Do"'
alias sd='jira issue list -p SD -a $(jira me) -s"Open" -s"In Progress" -s"To Do"'
alias ji='jira issue list -q "(assignee = currentUser() OR reporter = currentUser()) AND project NOT IN (SDOC, SD) AND (status IN (\"Open\", \"To Do\", \"In Progress\") OR updated >= -1w)"'
