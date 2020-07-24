-- According to the IMAP specification, when trying to write a message
-- to a non-existent mailbox, the server must send a hint to the client,
-- whether it should create the mailbox and try again or not. However
-- some IMAP servers don't follow the specification and don't send the
-- correct response code to the client. By enabling this option the
-- client tries to create the mailbox, despite of the server's response.
-- This variable takes a boolean as a value.  Default is “false”.
options.create = true
-- By enabling this option new mailboxes that were automatically created,
-- get auto subscribed
options.subscribe = true
-- How long to wait for servers response.
options.timeout = 120

-- Gets password from pass
status, gpassword = pipe_from('pass show Email/GmailApp')
-- Setup an imap account called work
gmail = IMAP {
  server = "imap.gmail.com",
  port = 993,
  username = "edmund.a.miller@gmail.com",
  password = gpassword,
  ssl = "auto",
}

status, upassword = pipe_from('pass show utd')
school = IMAP {
  server = "127.0.0.1",
  port = 1143,
  username = "eam150030@utdallas.edu",
  password = upassword,
}

-- This function takes a table of email addresses
-- and flags messages from them in the inbox.
function flagSenders(senders)
  for _, v in pairs(senders) do
    messages = gmail["Inbox"]:contain_from(v)
    messages:unmark_flagged()
  end
end

flagSenders {
    "troy.d.miller@gmail.com",
}
