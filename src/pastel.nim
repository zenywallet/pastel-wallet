# Copyright (c) 2019 zenywallet

import server
import stream
import watcher

var threads: array[3, Thread[void]]
threads[0] = server.start()
threads[1] = stream.start()
threads[2] = watcher.start()
joinThreads(threads)
