Reads entire device and times each read. If the hard drive is going bad,
it may take significantly longer to read certain sectors, even though
it succeeds and SMART reports no problems. This may indicated impending
failure. Additionally, reading the entire disk can trigger the drive's
automatic sector replacement for weak sectors, refreshing the data.
You may want to tee the output to a file for later review, there
may be a lot fo lines for large disks. Run on an idle system, other
activity will skew the drive read times.
