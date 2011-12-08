## Step 0
### Follow the directions for configuring configuring a JMS or InMem adapter located in examples/README

## Step 1
### Start up the application
* rm -f modern\_times.yml
* rackup -p 4567

## Step 2
* Browse to http://localhost:4567
* Open up the tree to Worker => Bar => Attributes or Worker => Baz => Attributes
* Modify the max\_count value and click Update.

## Step 3
* Open the tree to Publisher => Operations => send\_bar or send\_baz
* Enter values for the various arguments and click Execute.

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
a graph or alert for your system.

