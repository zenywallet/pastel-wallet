# Copyright (c) 2019 zenywallet

import server
import watcher
import cmd

var threads: array[3, ref Thread[void]]
threads[0] = server.start()
threads[1] = watcher.start()
threads[2] = cmd.start()
for i in 0..threads.high: joinThread(threads[i][])
