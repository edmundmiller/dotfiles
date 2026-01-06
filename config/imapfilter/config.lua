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
status, gpassword = pipe_from("pass show Email/GmailApp")
-- Setup an imap account called work
gmail =
    IMAP {
    server = "imap.gmail.com",
    port = 993,
    username = "edmund.a.miller@gmail.com",
    password = gpassword,
    ssl = "auto"
}

status, upassword = pipe_from("pass show utd")
utd =
    IMAP {
    server = "127.0.0.1",
    port = 1143,
    username = "eam150030@utdallas.edu",
    password = upassword
}

-- This function takes a table of email addresses
-- and flags messages from them in the inbox.
function flagSenders(senders)
    for _, v in pairs(senders) do
        messages = gmail["Inbox"]:contain_from(v)
        messages:mark_flagged()
    end
end

flagSenders {
    "monicadd4@gmail.com",
    "troy.d.miller@gmail.com",
    "lorioutlaw@gmail.com",
    "marciamd23@gmail.com"
}

-----------
-- Gmail --
-----------

bank = gmail.Inbox:contain_from("capitalone@notification.capitalone.com")
bank:move_messages(gmail["bank"])

github =
    gmail.Inbox:contain_from("notifications@github.com") + gmail.Inbox:contain_from("noreply@github.com") -
    gmail.Inbox:contain_subject("security advisory")
github:move_messages(gmail["github"])

cicd = gmail.Inbox:contain_from("ci_activity@noreply.github.com") - gmail.Inbox:contain_subject("Run failed:")
cicd:move_messages(gmail["ci-cd"])

receipts =
    gmail.Inbox:contain_subject("receipt") + gmail.Inbox:contain_subject("billing") +
    gmail.Inbox:contain_subject("invoice") * gmail.Inbox:is_older(2)
receipts:move_messages(gmail["receipt"])

amazon =
    gmail.Inbox:contain_from("auto-confirm@amazon.com") + gmail.Inbox:contain_from("order-update@amazon.com") +
    gmail.Inbox:contain_from("no-reply@amazon.com") +
    gmail.Inbox:contain_from("return@amazon.com") -
    gmail.Inbox:contain_subject("security advisory") * gmail.Inbox:is_older(1)
amazon:move_messages(gmail["amazon"])
gmail.amazon:is_older(30):delete_messages()

gmail.Inbox:contain_from("help@parcelpending.com"):is_older(1):delete_messages()

millblock =
    gmail.Inbox:contain_from("bob.reid@reidproperties.com") + gmail.Inbox:contain_from("brians@reidproperties.com")
millblock:move_messages(gmail["millblock"])

gmail["[Gmail]/Spam"]:contain_from("noreply@lscs.desire2learn.com"):delete_messages()

-- Promotional Emails
function deleteSenders(senders)
    for _, v in pairs(senders) do
        messages = gmail["Inbox"]:contain_from(v)
        messages:is_older(3):delete_messages()
    end
end

deleteSenders {
    "Promo@promo.newegg.com",
    "no-reply@m.chownowmail.com",
    "microcenter@microcenterinsider.com"
}

---------
-- UTD --
---------

covid =
    utd.Inbox:contain_from("redcap@utdallas.edu") * utd.Inbox:contain_subject("Daily Health Check") +
    utd.Inbox:contain_subject("[Reminder] Daily Health Check")

covid:delete_messages()

-- messages = utd["Inbox"]:contain_from("nancy.yu@utdallas.edu")
-- messages:mark_flagged()

elearning =
    utd.Inbox:contain_from("elearning-notification@utdallas.edu") * utd.Inbox:contain_subject("Daily Notifications") *
    utd.Inbox:is_older(1)

elearning:delete_messages()

utd.Inbox:contain_from("oitnotify@utdallas.edu"):delete_messages()

-- Courses
quant = utd.Inbox:contain_subject("BIOL 5460")
quant:is_older(1):move_messages(utd["courses/biol-5460"])

molcell = utd.Inbox:contain_subject("BIOL5420")
molcell:is_older(1):move_messages(utd["courses/biol-5420"])

colloquium = utd.Inbox:contain_subject("BIOL 6193")
colloquium:is_older(1):move_messages(utd["courses/biol-6193"])

biochem =
    utd.Inbox:contain_subject("3361.001") + utd.Inbox:contain_subject("Biochem I") +
    utd.Inbox:contain_from("gabriele.meloni@utdallas.edu") +
    utd.Inbox:contain_from("Rose.Curtis@UTDallas.edu")
biochem:is_older(1):move_messages(utd["courses/biol-3361"])

-- Functional Genomics
funcgenomics =
    utd.Inbox:contain_from("txk142630@utdallas.edu") + utd.Inbox:contain_from("gozde.buyukkahraman@utdallas.edu") +
    utd.Inbox:contain_from("grayson.almond@utdallas.edu") +
    utd.Inbox:contain_from("shayne.easterwood@utdallas.edu")
funcgenomics:is_older(1):move_messages(utd["Functional Genomics"])

-- Computational Biology Group
compbio =
    utd.Inbox:contain_from("michael.zhang@utdallas.edu") + utd.Inbox:contain_from("zhenyu.xuan@utdallas.edu") +
    utd.Inbox:contain_from("ben.niu@utdallas.edu") +
    utd.Inbox:contain_from("ming.song@utdallas.edu")
compbio:is_older(1):move_messages(utd["Computational Biology"])

-- SLURM
ganymede = utd.Inbox:contain_subject("Failed")
-- - utd.Inbox:contain_from("zhenyu.xuan@utdallas.edu")
ganymede:is_older(1):move_messages(utd["slurm"])
