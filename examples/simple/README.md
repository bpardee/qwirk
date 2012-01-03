## Step 0
### Follow the directions for configuring configuring a JMS or InMem adapter located in examples/README

## Step 1
### Start up the application
* rm -f qwirk.yml
* rackup -p 4567

## Step 2
* Browse to http://localhost:4567
* Open up the tree to Worker => Bar => Attributes and click on Attributes
* Change max\_count to 100, idle\_worker\_timeout to 10, and sleep\_time to 5 and click Update.

## Step 3
* Open the tree to Publisher => Operations => send\_bar and click on send\_bar
* Set count to 100 and sleep\_time to 0.2 and click Execute.
* Click back on Worker => Bar => Attributes and continue clicking every few seconds.  You
  should see the count of workers top out at around 25 (5 published messages/sec * 5 secs/worker)
  and then after all 100 messages have been read it will drop back down to 1.

## Step 4
* cntl-c the rackup process and start it back up.  It should come back with
  the workers and the config values that have been configured via the browser.

## Things to try:

### Expanding / Contracting workers

Note that after you set a max\_count and before you publish, the count of workers will be
1 as their is just a single worker waiting for data on the queue.  Once you publish messages,
the count of workers will grow as needed to handle the message volume up to max\_count.

If you set a value for idle\_worker\_timeout then the count of workers will go down when there
is no work to be done.  Set a timeout and refresh the attributes to see this in action.

### Monitoring your workers

Browse to http://localhost:4567/Worker/Bar/timer/attributes.json?reset=true

Publish some messages (possibly modifying the worker's sleep times first) and browse to that address again.

If you use a monitoring tool such as munin, nagios, hyperic, etc., you could poll this url periodically to create
a graph or alert for your system.  For easy creation of munin graphs and alert withe this framework, see
https://github.com/ClarityServices/ruminate

