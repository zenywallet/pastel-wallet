# Copyright (c) 2019 zenywallet

import server
import stream
import watcher
import cmd

var threads: array[4, Thread[void]]
threads[0] = server.start()
threads[1] = stream.start()
threads[2] = watcher.start()
threads[3] = cmd.start()
joinThreads(threads)
