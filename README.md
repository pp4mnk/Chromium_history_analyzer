I wanted to find out which websites I visit most frequently when using Chromium on EasyOS, without having to scroll through hundreds of individual browsing history entries.

The previous version worked perfectly from the terminal, but I thought: why not make it easier and more accessible for everybody?

So here we are!

What's new in version 3?

The main improvement is the addition of a GTKdialog graphical interface, which allows you to examine your browsing statistics in a window rather than relying entirely on terminal output.

Main features:

Graphical interface: A simple GTKdialog window to display your browsing statistics.

TOP 50 websites: Lists your most frequently visited domains.

Visit counter: Shows how many recorded visits each website has received.

Automatic ranking: Websites are sorted from most visited to least visited.

Domain grouping: Combines visits to different pages belonging to the same domain.

Text report: Automatically saves the results for future reference.

Open report button: Lets you view the report in your preferred text editor.

Privacy: Everything is processed locally, without sending your browsing history anywhere.

Lightweight: Written in Bash, using SQLite3 and GTKdialog. No Python required!

In other words, a small utility that does one job without unnecessary complications.

1. Requirements

The programme has been developed for EasyOS Excalibur, although it may also work with other Puppy Linux distributions after adjusting the Chromium profile location.

You will need:

Bash (already included in EasyOS).

Chromium, with an existing browsing history.

SQLite3 command-line utility.

GTKdialog for the graphical interface.

You can check whether the required programmes are available by opening a terminal and running:

command -v sqlite3
command -v gtkdialog

If both commands return a valid executable path, you're ready to go!

If SQLite3 is missing, search for the sqlite3 package in PKGget.

Important: The libsqlite3-0 library is not the same thing as the sqlite3 command-line programme. You need the latter to run the analyser.

GTKdialog is normally available in EasyOS, but it's worth checking.
